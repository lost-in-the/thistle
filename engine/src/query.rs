//! Bounded literal retrieval over saved evidence. No tokenization or runtime binding.
use crate::{error::{CoreError, Result}, schema, store::Reader};
use serde_json::{json, Value};
use std::sync::{Arc, OnceLock, atomic::{AtomicUsize, Ordering}};

pub(crate) struct Budget { used: AtomicUsize, limit: usize }
pub(crate) struct Reservation { budget: Arc<Budget>, bytes: usize }
impl Budget {
    pub(crate) fn new(limit: usize) -> Arc<Self> { Arc::new(Self { used: AtomicUsize::new(0), limit }) }
    pub(crate) fn reserve(self: &Arc<Self>, bytes: usize) -> Result<Reservation> {
        self.used.fetch_update(Ordering::AcqRel, Ordering::Acquire, |used|
            used.checked_add(bytes).filter(|total| *total <= self.limit))
            .map_err(|_| CoreError::limit("Reader/index/query budget exhausted; close unused readers or reduce the limit"))?;
        Ok(Reservation { budget: self.clone(), bytes })
    }
}
impl Drop for Reservation {
    fn drop(&mut self) { self.budget.used.fetch_sub(self.bytes, Ordering::AcqRel); }
}
pub(crate) fn budget() -> &'static Arc<Budget> {
    static BUDGET: OnceLock<Arc<Budget>> = OnceLock::new();
    BUDGET.get_or_init(|| Budget::new(crate::store::READER_BUDGET))
}

pub(crate) const MAX_WORK: usize = 32 * 1024 * 1024;
const INDEX_BYTES: usize = 32 * 1024 * 1024;
const FIELD_BYTES: usize = 4096;

pub(crate) struct Query<'a> { text: &'a str, pub limit: usize, kind: Option<&'a str>, path: Option<&'a str>, domain: &'a str }
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let text = schema::string(request, "query")?.trim();
        if text.is_empty() || text.len() > 256 { return Err(CoreError::input("Find needs 1 to 256 bytes of literal text")); }
        let limit = match request.get("limit") { None => 50, Some(v) => v.as_u64().filter(|n| (1..=500).contains(n)).ok_or_else(|| CoreError::input("Limit must be between 1 and 500"))? as usize };
        let optional = |key: &str| -> Result<Option<&'a str>> {
            match request.get(key) { None | Some(Value::Null) => Ok(None), Some(v) => {
                let s = v.as_str().filter(|s| !s.is_empty() && s.len() <= FIELD_BYTES && !s.contains('\0'))
                    .ok_or_else(|| CoreError::input("Filters must be nonempty strings of at most 4096 bytes"))?;
                Ok(Some(s))
            }}
        };
        let domain = optional("domain")?.unwrap_or("all");
        if !["all", "source", "metadata"].contains(&domain) { return Err(CoreError::input("Domain must be all, source or metadata")); }
        Ok(Self { text, limit, kind: optional("kind")?, path: optional("path_prefix")?, domain })
    }
    // Covers result Values, escaped response serialization, pointer sorting and
    // bounded snippets. Source cache allocations have separate retained charges.
    pub(crate) fn scratch(&self) -> Result<usize> {
        self.limit.checked_mul(128 * 1024).and_then(|n| n.checked_add(2 * 1024 * 1024))
            .ok_or_else(|| CoreError::limit("Query scratch accounting overflow"))
    }
    fn accepts(&self, kind: &str, path: Option<&str>) -> bool {
        self.kind.is_none_or(|filter| filter == kind) && self.path.is_none_or(|prefix| path.is_some_and(|p| p.starts_with(prefix)))
    }
}

struct Entry { file: usize, content: Option<String>, _charge: Option<Reservation> }
pub(crate) struct Index { entries: Vec<Entry>, _charge: Reservation }
impl Index {
    pub(crate) fn build(reader: &Reader, budget: &Arc<Budget>) -> Result<Self> {
        let files = reader.manifest["files"].as_array().expect("validated manifest");
        let slots = files.len().checked_mul(std::mem::size_of::<Entry>()).and_then(|n| n.checked_add(1024))
            .ok_or_else(|| CoreError::limit("Index accounting overflow"))?;
        let charge = budget.reserve(slots)?;
        let mut index = Self { entries: Vec::with_capacity(files.len()), _charge: charge };
        let mut retained = slots;
        for (file, metadata) in files.iter().enumerate() {
            // read_to_end growth and its temporary storage are conservatively
            // charged before I/O; retained capacity cannot exceed this bound.
            let size = (metadata["bytes"].as_u64().unwrap() as usize).checked_mul(2).and_then(|n| n.checked_add(4096))
                .ok_or_else(|| CoreError::limit("Source cache accounting overflow"))?;
            let reserved = retained.checked_add(size).filter(|n| *n <= INDEX_BYTES)
                .and_then(|_| budget.reserve(size).ok());
            if reserved.is_some() { retained += size; }
            let loaded = reserved.and_then(|charge| reader.source_bytes(metadata).ok().map(|content| (content, charge)));
            let (content, charge) = match loaded {
                Some((content, charge)) => (Some(content), Some(charge)),
                None => (None, None)
            };
            index.entries.push(Entry { file, content, _charge: charge });
        }
        index.entries.sort_unstable_by(|a, b| files[a.file]["path"].as_str().cmp(&files[b.file]["path"].as_str()));
        Ok(index)
    }
}

// ASCII-only folding leaves UTF-8 bytes and their original positions intact.
// A comparison budget bounds even adversarial repeated-prefix input.
fn literal(text: &str, query: &str, work: &mut usize) -> Result<Option<usize>> {
    for (start, window) in text.as_bytes().windows(query.len()).enumerate() {
        let mut matched = true;
        for (a, b) in window.iter().zip(query.bytes()) {
            *work = work.checked_sub(1).ok_or_else(|| CoreError::limit("Find comparison budget exhausted"))?;
            if !a.eq_ignore_ascii_case(&b) { matched = false; break; }
        }
        if matched { return Ok(Some(start)); }
    }
    Ok(None)
}
fn snippet(text: &str, start: usize) -> &str {
    let mut end = (start + 384).min(text.len());
    while !text.is_char_boundary(end) { end -= 1; }
    &text[start..end]
}

// Fixed paths only. Borrow accepted names; never traverse defaults/options or
// allocate a per-model field list. One result per fact keeps legacy precedence.
fn model_names(fact: &Value) -> impl Iterator<Item = (&'static str, usize, &Value)> {
    [
        ("columns", "attributes.model.columns.entries[].name"),
        ("associations", "attributes.model.associations.entries[].name"),
    ].into_iter().filter(move |_| fact["kind"] == "rails_model").flat_map(move |(family, field)| {
        fact["attributes"]["model"][family]["entries"].as_array().into_iter()
            .flatten().enumerate().map(move |(index, entry)| (field, index, &entry["name"]))
    })
}

#[derive(Default)]
struct ModelCoverage { observed: usize, unavailable: usize, unknown: usize }
impl ModelCoverage {
    fn record(&mut self, status: Option<&str>) {
        match status {
            Some("observed") => self.observed += 1,
            Some("unavailable") => self.unavailable += 1,
            _ => self.unknown += 1,
        }
    }
    fn value(&self) -> Value {
        json!({"observed":self.observed,"unavailable":self.unavailable,"unknown":self.unknown})
    }
}

pub(crate) fn search(reader: &Reader, q: &Query<'_>) -> Result<Value> {
    search_with_budget(reader, q, budget())
}

fn search_with_budget(reader: &Reader, q: &Query<'_>, budget: &Arc<Budget>) -> Result<Value> {
    search_with_work(reader, q, budget, MAX_WORK)
}

fn search_with_work(reader: &Reader, q: &Query<'_>, budget: &Arc<Budget>, mut work: usize) -> Result<Value> {
    let mut results = Vec::with_capacity(q.limit);
    let mut total = 0;
    let mut partial = false;
    let mut metadata_omitted = 0;
    let mut metadata_eligible = 0;
    let mut metadata_searched = 0;
    let mut columns = ModelCoverage::default();
    let mut associations = ModelCoverage::default();
    let model_inventory = if q.domain == "source" { "not_searched" } else {
        reader.manifest["coverage"].as_array().filter(|rows| rows.len() <= 256)
            .and_then(|rows| rows.iter().find(|row| row["family"] == "rails_models"))
            .and_then(|row| row["status"].as_str()).unwrap_or("unknown")
    };
    let mut source_searched = 0;
    let mut source_eligible = 0;
    let mut source_matches_omitted = 0;
    let mut source_matches_without_span = 0;
    let mut source_unavailable = 0;
    fn emit(results: &mut Vec<Value>, total: &mut usize, limit: usize, make: impl FnOnce() -> Value) {
        *total += 1;
        if results.len() < limit { results.push(make()); }
    }
    if q.domain != "source" {
        let mut facts: Vec<&Value> = reader.facts.iter().collect();
        facts.sort_unstable_by(|a,b| a["id"].as_str().cmp(&b["id"].as_str()));
        // Constant work per fact/family, even when comparison work runs out.
        // These are capture statuses, not a claim that entries were searched.
        for fact in &facts {
            if !q.accepts(fact["kind"].as_str().unwrap(), fact["path"].as_str()) { continue; }
            metadata_eligible += 1;
            if fact["kind"] == "rails_model" {
                columns.record(fact["attributes"]["model"]["columns"]["status"].as_str());
                associations.record(fact["attributes"]["model"]["associations"]["status"].as_str());
            }
        }
        'facts: for fact in facts {
            let path = fact["path"].as_str();
            if !q.accepts(fact["kind"].as_str().unwrap(), path) { continue; }
            let identity = ["name", "kind", "path", "id"].into_iter().map(|key| (key, &fact[key]));
            let attrs = &fact["attributes"];
            let route = ["controller", "action", "route_path", "route_name", "verb", "source_status", "coherence"]
                .into_iter().filter(|_| fact["kind"] == "route").map(|key| (key, &attrs[key]));
            let status = std::iter::once(("route_constraints.status", &attrs["route_constraints"]["status"]))
                .filter(|_| fact["kind"] == "route");
            let ordinary = identity.chain(route).chain(status).map(|(field, value)| (field, None, value));
            let model = model_names(fact).map(|(field, index, value)| (field, Some(index), value));
            for (field, entry, value) in ordinary.chain(model) {
                // Charge field/entry visits, including short or omitted strings
                // for which the literal matcher needs no byte comparisons.
                let Some(remaining) = work.checked_sub(1) else { partial = true; break 'facts; };
                work = remaining;
                let Some(text) = value.as_str() else { continue; };
                if text.len() > FIELD_BYTES { metadata_omitted += 1; partial = true; continue; }
                match literal(text, q.text, &mut work) {
                    Ok(Some(start)) => {
                        emit(&mut results, &mut total, q.limit, || {
                            let mut hit = json!({"origin":"metadata", "field":field, "fact_id":fact["id"],
                            "name":fact["name"], "kind":fact["kind"], "path":path,
                            "snippet":snippet(text, start), "span":null});
                            if let Some(index) = entry {
                                hit["entry_index"] = json!(index);
                                hit["entry_name"] = json!(text);
                            }
                            hit
                        });
                        metadata_searched += 1;
                        continue 'facts;
                    },
                    Ok(None) => {},
                    Err(_) => { partial = true; break 'facts; }
                }
            }
            metadata_searched += 1;
        }
    }
    if q.domain != "source" && q.kind.is_none_or(|kind| kind == "file") {
        let mut files: Vec<&Value> = reader.manifest["files"].as_array().unwrap().iter().collect();
        files.sort_unstable_by(|a,b| a["path"].as_str().cmp(&b["path"].as_str()));
        for file in files {
            let path = file["path"].as_str().unwrap();
            if !q.accepts("file", Some(path)) { continue; }
            match literal(path, q.text, &mut work) {
                Ok(Some(start)) => emit(&mut results, &mut total, q.limit, || json!({
                    "origin":"metadata", "field":"path", "fact_id":null, "kind":"file", "name":path,
                    "path":path, "snippet":snippet(path,start), "span":null})),
                Ok(None) => {},
                Err(_) => { partial = true; break; }
            }
        }
    }
    if q.domain != "metadata" && q.kind.is_none_or(|kind| kind == "file") {
        source_eligible = reader.manifest["files"].as_array().unwrap().iter()
            .filter(|f| q.accepts("file", f["path"].as_str())).count();
    }
    if source_eligible > 0 {
        let mut cache = reader.source_index.lock().map_err(|_| CoreError::new("internal_error", "Source index lock unavailable"))?;
        if cache.is_none() { *cache = Index::build(reader, budget).ok(); }
        if let Some(index) = cache.as_ref() {
            let files = reader.manifest["files"].as_array().unwrap();
            source_unavailable = index.entries.iter().filter(|entry| entry.content.is_none() &&
                q.accepts("file", files[entry.file]["path"].as_str())).count();
            for entry in &index.entries {
                let file = &files[entry.file];
                let path = file["path"].as_str().unwrap();
                if !q.accepts("file", Some(path)) { continue; }
                let Some(content) = entry.content.as_ref() else { partial = true; continue; };
                match literal(content, q.text, &mut work) {
                    Ok(found) => {
                        if let Some(start) = found {
                            if results.len() == q.limit {
                                total += 1;
                                source_matches_omitted += 1;
                                source_searched += 1;
                                continue;
                            }
                            let end = start + q.text.len();
                            // Line counting has a separate linear pass, charged to
                            // the same operation budget, never an offset array.
                            if work < end {
                                total += 1;
                                source_searched += 1;
                                source_matches_without_span += 1;
                                partial = true;
                                break;
                            }
                            work -= end;
                            let from = content.as_bytes()[..start].iter().filter(|b| **b == b'\n').count() + 1;
                            let to = from + content.as_bytes()[start..end].iter().filter(|b| **b == b'\n').count();
                            emit(&mut results, &mut total, q.limit, || json!({"origin":"source", "field":"content", "fact_id":null,
                                "name":path, "kind":"file", "path":path, "snippet":snippet(content, start),
                                "span":{"start_byte":start,"end_byte":end,"start_line":from,"end_line":to}}));
                        }
                        source_searched += 1;
                    },
                    Err(_) => { partial = true; break; }
                }
            }
        } else { partial = true; source_unavailable = source_eligible; }
    }
    Ok(json!({"version":1, "generation":reader.generation, "query":q.text, "limit":q.limit,
        "domain":q.domain, "status":if partial { "partial" } else { "complete" },
        "truncated":total > q.limit, "total_matches":total, "total_is_lower_bound":partial,
        "results":results, "coverage":{"capture":"See generation manifest; retrieval completeness does not establish capture completeness"},
        "search_coverage":{"source_files_searched":source_searched,"source_files_unavailable":source_unavailable,
            "source_files_eligible":source_eligible, "source_files_not_searched":source_eligible - source_searched,
            "source_matching_files_omitted":source_matches_omitted, "occurrences":"first_per_file",
            "source_matches_without_span":source_matches_without_span,
            "metadata_facts_eligible":metadata_eligible,"metadata_facts_searched":metadata_searched,
            "metadata_facts_not_searched":metadata_eligible - metadata_searched,
            "model_capture_families":{"inventory":model_inventory,"columns":columns.value(),"associations":associations.value()},
            "metadata_fields_omitted":metadata_omitted,"work_remaining":work},
        "semantics":"literal; ASCII case-insensitive, other UTF-8 bytes exact; one first source match per file; names are candidates, not runtime bindings"}))
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn reservations_release_and_refuse_checked_overflow() {
        let b = Budget::new(100);
        let a = b.reserve(60).unwrap();
        assert!(b.reserve(41).is_err());
        assert!(b.reserve(usize::MAX).is_err());
        let c = b.reserve(40).unwrap();
        drop(a); drop(c);
        assert_eq!(b.used.load(Ordering::Acquire), 0);
    }
    #[test]
    fn literal_preserves_unicode_bytes_and_bounds_adversarial_work() {
        assert_eq!(literal("é <Hello> İ", "HELLO", &mut 100).unwrap(), Some(4));
        assert_eq!(literal("É", "é", &mut 100).unwrap(), None);
        assert!(literal("aaaaaaaaaaaa", "aaaaab", &mut 4).is_err());
    }
    fn capture() -> Value {
        let content = "# é\nneedle <script>\n";
        json!({"root_id":"a".repeat(64),"producer":{},"diagnostics":[],
            "coverage":[{"family":"ruby","status":"partial","scope":"fixture","reason":"owners unavailable"}],
            "files":[{"path":"spec/only.rb","content":content,"sha256":schema::digest(content.as_bytes()),"bytes":content.len(),"encoding":"UTF-8"}],
            "facts":[{"id":"b".repeat(64),"kind":"route","name":"route label","path":null,"location":null,
                "evidence":"runtime","attributes":{"controller":"metadata_only","private":"secret_only","route_constraints":{"status":"observed"}},"links":[]}]})
    }
    fn run(reader: &Reader, input: Value) -> Value { search(reader, &Query::parse(&input).unwrap()).unwrap() }
    fn model_capture(observation: &Value) -> Value {
        let mut data = capture();
        data["files"] = json!([]);
        let added = crate::model::batch(&json!({"limits":{"max_facts":100,"max_links":100,
            "max_entries":100,"max_diagnostics":10},"facts":0,"links":0,"diagnostics":0,"fact_bytes":2}), observation).unwrap();
        data["facts"] = added["facts"].clone();
        data["coverage"] = added["coverage"].clone();
        data["producer"]["model_observer"] = added["model_observer"].clone();
        data
    }
    fn models() -> Value { serde_json::from_str(include_str!("../tests/fixtures/models.json")).unwrap() }
    #[test]
    fn model_names_are_allowlisted_borrowed_first_entries_with_saved_identity() {
        let dir = tempfile::tempdir().unwrap();
        let mut observation = models();
        observation["models"][0]["associations"]["entries"][1]["target"] = json!("ForbiddenTargetCanary");
        let data = model_capture(&observation);
        let first = crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        for (query, field, index) in [("STATE", "columns", 0), ("payments", "associations", 1)] {
            let result = run(&reader, json!({"query":query,"domain":"metadata","kind":"rails_model"}));
            let hit = &result["results"][0];
            assert_eq!(result["status"], "complete");
            assert_eq!(hit["fact_id"], data["facts"][0]["id"]);
            assert_eq!(hit["field"], format!("attributes.model.{field}.entries[].name"));
            assert_eq!(hit["entry_index"], index);
            assert_eq!(hit["entry_name"], observation["models"][0][field]["entries"][index]["name"]);
            assert!(hit["path"].is_null());
            assert_eq!(result["generation"], first["generation"]);
        }
        // Neither a literal default nor target/table/type labels enter search.
        for query in ["new", "ForbiddenTargetCanary", "ApplicationRecord", "orders", "varchar"] {
            assert_eq!(run(&reader, json!({"query":query,"domain":"metadata"}))["total_matches"], 0, "{query}");
        }
        assert_eq!(run(&reader, json!({"query":"state","domain":"source"}))["total_matches"], 0);
        assert_eq!(run(&reader, json!({"query":"state","path_prefix":"app/"}))["total_matches"], 0);
        assert_eq!(run(&reader, json!({"query":"Order"}))["results"][0]["field"], "name");
        let names: Vec<_> = model_names(&data["facts"][0]).collect();
        assert!(std::ptr::eq(names[0].2, &data["facts"][0]["attributes"]["model"]["columns"]["entries"][0]["name"]));
    }
    #[test]
    fn ambiguous_model_results_and_work_omissions_are_distinct() {
        let dir = tempfile::tempdir().unwrap();
        let mut observation = models();
        let second = observation["models"][0].clone();
        observation["models"].as_array_mut().unwrap().push(second);
        let data = model_capture(&observation);
        crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let input = json!({"query":"state","domain":"metadata","limit":1});
        let full = run(&reader, input.clone());
        assert_eq!(full["total_matches"], 2);
        assert_eq!(full["truncated"], true);
        assert_eq!(full["total_is_lower_bound"], false);
        assert_eq!(full["search_coverage"]["metadata_facts_not_searched"], 0);
        let all = run(&reader, json!({"query":"state","domain":"metadata"}));
        let rows = all["results"].as_array().unwrap();
        assert!(rows[0]["fact_id"].as_str() < rows[1]["fact_id"].as_str());
        assert_eq!(rows[0]["name"], rows[1]["name"]);
        // Exactly enough work to confirm the first representative, none for
        // the second fact. No known omitted result may be invented.
        let used = MAX_WORK - all["search_coverage"]["work_remaining"].as_u64().unwrap() as usize;
        let limited = search_with_work(&reader, &Query::parse(&input).unwrap(), budget(), used / 2).unwrap();
        assert_eq!(limited["total_matches"], 1);
        assert_eq!(limited["truncated"], false);
        assert_eq!(limited["total_is_lower_bound"], true);
        assert_eq!(limited["search_coverage"]["metadata_facts_not_searched"], 1);
    }
    #[test]
    fn empty_model_families_keep_capture_uncertainty_separate_from_scan() {
        for status in ["observed", "unavailable"] {
            let dir = tempfile::tempdir().unwrap();
            let mut observation = models();
            observation["models"][0]["columns"] = json!({"status":status,"entries":[]});
            let data = model_capture(&observation);
            crate::store::publish(dir.path(), &data).unwrap();
            let reader = Reader::open(dir.path(), None).unwrap();
            let result = run(&reader, json!({"query":"absent-column","domain":"metadata"}));
            assert_eq!(result["total_matches"], 0);
            assert_eq!(result["status"], "complete");
            assert_eq!(result["search_coverage"]["model_capture_families"]["inventory"], "partial");
            assert_eq!(result["search_coverage"]["model_capture_families"]["columns"][status], 1);
            assert_eq!(result["search_coverage"]["metadata_facts_not_searched"], 0);
        }
        let missing = json!({"kind":"rails_model","attributes":{}});
        assert_eq!(model_names(&missing).count(), 0);
        let mut coverage = ModelCoverage::default();
        coverage.record(missing["attributes"]["model"]["columns"]["status"].as_str());
        assert_eq!(coverage.value()["unknown"], 1);
        let dir = tempfile::tempdir().unwrap();
        let mut observation = models();
        observation["status"] = json!("unavailable");
        observation["models"] = json!([]);
        crate::store::publish(dir.path(), &model_capture(&observation)).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let result = run(&reader, json!({"query":"state","domain":"metadata"}));
        assert_eq!(result["total_matches"], 0);
        assert_eq!(result["search_coverage"]["model_capture_families"]["inventory"], "unavailable");
    }
    #[test]
    fn short_entries_still_cost_work_and_oversized_fields_remain_omitted() {
        let dir = tempfile::tempdir().unwrap();
        let data = model_capture(&models());
        crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let input = json!({"query":"x".repeat(256),"domain":"metadata"});
        // Four identity visits, one column and two associations. None is long
        // enough for a byte comparison, but entry scanning is never free.
        let result = search_with_work(&reader, &Query::parse(&input).unwrap(), budget(), 6).unwrap();
        assert_eq!(result["status"], "partial");
        assert_eq!(result["search_coverage"]["metadata_facts_not_searched"], 1);
        assert_eq!(run(&reader, input)["search_coverage"]["work_remaining"], MAX_WORK - 7);
        let dir = tempfile::tempdir().unwrap();
        let mut data = capture();
        data["files"] = json!([]);
        data["facts"][0]["attributes"]["controller"] = json!("x".repeat(FIELD_BYTES + 1));
        crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let result = run(&reader, json!({"query":"not-in-saved-evidence","domain":"metadata"}));
        assert_eq!(result["status"], "partial");
        assert_eq!(result["search_coverage"]["metadata_fields_omitted"], 1);
        assert_eq!(result["search_coverage"]["model_capture_families"]["inventory"], "unknown");
    }
    #[test]
    fn source_metadata_filters_offsets_and_pinned_file_without_owner() {
        let dir = tempfile::tempdir().unwrap();
        let first = crate::store::publish(dir.path(), &capture()).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let result = run(&reader, json!({"query":"NEEDLE", "domain":"source"}));
        assert_eq!(result["status"], "complete");
        assert_eq!(result["results"].as_array().unwrap().len(), 1);
        let hit = &result["results"][0];
        assert_eq!(hit["fact_id"], Value::Null);
        assert_eq!(hit["kind"], "file");
        let limited = run(&reader, json!({"query":"e","limit":1}));
        assert_eq!(limited["truncated"], true);
        assert_eq!(limited["search_coverage"]["source_matching_files_omitted"], 1);
        assert_eq!(limited["search_coverage"]["source_files_not_searched"], 0);
        assert_eq!(hit["span"], json!({"start_byte":5,"end_byte":11,"start_line":2,"end_line":2}));
        assert_eq!(reader.source_file("spec/only.rb").unwrap()["content"], "# é\nneedle <script>\n");
        assert_eq!(run(&reader, json!({"query":"metadata_only","domain":"metadata"}))["results"][0]["field"], "controller");
        assert_eq!(run(&reader, json!({"query":"secret_only"}))["total_matches"], 0);
        assert_eq!(run(&reader, json!({"query":"needle","kind":"method"}))["total_matches"], 0);
        assert_eq!(run(&reader, json!({"query":"needle","path_prefix":"app/"}))["total_matches"], 0);
        let mut next = capture(); next["facts"][0]["name"] = json!("new generation");
        crate::store::publish(dir.path(), &next).unwrap();
        assert_eq!(run(&reader, json!({"query":"needle"}))["generation"], first["generation"]);
        assert!(reader.source_file("../outside").is_err());
        assert!(reader.source_file("app/absent.rb").is_err());
    }
    #[test]
    fn unmatched_source_prefix_never_locks_or_builds_the_corpus() {
        let dir = tempfile::tempdir().unwrap();
        crate::store::publish(dir.path(), &capture()).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let budget = Budget::new(1024 * 1024);
        for domain in ["source", "all"] {
            let input = json!({"query":"needle", "domain":domain, "path_prefix":"absent/"});
            let result = search_with_budget(&reader, &Query::parse(&input).unwrap(), &budget).unwrap();
            assert_eq!(result["status"], "complete");
            assert_eq!(result["total_matches"], 0);
            assert_eq!(result["search_coverage"]["source_files_eligible"], 0);
            assert_eq!(result["search_coverage"]["source_files_not_searched"], 0);
        }
        assert!(reader.source_index.lock().unwrap().is_none());
        assert_eq!(budget.used.load(Ordering::Acquire), 0);
    }
    #[test]
    fn deterministic_truncation_and_partial_cache_do_not_poison_metadata() {
        let dir = tempfile::tempdir().unwrap();
        let mut data = capture();
        let mut second = data["facts"][0].clone(); second["id"] = json!("c".repeat(64));
        data["facts"].as_array_mut().unwrap().insert(0, second);
        crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let input = json!({"query":"metadata_only","limit":1});
        let result = search_with_budget(&reader, &Query::parse(&input).unwrap(), &Budget::new(2048)).unwrap();
        assert_eq!(result["status"], "partial");
        assert_eq!(result["truncated"], true);
        assert_eq!(result["results"][0]["fact_id"], "b".repeat(64));
        assert_eq!(result["search_coverage"]["source_files_unavailable"], 1);
        assert_eq!(result["search_coverage"]["source_files_not_searched"], 1);
        assert!(reader.source_file("spec/only.rb").is_ok());
        let file_hit = run(&reader, json!({"query":"spec/only.rb","domain":"metadata"}));
        assert_eq!(file_hit["results"][0]["field"], "path");
        assert_eq!(file_hit["results"][0]["fact_id"], Value::Null);
        assert_eq!(run(&reader, json!({"query":"metadata_only","domain":"metadata"}))["status"], "complete");
    }
    #[test]
    fn verified_cache_is_once_per_file_and_new_reader_reports_corruption() {
        let dir = tempfile::tempdir().unwrap();
        let data = capture();
        crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        assert_eq!(run(&reader, json!({"query":"needle"}))["total_matches"], 1);
        let blob = dir.path().join("blobs").join(data["files"][0]["sha256"].as_str().unwrap());
        std::fs::write(blob, "broken").unwrap();
        assert_eq!(run(&reader, json!({"query":"needle"}))["total_matches"], 1);
        assert!(reader.source_file("spec/only.rb").is_err());
        let fresh = Reader::open(dir.path(), None).unwrap();
        assert_eq!(run(&fresh, json!({"query":"needle"}))["status"], "partial");
    }
    #[test]
    fn omitted_matches_do_not_spend_span_budget_or_become_unsearched() {
        let dir = tempfile::tempdir().unwrap();
        let mut data = capture();
        let content = "aaaaz";
        data["files"] = json!(["a.rb", "b.rb"].map(|path| json!({"path":path,
            "content":content,"sha256":schema::digest(content.as_bytes()),"bytes":content.len(),"encoding":"UTF-8"})));
        crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let input = json!({"query":"az","domain":"source","limit":1});
        // Two eight-comparison searches plus only the displayed five-byte span.
        let result = search_with_work(&reader, &Query::parse(&input).unwrap(), &Budget::new(1024 * 1024), 21).unwrap();
        assert_eq!(result["status"], "complete");
        assert_eq!(result["total_matches"], 2);
        assert_eq!(result["truncated"], true);
        assert_eq!(result["search_coverage"]["source_matching_files_omitted"], 1);
        assert_eq!(result["search_coverage"]["source_files_searched"], 2);
        assert_eq!(result["search_coverage"]["source_files_not_searched"], 0);
    }
    #[test]
    fn confirmed_match_survives_exhausted_span_budget_in_coverage() {
        let dir = tempfile::tempdir().unwrap();
        let mut data = capture();
        let content = "aaz";
        data["files"] = json!(["a.rb", "b.rb"].map(|path| json!({"path":path,
            "content":content,"sha256":schema::digest(content.as_bytes()),"bytes":content.len(),"encoding":"UTF-8"})));
        crate::store::publish(dir.path(), &data).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        let input = json!({"query":"az","domain":"source"});
        let result = search_with_work(&reader, &Query::parse(&input).unwrap(), &Budget::new(1024 * 1024), 4).unwrap();
        assert_eq!(result["status"], "partial");
        assert_eq!(result["total_matches"], 1);
        assert_eq!(result["total_is_lower_bound"], true);
        assert_eq!(result["results"], json!([]));
        assert_eq!(result["search_coverage"]["source_matches_without_span"], 1);
        assert_eq!(result["search_coverage"]["source_matching_files_omitted"], 0);
        assert_eq!(result["search_coverage"]["source_files_searched"], 1);
        assert_eq!(result["search_coverage"]["source_files_not_searched"], 1);
    }
    #[test]
    fn malformed_query_limits_and_domains_refuse() {
        for input in [json!({"query":" "}), json!({"query":"a","limit":0}), json!({"query":"a","limit":501}),
            json!({"query":"a","limit":"1"}),json!({"query":"a","domain":"private"}),json!({"query":"a","kind":[]})] {
            assert!(Query::parse(&input).is_err());
        }
    }

    #[test]
    fn concurrent_reservations_and_last_reader_reference_own_charges() {
        let b = Budget::new(100);
        let charge = b.reserve(80).unwrap();
        let held = Arc::new(charge);
        let in_flight = held.clone();
        drop(held);
        let other = b.clone();
        std::thread::spawn(move || assert!(other.reserve(21).is_err())).join().unwrap();
        drop(in_flight);
        assert!(b.reserve(100).is_ok());
    }
    #[test]
    fn file_source_and_index_refuse_symlinked_blob() {
        let dir = tempfile::tempdir().unwrap();
        let data = capture();
        crate::store::publish(dir.path(), &data).unwrap();
        let blob = dir.path().join("blobs").join(data["files"][0]["sha256"].as_str().unwrap());
        let target = dir.path().join("external");
        std::fs::write(&target, data["files"][0]["content"].as_str().unwrap()).unwrap();
        std::fs::remove_file(&blob).unwrap();
        std::os::unix::fs::symlink(target, blob).unwrap();
        let reader = Reader::open(dir.path(), None).unwrap();
        assert!(reader.source_file("spec/only.rb").is_err());
        assert_eq!(run(&reader, json!({"query":"needle"}))["status"], "partial");
    }

}
