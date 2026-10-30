//! Descriptor-matched saved declarations; never proof of live binding/execution.
use crate::{error::{CoreError, Result}, link_encoding::SemanticLinkView, schema, store::Reader};
use serde_json::{json, Value};
use std::cmp::Ordering;

const MAX_FACTS: usize = 20_000;
const MAX_LINKS: usize = 50_000;
const MAX_LABEL_BYTES: usize = 32 * 1024 * 1024;
const MAX_FILES: usize = 16;
const MAX_FILE_BYTES: usize = 256 * 1024;
const MAX_SOURCE_BYTES: usize = 1024 * 1024;
const MAX_OUTPUT: usize = 128 * 1024;
const MAX_ROWS_BYTES: usize = 96 * 1024;
const MAX_METADATA: usize = 8 * 1024;
const MAX_EFFECTS: usize = 8;
const SEMANTICS: &str = "Registered metadata, source-supported potential operations and observed execution are separate evidence families. Descriptor-matched captured declaration only; runtime/source coherence, constant identity, ActiveJob ancestry, runtime dispatch, condition/branch satisfaction, invocation, job delivery and execution are unknown. No observed enqueue. Representative call groups are non-exhaustive; lexical occurrence is not execution order. No supported match never means no possible effect.";

pub(crate) struct Query<'a> { id: &'a str, limit: usize }
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let id = schema::hash(schema::string(request, "id")?)?;
        let limit = match request.get("limit") { None => 50, Some(v) => v.as_u64()
            .filter(|n| (1..=200).contains(n)).ok_or_else(|| CoreError::input("Limit must be between 1 and 200"))? as usize };
        Ok(Self { id, limit })
    }
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
}

#[derive(Default)]
struct Work { facts: usize, links: usize, label_bytes: usize, files: usize, source_bytes: usize }
impl Work {
    fn compare(&mut self, a: &str, b: &str) -> Option<Ordering> {
        let bytes = a.len().checked_add(b.len())?;
        if bytes > MAX_LABEL_BYTES.saturating_sub(self.label_bytes) { return None; }
        self.label_bytes += bytes;
        Some(a.cmp(b))
    }
}
struct Group<'a> { owner: &'a str, name: &'a str, count: usize, candidate: Option<&'a Value>, result: Value }
fn unknown(reason: &str) -> Value {
    json!({"status":"unknown","reason":reason,"binding":"unavailable","effects":[],"links_search_complete":false})
}
// Explicit charged binary search: one fact pass, O(F log C), borrowed keys.
fn lookup(groups: &[Group<'_>], owner: &str, name: &str, work: &mut Work) -> Option<std::result::Result<usize, usize>> {
    let (mut lo, mut hi) = (0, groups.len());
    while lo < hi {
        let mid = lo + (hi - lo) / 2;
        let mut order = work.compare(groups[mid].owner, owner)?;
        if order == Ordering::Equal { order = work.compare(groups[mid].name, name)?; }
        match order { Ordering::Less => lo = mid + 1, Ordering::Greater => hi = mid, Ordering::Equal => return Some(Ok(mid)) }
    }
    Some(Err(lo))
}
fn descriptor(entry: &Value) -> Option<(&str, &str)> {
    let filter = &entry["filter"];
    if filter["kind"] != "method" { return None; }
    let owner = filter["owner"].as_str().filter(|s| !s.is_empty() && !s.contains(['<', '>']))?;
    let name = filter["name"].as_str()?;
    filter["source"]["path"].as_str()?;
    filter["source"]["line"].as_u64()?;
    Some((owner, name))
}
fn method_span(fact: &Value) -> Value {
    let location = &fact["location"];
    json!({"start_byte":location["start_byte"],"end_byte":location["end_byte"],
        "start_line":location["start_line"],"end_line":location["end_line"]})
}
fn span(location: schema::CallLocation) -> Value {
    json!({"start_byte":location.start_byte,"end_byte":location.end_byte,
        "start_line":location.start_line,"end_line":location.end_line})
}
fn bounds(fact: &Value) -> Option<(u64, u64)> {
    let start = fact["location"]["start_byte"].as_u64()?;
    let end = fact["location"]["end_byte"].as_u64()?;
    (end > start).then_some((start, end))
}
fn fits_descriptor(group: &Group<'_>, entry: &Value, work: &mut Work) -> Option<bool> {
    let fact = group.candidate?;
    let filter = &entry["filter"];
    let expected = format!("{}#{}", group.owner, group.name);
    Some(fact["attributes"]["singleton"] == false && fact["attributes"]["name_resolution"] == "lexical" &&
        work.compare(fact["name"].as_str()?, &expected)? == Ordering::Equal &&
        work.compare(fact["path"].as_str()?, filter["source"]["path"].as_str()?)? == Ordering::Equal &&
        fact["location"]["start_line"] == filter["source"]["line"] && bounds(fact).is_some())
}

fn explain(fact: &Value, file: &Value, version: u64, lines: usize, work: &mut Work) -> Result<Value> {
    // Caller has charged and validated this entire method, including every call
    // and receiver coordinate, against the actual digest-checked saved bytes.
    let content = schema::string(file, "content")?;
    let (start, end) = bounds(fact).expect("checked complete method span");
    let mut effects = Vec::new();
    let mut omitted = 0;
    for wire in schema::array(fact, "links")? {
        let link = SemanticLinkView::from_wire(wire, version, "static")?;
        if link.relation() != "calls" || link.target() != "perform_later" { continue; }
        let Some(call) = link.call_metadata() else { continue; };
        if call.kind != "constant" || call.omitted { continue; }
        let Some(receiver) = call.name else { continue; };
        let Some(receiver_span) = call.receiver_location else { continue; };
        if call.location.end_byte <= call.location.start_byte ||
            receiver_span.start_byte < call.location.start_byte || receiver_span.end_byte > call.location.end_byte ||
            receiver_span.end_byte <= receiver_span.start_byte {
            return Err(CoreError::snapshot("Callback call/receiver span disagrees with its captured source"));
        }
        // Prism can associate a heredoc interpolation with this method while
        // its bytes follow the lexical `end`. File coordinates were verified
        // above; non-containment alone is not snapshot corruption. Keep this
        // deliberately narrow explanation unknown rather than infer ownership
        // across discontiguous source or claim exhaustive absence.
        if call.location.start_byte < start || call.location.end_byte > end {
            return Ok(unknown("recorded_call_outside_lexical_method_span"));
        }
        // Stored metadata has validated shape/coordinates, not lexical labels.
        // Corroborate this deliberately narrow direct-call spelling against the
        // saved bytes before promoting it to source-supported potential. Exact
        // receiver equality also charges these comparisons to the shared cap.
        let receiver_text = &content[receiver_span.start_byte as usize..receiver_span.end_byte as usize];
        let tail = &content[receiver_span.end_byte as usize..call.location.end_byte as usize];
        let prefix = if call.safe_navigation { "&.perform_later" } else { ".perform_later" };
        let boundary = tail.strip_prefix(prefix).is_some_and(|rest|
            rest.as_bytes().first().is_none_or(|b| matches!(*b, b'(' | b'{')));
        if receiver_span.start_byte != call.location.start_byte ||
            work.compare(receiver_text, receiver) != Some(Ordering::Equal) || !boundary {
            return Ok(unknown("recorded_call_spelling_not_corroborated"));
        }
        if effects.len() == MAX_EFFECTS { omitted += 1; continue; }
        let text = &content[call.location.start_byte as usize..call.location.end_byte as usize];
        // Bounded supporting excerpt; exact complete half-open span and digest
        // remain available even when arguments make the representative call long.
        let mut last = text.len().min(512);
        while !text.is_char_boundary(last) { last -= 1; }
        effects.push(json!({"kind":"potential_enqueue_style_request","operation":format!("{receiver}.perform_later"),
            "receiver":receiver,"selector":"perform_later","safe_navigation":call.safe_navigation,
            "provenance":"captured_source_potential","call_span":span(call.location),"receiver_span":span(receiver_span),
            "source_excerpt":&text[..last],"excerpt_truncated":last < text.len()}));
    }
    let mut result = json!({"status":if effects.is_empty() {"no_supported_match"} else {"supported_potential"},
        "reason":if effects.is_empty() {"no_supported_recorded_call_in_searched_declaration"} else {"recorded_constant_receiver_perform_later"},
        "binding":"descriptor_matched_captured_declaration","coherence":"unknown","links_search_complete":true,
        "method":{"id":fact["id"],"name":fact["name"],"owner":fact["attributes"]["owner"],
            "method_name":fact["attributes"]["method_name"],"path":fact["path"],"span":method_span(fact)},
        "source":{"path":file["path"],"sha256":file["sha256"],"bytes":file["bytes"],
            "lines":lines},
        "effects":null,"known_effects_omitted":omitted,"effects_non_exhaustive":true});
    result["effects"] = Value::Array(effects);
    Ok(result)
}

pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    let anchor = reader.stored_fact(query.id)?;
    if anchor["kind"] != "rails_save_callbacks" { return Err(CoreError::input("callback_effects requires a rails_save_callbacks fact ID")); }
    let data = &anchor["attributes"]["callbacks"];
    let entries = schema::array(&data["save"], "entries")?;
    let mut work = Work { facts: 1, ..Work::default() };
    let mut groups = Vec::new();
    let mut selected = Vec::new();
    let mut metadata_omitted = 0;
    let mut rows_attempted = 0;
    let mut scan_complete = true;
    for entry in entries.iter().take(query.limit) {
        rows_attempted += 1;
        match schema::encoded_bytes(entry, MAX_METADATA) {
            Ok(_) => {}, Err(e) if e.code == "limit_exceeded" => { metadata_omitted += 1; continue; }, Err(e) => return Err(e),
        }
        selected.push(entry);
        if let Some((owner, name)) = descriptor(entry) {
            match lookup(&groups, owner, name, &mut work) {
                Some(Err(at)) => groups.insert(at, Group { owner, name, count: 0, candidate: None, result: unknown("captured_declaration_unavailable") }),
                Some(Ok(_)) => {}, None => { scan_complete = false; break; },
            }
        }
    }
    if !groups.is_empty() && scan_complete {
        for fact in &reader.facts {
            if work.facts == MAX_FACTS { scan_complete = false; break; }
            work.facts += 1;
            if fact["kind"] != "method" || fact["evidence"] != "static" || fact["attributes"]["singleton"] == true { continue; }
            let (Some(owner), Some(name)) = (fact["attributes"]["owner"].as_str(), fact["attributes"]["method_name"].as_str()) else { continue; };
            match lookup(&groups, owner, name, &mut work) {
                Some(Ok(at)) => { groups[at].count += 1; groups[at].candidate = Some(fact); },
                Some(Err(_)) => {}, None => { scan_complete = false; break; },
            }
        }
    }
    // One source read per unique selected path. Group all methods for the file
    // into one schema validation, avoiding repeated newline indexes/validation.
    let mut paths = Vec::<&str>::new();
    for group in &mut groups {
        if !scan_complete { group.result = unknown("declaration_uniqueness_scan_incomplete"); continue; }
        if group.count > 1 { group.result = unknown("ambiguous_duplicate_instance_declarations"); continue; }
        let Some(fact) = group.candidate else { continue; };
        if fact["attributes"]["singleton"] != false || fact["attributes"]["name_resolution"] != "lexical" || bounds(fact).is_none() {
            group.result = unknown("unsupported_or_incomplete_declaration"); continue;
        }
        let Some(path) = fact["path"].as_str() else { continue; };
        // Check at least one observed descriptor before spending source work.
        let mut matches = false;
        for entry in &selected {
            let Some((owner, name)) = descriptor(entry) else { continue; };
            if work.compare(owner, group.owner) != Some(Ordering::Equal) ||
                work.compare(name, group.name) != Some(Ordering::Equal) { continue; }
            matches |= fits_descriptor(group, entry, &mut work).unwrap_or(false);
        }
        if !matches { group.result = unknown("observed_descriptor_mismatch_or_label_budget"); continue; }
        let mut present = false;
        for old in &paths { present |= work.compare(old, path) == Some(Ordering::Equal); }
        if !present { paths.push(path); }
        group.result = unknown("source_not_searched");
    }
    for path in paths {
        let indexes: Vec<usize> = groups.iter().enumerate().filter_map(|(i, g)| {
            if g.result["reason"] != "source_not_searched" { return None; }
            (work.compare(g.candidate.unwrap()["path"].as_str().unwrap(), path) == Some(Ordering::Equal)).then_some(i)
        }).collect();
        if work.files == MAX_FILES {
            for i in indexes { groups[i].result = unknown("source_file_attempt_budget"); }
            continue;
        }
        work.files += 1; // Missing/oversized/failed attempts are charged too.
        let mut file = None;
        for item in schema::array(&reader.manifest, "files")? {
            match work.compare(item["path"].as_str().unwrap(), path) {
                Some(Ordering::Equal) => { file = Some(item); break; }, Some(_) => {}, None => break,
            }
        }
        let Some(file) = file else {
            for i in indexes { groups[i].result = unknown("source_metadata_unavailable_or_label_budget"); }
            continue;
        };
        let bytes = file["bytes"].as_u64().unwrap() as usize;
        if bytes > MAX_FILE_BYTES || bytes > MAX_SOURCE_BYTES.saturating_sub(work.source_bytes) {
            for i in indexes { groups[i].result = unknown("source_byte_budget"); }
            continue;
        }
        work.source_bytes += bytes;
        let mut admitted = Vec::new();
        for i in indexes {
            let count = schema::array(groups[i].candidate.unwrap(), "links")?.len();
            // Validation and explanation each visit every link, including misses.
            if count > (MAX_LINKS - work.links) / 2 {
                groups[i].result = unknown("link_visit_budget"); continue;
            }
            if work.facts > MAX_FACTS - 2 {
                groups[i].result = unknown("fact_visit_budget"); continue;
            }
            // The schema and explanation revisit this selected method too.
            work.facts += 2;
            work.links += count * 2;
            admitted.push(i);
        }
        if admitted.is_empty() { continue; }
        let content = match reader.source_bytes(file) {
            Ok(content) => content,
            Err(e) if e.code == "not_found" => { for i in admitted { groups[i].result = unknown("saved_source_blob_missing"); } continue; },
            Err(e) => return Err(e),
        };
        let lines = content.bytes().filter(|b| *b == b'\n').count() + usize::from(!content.ends_with('\n'));
        let mut expanded = json!({"path":file["path"],"sha256":file["sha256"],"bytes":file["bytes"]});
        expanded["content"] = Value::String(content);
        schema::stored_facts(admitted.iter().map(|i| groups[*i].candidate.unwrap()), std::slice::from_ref(&expanded), reader.schema_version())
            .map_err(|_| CoreError::snapshot("Callback source positions disagree with captured bytes"))?;
        for i in admitted { groups[i].result = explain(groups[i].candidate.unwrap(), &expanded, reader.schema_version(), lines, &mut work)?; }
    }
    let mut rows = Vec::new();
    let mut output_bytes = 0;
    let mut output_omitted = 0;
    for entry in selected {
        let explanation = if let Some((owner, name)) = descriptor(entry) {
            match lookup(&groups, owner, name, &mut work) {
                Some(Ok(at)) if scan_complete && groups[at].result["binding"] == "descriptor_matched_captured_declaration" => {
                    if fits_descriptor(&groups[at], entry, &mut work) == Some(true) { groups[at].result.clone() }
                    else { unknown("observed_descriptor_mismatch_or_label_budget") }
                },
                Some(Ok(at)) => groups[at].result.clone(),
                _ => unknown("declaration_uniqueness_scan_incomplete"),
            }
        } else { unknown("opaque_or_incomplete_observed_method_descriptor") };
        let mut row = json!({"callback_id":format!("{}:{}", query.id, entry["position"]),
            "registry_id":query.id,"position":entry["position"],"kind":entry["kind"],"filter":entry["filter"],
            "if":entry["if"],"unless":entry["unless"],"inherited":entry["inherited"],
            "registry_provenance":"registered_metadata","explanation":null});
        row["explanation"] = explanation;
        let bytes = schema::encoded_bytes(&row, MAX_ROWS_BYTES)?;
        if bytes > MAX_ROWS_BYTES.saturating_sub(output_bytes) { output_omitted += 1; continue; }
        output_bytes += bytes; rows.push(row);
    }
    let coverage = schema::array(&reader.manifest, "coverage")?;
    let capture_unknown = coverage.is_empty() || coverage.len() > 256 || coverage.iter().take(256).any(|c| c["status"] != "complete");
    let mut response = json!({"version":1,"generation":reader.generation,"registry_id":query.id,"model":data["name"],
        "registry_status":data["save"]["status"],"coherence":"unknown","execution":"unknown","limit":query.limit,
        "callbacks":null,"semantics":SEMANTICS,"coverage":{"capture_partial_or_unknown":capture_unknown,
            "declaration_scan_complete":scan_complete,"facts_visited":work.facts,"links_visited":work.links,
            "compared_label_bytes":work.label_bytes,"source_files_attempted":work.files,"source_bytes_charged":work.source_bytes,
            "rows_attempted":rows_attempted,"rows_not_searched":entries.len()-rows_attempted,
            "rows_metadata_omitted":metadata_omitted,"rows_output_omitted":output_omitted,
            "truncated":entries.len()>rows_attempted || metadata_omitted>0 || output_omitted>0,
            "absence":"No supported match in searched recorded evidence does not establish no possible effect",
            "budgets":{"callbacks":200,"facts":MAX_FACTS,"links":MAX_LINKS,"label_bytes":MAX_LABEL_BYTES,
                "files":MAX_FILES,"file_bytes":MAX_FILE_BYTES,"source_bytes":MAX_SOURCE_BYTES,"output_bytes":MAX_OUTPUT,
                "row_metadata_bytes":MAX_METADATA,"effects_per_method":MAX_EFFECTS}}});
    response["callbacks"] = Value::Array(rows);
    schema::encoded_bytes(&response, MAX_OUTPUT)?;
    Ok(response)
}

#[cfg(test)]
#[path = "callback_effects_tests.rs"]
mod tests;
