//! Bounded, generation-local recorded relationships. Label equality is never binding.
use crate::{error::{CoreError, Result}, link_encoding::SemanticLinkView, schema, store::Reader};
use serde_json::{json, Value};

const MAX_FACTS: usize = 20_000;
const MAX_LINKS: usize = 50_000;
const MAX_COMPARISONS: usize = 100_000;
const MAX_LABEL_BYTES: usize = 16 * 1024 * 1024;
const MAX_OUTPUT: usize = 2 * 1024 * 1024;
const MAX_CANDIDATES: usize = 4;
const MAX_COVERAGE: usize = 256;

pub(crate) struct Query<'a> { id: &'a str, incoming: bool, limit: usize }
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let id = schema::hash(schema::string(request, "id")?)?;
        let incoming = match request.get("direction").and_then(Value::as_str) {
            None if request.get("direction").is_none() => false,
            Some("outgoing") => false, Some("incoming") => true,
            _ => return Err(CoreError::input("Direction must be incoming or outgoing")),
        };
        let limit = match request.get("limit") { None => 50, Some(v) => v.as_u64()
            .filter(|n| (1..=500).contains(n)).ok_or_else(|| CoreError::input("Limit must be between 1 and 500"))? as usize };
        Ok(Self { id, incoming, limit })
    }
    // Covers bounded Values, escaped JSON and C/Ruby response copies. No retained index.
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
}

fn identity(fact: &Value, work: &mut Work<'_>) -> Result<Value> {
    if let Some(shared) = work.shared.as_deref_mut() {
        if !shared.facts(1) { return Err(CoreError::limit("Reference identity visit unavailable")); }
        for field in ["id", "kind", "name", "path", "location", "evidence"] { shared.metadata(&fact[field], 2)?; }
    }
    let value = json!({"id":fact["id"],"kind":fact["kind"],"name":fact["name"],
        "path":fact["path"],"location":if fact["location"].is_null() { Value::Null } else {
            json!({"start_line":fact["location"]["start_line"],"end_line":fact["location"]["end_line"],
                "start_byte":fact["location"]["start_byte"],"end_byte":fact["location"]["end_byte"]}) },"evidence":fact["evidence"]});
    schema::encoded_bytes(&value, 32 * 1024)?;
    Ok(value)
}
fn candidate_name(fact: &Value) -> Option<&str> {
    // Synthetic display names for anonymous runtime models are not labels.
    if (fact["kind"] == "rails_model" && fact["attributes"]["model"]["name"].is_null()) ||
        (fact["kind"] == "rails_save_callbacks" && fact["attributes"]["callbacks"]["name"].is_null()) { return None; }
    fact["name"].as_str()
}
fn label<'a>(link: &SemanticLinkView<'a>) -> Option<&'a str> {
    if let Some(call) = link.call_metadata() {
        // A method selector is not a class label. Only a recorded constant receiver
        // supplies a candidate label; lexical nesting/runtime dispatch stay unknown.
        return (call.kind == "constant" && !call.omitted).then_some(call.name).flatten();
    }
    Some(link.target())
}
struct Work<'a> { comparisons: usize, bytes: usize, shared: Option<&'a mut crate::model_brief::RequestWork> }
impl Work<'_> {
    fn compare(&mut self, a: &str, b: &str) -> Option<bool> {
        let bytes = a.len().checked_add(b.len())?;
        if self.comparisons == MAX_COMPARISONS || bytes > MAX_LABEL_BYTES.saturating_sub(self.bytes) { return None; }
        if let Some(shared) = self.shared.as_deref_mut() { if !shared.labels(bytes) { return None; } }
        self.comparisons += 1; self.bytes += bytes;
        Some(a == b)
    }
}

pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    select_scoped(reader, query, None)
}

pub(crate) fn select_scoped(reader: &Reader, query: &Query<'_>, shared: Option<&mut crate::model_brief::RequestWork>) -> Result<Value> {
    let anchor = reader.stored_fact(query.id)?;
    let anchor_label = candidate_name(anchor);
    let mut work = Work { comparisons: 0, bytes: 0, shared };
    let mut rows = Vec::new();
    let mut labels = Vec::new(); // borrowed labels only for returned outgoing rows
    let mut scanned_facts = 0;
    let mut scanned_links = 0;
    let mut matched = 0;
    let mut omitted = 0;
    let mut output_bytes = 0;
    let mut complete = true;
    let facts: &[Value] = if query.incoming { &reader.facts } else { std::slice::from_ref(anchor) };
    'facts: for fact in facts {
        if scanned_facts == MAX_FACTS { complete = false; break; }
        if let Some(shared) = work.shared.as_deref_mut() { if !shared.facts(1) { complete = false; break; } }
        scanned_facts += 1;
        for wire in schema::array(fact, "links")? {
            if scanned_links == MAX_LINKS { complete = false; break 'facts; }
            if let Some(shared) = work.shared.as_deref_mut() { if !shared.links(1) { complete = false; break 'facts; } }
            scanned_links += 1;
            let link = SemanticLinkView::from_wire(wire, reader.schema_version(), schema::string(fact, "evidence")?)?;
            let target = label(&link);
            let accepts = if query.incoming {
                match (target, anchor_label) {
                    (Some(a), Some(b)) => match work.compare(a, b) { Some(equal) => equal, None => { complete = false; break 'facts; } },
                    _ => false,
                }
            } else { true };
            if !accepts { continue; }
            matched += 1;
            if rows.len() == query.limit { omitted += 1; continue; }
            if let Some(shared) = work.shared.as_deref_mut() { shared.metadata(&link, 2)?; }
            let detail_omitted = schema::encoded_bytes(&link, 16 * 1024).is_err();
            let detail = if !detail_omitted { link.materialize()? }
                else { json!({"relation":link.relation(),"target":link.target(),"resolution":link.resolution()}) };
            let mut row = json!({"origin":null,"link":null,"detail_omitted":detail_omitted,
                "match_basis":if query.incoming { "label_match_binding_unknown" } else { "recorded_outgoing_binding_unknown" },
                "candidate_label":target,"candidates":[],"candidate_matches":0,"candidate_search_complete":false});
            row["origin"] = identity(fact, &mut work)?;
            row["link"] = detail;
            if query.incoming {
                row["candidates"] = json!([identity(anchor, &mut work)?]);
                row["candidate_matches"] = json!(1);
                // This is the selected label match, not a unique global candidate.
            }
            let bytes = schema::encoded_bytes(&row, MAX_OUTPUT)?;
            if bytes > MAX_OUTPUT.saturating_sub(output_bytes) { omitted += 1; continue; }
            output_bytes += bytes;
            rows.push(row); labels.push(target);
        }
    }
    let mut candidate_facts = 0;
    let mut candidates_complete = !query.incoming;
    if !query.incoming && !rows.is_empty() {
        'candidates: for fact in reader.facts.iter().take(MAX_FACTS) {
            if let Some(shared) = work.shared.as_deref_mut() { if !shared.facts(1) { candidates_complete = false; break; } }
            candidate_facts += 1;
            let Some(name) = candidate_name(fact) else { continue };
            for (row, target) in rows.iter_mut().zip(&labels) {
                let Some(target) = target else { continue };
                let equal = match work.compare(name, target) { Some(equal) => equal, None => { candidates_complete = false; break 'candidates; } };
                if !equal { continue; }
                row["candidate_matches"] = json!(row["candidate_matches"].as_u64().unwrap() + 1);
                if row["candidates"].as_array().unwrap().len() == MAX_CANDIDATES { continue; }
                let candidate = identity(fact, &mut work)?;
                let bytes = schema::encoded_bytes(&candidate, 32 * 1024)?;
                if bytes > MAX_OUTPUT.saturating_sub(output_bytes) { continue; }
                output_bytes += bytes;
                row["candidates"].as_array_mut().unwrap().push(candidate);
            }
        }
        candidates_complete &= candidate_facts == reader.facts.len();
        for row in &mut rows { row["candidate_search_complete"] = json!(candidates_complete); }
    }
    let coverage = schema::array(&reader.manifest, "coverage")?;
    let capture_scan_complete = coverage.len() <= MAX_COVERAGE;
    let partial = !capture_scan_complete || coverage.iter().take(MAX_COVERAGE).any(|entry| entry["status"] != "complete");
    let mut response = json!({"generation":reader.generation,"anchor":identity(anchor, &mut work)?,
        "direction":if query.incoming {"incoming"} else {"outgoing"},"limit":query.limit,
        "coverage":{"capture_partial":partial,"capture_families":coverage.len(),"capture_scan_complete":capture_scan_complete,
            "scan_complete":complete,"facts_scanned":scanned_facts,"links_scanned":scanned_links,
            "known_matches":matched,"known_omitted":omitted,"not_searched":!complete,
            "candidate_facts_scanned":candidate_facts,"candidate_search_complete":candidates_complete,
            "comparisons":work.comparisons,"label_bytes":work.bytes,
            "budgets":{"facts":MAX_FACTS,"links":MAX_LINKS,"comparisons":MAX_COMPARISONS,
                "label_bytes":MAX_LABEL_BYTES,"capture_families":MAX_COVERAGE,"output_bytes":MAX_OUTPUT,"candidates_per_relationship":MAX_CANDIDATES}},
        "semantics":"Recorded relationship groups, not textual occurrence counts. Label matches do not establish canonical identity or runtime dispatch."});
    response["relationships"] = Value::Array(rows);
    if let Some(shared) = work.shared.as_deref_mut() { shared.metadata(&response, 2)?; }
    Ok(response)
}

#[cfg(test)]
#[path = "references_tests.rs"]
mod tests;
