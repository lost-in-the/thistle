//! Bounded, generation-local recorded relationships. Label equality is never binding.
use crate::{error::{CoreError, Result}, link_encoding::SemanticLinkView, recorded_domain, schema, store::Reader};
use serde_json::{json, Value};

const MAX_FACTS: usize = 20_000;
const MAX_LINKS: usize = 50_000;
const MAX_COMPARISONS: usize = 100_000;
const MAX_LABEL_BYTES: usize = 16 * 1024 * 1024;
const MAX_OUTPUT: usize = 2 * 1024 * 1024;
const MAX_CANDIDATES: usize = 4;
const MAX_COVERAGE: usize = 256;

pub(crate) struct Query<'a> { id: &'a str, incoming: bool, limit: usize, cursor: Option<&'a Value>, candidate_link: Option<usize> }
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
        let candidate_link = match request.get("candidate_link") { None | Some(Value::Null) => None,
            Some(v) => Some(v.as_u64().and_then(|n| usize::try_from(n).ok())
                .ok_or_else(|| CoreError::input("candidate_link must be a nonnegative integer"))?) };
        if incoming && candidate_link.is_some() { return Err(CoreError::input("Candidate pages require outgoing direction")); }
        Ok(Self { id, incoming, limit, cursor: request.get("cursor"), candidate_link })
    }
    // Covers bounded Values, escaped JSON and C/Ruby response copies. No retained index.
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
}

fn identity(fact: &Value, shared: Option<&mut crate::model_brief::RequestWork>) -> Result<Value> {
    if let Some(shared) = shared {
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
use recorded_domain::candidate_name;
fn label<'a>(link: &SemanticLinkView<'a>) -> Option<&'a str> {
    if let Some(call) = link.call_metadata() {
        // A method selector is not a class label. Only a recorded constant receiver
        // supplies a candidate label; lexical nesting/runtime dispatch stay unknown.
        return (call.kind == "constant" && !call.omitted).then_some(call.name).flatten();
    }
    Some(link.target())
}
struct Work { comparisons: usize, bytes: usize }
impl Work {
    #[cfg(test)]
    fn compare(&mut self, a: &str, b: &str) -> Option<bool> {
        self.charge(a,b,None)?;
        Some(a == b)
    }
    fn compare_scoped(&mut self, a: &str, b: &str, shared: Option<&mut crate::model_brief::RequestWork>) -> Option<bool> {
        self.charge(a,b,shared)?;
        Some(a == b)
    }
    fn charge(&mut self, a: &str, b: &str, shared: Option<&mut crate::model_brief::RequestWork>) -> Option<()> {
        let bytes = a.len().checked_add(b.len())?;
        if self.comparisons == MAX_COMPARISONS || bytes > MAX_LABEL_BYTES.saturating_sub(self.bytes) { return None; }
        if let Some(shared) = shared { if !shared.labels(bytes) { return None; } }
        self.comparisons += 1; self.bytes += bytes; Some(())
    }
}

struct ScopedLabels<'a> { work: &'a mut Work, shared: Option<&'a mut crate::model_brief::RequestWork> }
impl recorded_domain::LabelWork for ScopedLabels<'_> {
    fn compare(&mut self, a: &str, b: &str) -> Result<std::cmp::Ordering> {
        self.work.charge(a, b, self.shared.as_deref_mut())
            .ok_or_else(|| CoreError::limit("Reference label allowance unavailable"))?;
        Ok(a.cmp(b))
    }
}
fn lookup(reader: &Reader, target: &str, offset: usize, limit: usize, work: &mut Work,
    shared: Option<&mut crate::model_brief::RequestWork>) -> Result<(recorded_domain::Page, Value)> {
    reader.recorded_candidates(target, None, offset, limit,
        &mut ScopedLabels { work, shared })
}
fn capture_coverage(reader: &Reader) -> Result<Value> {
    let coverage=schema::array(&reader.manifest,"coverage")?;
    let complete=coverage.len()<=MAX_COVERAGE;
    Ok(json!({"capture_partial":coverage.is_empty() || !complete || coverage.iter().take(MAX_COVERAGE).any(|v| v["status"]!="complete"),
        "capture_families":coverage.len(),"capture_scan_complete":complete}))
}

pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> { select_scoped(reader, query, None) }

pub(crate) fn select_scoped(reader: &Reader, query: &Query<'_>, mut shared: Option<&mut crate::model_brief::RequestWork>) -> Result<Value> {
    let anchor = reader.stored_fact(query.id)?;
    let anchor_identity = identity(anchor, shared.as_deref_mut())?;
    let scope = json!(["references",query.id,query.incoming,query.candidate_link]);
    let start = recorded_domain::position(query.cursor, &reader.generation, &scope)?;
    let mut work = Work { comparisons: 0, bytes: 0 };
    if let Some(ordinal) = query.candidate_link {
        if start.1 != 0 { return Err(CoreError::input("Invalid candidate cursor position")); }
        let links = schema::array(anchor,"links")?;
        let wire = links.get(ordinal).ok_or_else(|| CoreError::input("candidate_link is outside this fact"))?;
        let link = SemanticLinkView::from_wire(wire,reader.schema_version(),schema::string(anchor,"evidence")?)?;
        let (page, directory) = if let Some(target) = label(&link) {
            lookup(reader,target,start.0,query.limit,&mut work,shared.as_deref_mut())?
        } else {
            if start.0 != 0 { return Err(CoreError::input("Invalid empty candidate cursor")); }
            (recorded_domain::Page { positions: Vec::new(), total: 0 }, json!({"status":"not_needed"}))
        };
        let mut candidates = Vec::new(); let mut bytes = 0;
        for position in page.positions {
            let item = identity(&reader.facts[position],shared.as_deref_mut())?;
            let size = schema::encoded_bytes(&item,32*1024)?;
            if size > MAX_OUTPUT.saturating_sub(bytes) { break; }
            bytes += size; candidates.push(item);
        }
        let next = start.0 + candidates.len();
        let continuation = if next < page.total {
            if next == start.0 { return Err(CoreError::limit("Candidate page made no progress")); }
            recorded_domain::cursor(&reader.generation,&scope,(next,0))?
        } else { Value::Null };
        return Ok(json!({"generation":reader.generation,"anchor":anchor_identity,"candidate_link":ordinal,
            "candidates":candidates,"candidate_matches":page.total,"candidate_search_complete":true,
            "coverage":capture_coverage(reader)?,
            "candidate_status":if page.total>1 {"ambiguous"} else if page.total==1 {"unique_label_binding_unknown"} else {"no_recorded_label_match"},
            "next_cursor":continuation,"page_complete":next==page.total,"cost":{"recorded_directory":directory,
                "comparisons":work.comparisons,"label_bytes":work.bytes},
            "semantics":"Exact saved label candidates only; no canonical binding or execution claim."}));
    }
    let facts: &[Value] = if query.incoming { &reader.facts } else { std::slice::from_ref(anchor) };
    if start.0 > facts.len() || start.0 == facts.len() && start.1 != 0 ||
        start.0 < facts.len() && start.1 > schema::array(&facts[start.0],"links")?.len() {
        return Err(CoreError::input("Continuation is outside the recorded domain"));
    }
    let anchor_label = candidate_name(anchor);
    let mut rows = Vec::new(); let mut scanned_facts = 0; let mut scanned_links = 0;
    let mut output_bytes = 0; let mut position = start;
    let mut directory = json!({"status":"not_requested","built_this_request":false});
    'facts: while position.0 < facts.len() {
        if scanned_facts == MAX_FACTS { break; }
        if let Some(shared) = shared.as_deref_mut() { if !shared.facts(1) { break; } }
        scanned_facts += 1;
        let fact = &facts[position.0];
        let links = schema::array(fact,"links")?;
        while position.1 < links.len() {
            if rows.len() == query.limit || scanned_links == MAX_LINKS { break 'facts; }
            if let Some(shared) = shared.as_deref_mut() { if !shared.links(1) { break 'facts; } }
            scanned_links += 1;
            let link = SemanticLinkView::from_wire(&links[position.1],reader.schema_version(),schema::string(fact,"evidence")?)?;
            let target = label(&link);
            let accepts = if query.incoming {
                match (target,anchor_label) {
                    (Some(a),Some(b)) => match work.compare_scoped(a,b,shared.as_deref_mut()) { Some(equal)=>equal,None=>break 'facts },
                    _ => false,
                }
            } else { true };
            if !accepts { position.1 += 1; continue; }
            let detail_omitted = schema::encoded_bytes(&link,16*1024).is_err();
            if let Some(shared) = shared.as_deref_mut() { shared.metadata(&link,2)?; }
            let detail = if detail_omitted { json!({"relation":link.relation(),"target":link.target(),"resolution":link.resolution()}) } else { link.materialize()? };
            let mut row = json!({"origin":null,"link":detail,"link_ordinal":position.1,"detail_omitted":detail_omitted,
                "match_basis":if query.incoming {"label_match_binding_unknown"} else {"recorded_outgoing_binding_unknown"},
                "candidate_label":target,"candidates":[],"candidate_matches":0,"candidate_search_complete":false});
            row["origin"] = match identity(fact,shared.as_deref_mut()) {
                Ok(value)=>value, Err(error) if error.code=="limit_exceeded" && shared.is_some()=>break 'facts, Err(error)=>return Err(error),
            };
            if query.incoming {
                if let Some(shared) = shared.as_deref_mut() { shared.metadata(&anchor_identity,2)?; }
                row["candidates"] = json!([anchor_identity]); row["candidate_matches"] = json!(1);
            } else {
                let page = if let Some(target) = target {
                    match lookup(reader,target,0,MAX_CANDIDATES,&mut work,shared.as_deref_mut()) {
                        Ok((page,stats)) => { if directory["built_this_request"] != true { directory=stats; } Some(page) },
                        Err(error) if error.code=="limit_exceeded" && (!rows.is_empty() || shared.is_some()) => break 'facts,
                        Err(error)=>return Err(error),
                    }
                } else { None };
                if let Some(page) = page {
                    row["candidate_matches"] = json!(page.total);
                    for index in page.positions {
                        let candidate = match identity(&reader.facts[index],shared.as_deref_mut()) {
                            Ok(value)=>value, Err(error) if error.code=="limit_exceeded" && shared.is_some()=>break, Err(error)=>return Err(error),
                        };
                        row["candidates"].as_array_mut().unwrap().push(candidate);
                    }
                }
                row["candidate_search_complete"] = json!(true);
                row["candidate_followup"] = json!({"operation":"references","generation":reader.generation,"id":fact["id"],"candidate_link":position.1});
            }
            let bytes = schema::encoded_bytes(&row,MAX_OUTPUT)?;
            if bytes > MAX_OUTPUT.saturating_sub(output_bytes) { break 'facts; }
            output_bytes += bytes; rows.push(row); position.1 += 1;
        }
        position.0 += 1; position.1 = 0;
    }
    let complete = position.0 == facts.len();
    // Shared brief exhaustion can return its admitted prefix. Its independent
    // public follow-up restarts this family; never emit a circular cursor.
    let next = if !complete && position != start { recorded_domain::cursor(&reader.generation,&scope,position)? }
        else if !complete && shared.is_none() { return Err(CoreError::limit("Reference page made no progress")); } else { Value::Null };
    let coverage = schema::array(&reader.manifest,"coverage")?;
    let capture_scan_complete = coverage.len() <= MAX_COVERAGE;
    let partial = coverage.is_empty() || !capture_scan_complete || coverage.iter().take(MAX_COVERAGE).any(|v| v["status"]!="complete");
    let known_omitted = if query.incoming || complete { 0 } else { schema::array(anchor,"links")?.len().saturating_sub(position.1) };
    let candidates_complete = !query.incoming;
    let mut response = json!({"generation":reader.generation,"anchor":anchor_identity,
        "direction":if query.incoming {"incoming"} else {"outgoing"},"limit":query.limit,"next_cursor":next,
        "start_position":{"fact":start.0,"link":start.1},
        "coverage":{"capture_partial":partial,"capture_families":coverage.len(),"capture_scan_complete":capture_scan_complete,
            "scan_scope":"remaining_cursor_domain",
            "scan_complete":complete,"facts_scanned":scanned_facts,"links_scanned":scanned_links,
            "known_matches":rows.len(),"known_omitted":known_omitted,"not_searched":!complete,
            "candidate_facts_scanned":0,"candidate_search_complete":candidates_complete,
            "comparisons":work.comparisons,"label_bytes":work.bytes,
            "budgets":{"facts":MAX_FACTS,"links":MAX_LINKS,"comparisons":MAX_COMPARISONS,"label_bytes":MAX_LABEL_BYTES,
                "capture_families":MAX_COVERAGE,"output_bytes":MAX_OUTPUT,"candidates_per_relationship":MAX_CANDIDATES}},
        "cost":{"recorded_directory":directory,"reader_open":reader.method_lookup_baseline()},
        "semantics":"Recorded relationship groups, not textual occurrence counts. Label matches do not establish canonical identity or runtime dispatch. Completeness concerns the remaining cursor domain; capture partiality is independent."});
    response["relationships"] = Value::Array(rows);
    if let Some(shared) = shared.as_deref_mut() { shared.metadata(&response,2)?; }
    Ok(response)
}

#[cfg(test)]
#[path = "references_tests.rs"]
mod tests;
