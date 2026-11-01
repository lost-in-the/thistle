//! Conventional saved route labels -> static instance-method candidates only.
use crate::{error::{CoreError, Result}, method_lookup::{self, Work as _}, query, recorded_domain, schema, store::Reader};
use serde_json::{json, Value};
use std::cmp::Ordering;

const MAX_VISITS: usize = 20_000;
const MAX_COMPARISONS: usize = 100_000;
const MAX_LABEL_BYTES: usize = 32 * 1024 * 1024;
pub(crate) struct Query<'a> {
    id: &'a str, limit: usize, cursor: Option<&'a Value>, max_bytes: usize,
}
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let number = |field: &str, default: usize, ceiling: usize| -> Result<usize> {
            match request.get(field) {
                None => Ok(default),
                Some(value) => value.as_u64().filter(|n| *n > 0 && *n <= ceiling as u64)
                    .map(|n| n as usize).ok_or_else(|| CoreError::input(format!("Invalid route actions {field}"))),
            }
        };
        Ok(Self { id:schema::hash(schema::string(request,"id")?)?, limit:number("limit",8,16)?,
            cursor:request.get("cursor"), max_bytes:number("max_bytes",32768,65536)? })
    }
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
}

// Deliberately independent of ActiveSupport/custom inflections. This is a
// declared spelling convention, never evidence of loaded controller binding.
fn snake(label: &str) -> bool {
    !label.is_empty() && label.split('_').all(|word| {
        word.as_bytes().first().is_some_and(u8::is_ascii_lowercase) &&
            word.bytes().all(|b| b.is_ascii_lowercase() || b.is_ascii_digit())
    })
}
fn naming(route: &Value) -> Option<(String, &str)> {
    if route["evidence"] != "runtime" || !route["path"].is_null() || !route["location"].is_null() { return None; }
    let controller = route["attributes"]["controller"].as_str()?;
    let action = route["attributes"]["action"].as_str()?;
    if controller.len() > 4096 || action.len() > 4096 || !snake(action) { return None; }
    let label = controller.strip_prefix("::").or_else(|| controller.strip_prefix('/')).unwrap_or(controller);
    if !label.split('/').all(snake) { return None; }
    let mut owner = String::with_capacity(label.len()+32);
    for (index, component) in label.split('/').enumerate() {
        if index != 0 { owner.push_str("::"); }
        for word in component.split('_') {
            owner.push((word.as_bytes()[0] as char).to_ascii_uppercase());
            owner.push_str(&word[1..]);
        }
    }
    owner.push_str("Controller");
    (owner.len() <= 4096).then_some((owner,action))
}
fn identity(fact: &Value, generation: &str) -> Value {
    let span = &fact["location"];
    json!({"generation":generation,"id":fact["id"],"kind":fact["kind"],"name":fact["name"],
        "evidence":fact["evidence"],"path":fact["path"],"span":if span.is_null() { Value::Null } else {
            json!({"start_byte":span["start_byte"],"end_byte":span["end_byte"],"start_line":span["start_line"],"end_line":span["end_line"]}) }})
}
#[derive(Default)]
struct Work { visits: usize, comparisons: usize, bytes: usize }
impl method_lookup::Work for Work {
    fn visit(&mut self) -> bool {
        if self.visits >= MAX_VISITS { return false; } self.visits+=1; true
    }
    fn bytes(&mut self, bytes: usize) -> bool {
        if bytes > MAX_LABEL_BYTES.saturating_sub(self.bytes) { return false; } self.bytes+=bytes; true
    }
    fn compare(&mut self, a: &str, b: &str) -> Option<Ordering> {
        if self.comparisons >= MAX_COMPARISONS || !self.bytes(a.len().saturating_add(b.len())) { return None; }
        self.comparisons+=1; Some(a.cmp(b))
    }
    fn compare_digest(&mut self, a: &[u8;32], b: &[u8;32]) -> Option<Ordering> {
        if self.comparisons >= MAX_COMPARISONS || !self.bytes(64) { return None; }
        self.comparisons+=1; Some(a.cmp(b))
    }
}
fn capture_complete(reader: &Reader, work: &mut Work) -> bool {
    let Some(rows) = reader.manifest["coverage"].as_array().filter(|rows| rows.len() <= 1024) else { return false; };
    let mut counts = [0;3];
    let mut complete = true;
    for row in rows {
        let family = row["family"].as_str().unwrap_or("");
        if !work.visit() || !work.bytes(family.len()) { return false; }
        if let Some(index) = ["source_inventory","ruby_declarations","rails_routes"].iter().position(|name| *name==family) {
            counts[index]+=1; complete &= row["status"]=="complete";
        }
    }
    complete && counts==[1,1,1]
}

// Borrow the already-projected response while counting the FFI success envelope.
// json!({"result": &out}) would clone every nested Value on each fit attempt.
#[derive(serde::Serialize)]
struct SuccessEnvelope<'a> { ok: bool, result: &'a Value }

pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    select_with_work(reader,query,Work::default())
}
fn select_with_work(reader: &Reader, query: &Query<'_>, mut work: Work) -> Result<Value> {
    let route = reader.stored_fact(query.id)?;
    if route["kind"] != "route" { return Err(CoreError::input("Expected a saved route")); }
    // Refuse an oversized raw route before copying any attributes/link trees.
    schema::encoded_bytes(route,query.max_bytes)?;
    let scope = json!(["route_actions",query.id]);
    let (offset,second) = recorded_domain::position(query.cursor,&reader.generation,&scope)?;
    if second != 0 { return Err(CoreError::input("Invalid route actions cursor position")); }
    let labels = naming(route);
    let partial_capture = !capture_complete(reader,&mut work);
    let mut positions = Vec::new();
    let mut stats = Value::Null;
    let (mut count,mut exact,mut complete,mut page_complete,mut next,mut partial) = (0,false,false,true,None,false);
    if let Some((owner,action)) = &labels {
        // Global ambiguity witness is separate from the visible page. lookup
        // must exhaust the exact range before zero/one can be called decided;
        // two witnesses establish ambiguity regardless of a late duplicate.
        let (found,page,cost) = reader.with_method_directory(query::budget(), |directory,built| {
            let found = directory.lookup(&reader.facts,owner,action,&mut work);
            let page = directory.page(&reader.facts,owner,action,offset,query.limit,&mut work);
            (found,page,directory.stats(built).value())
        })?;
        let page = page?;
        count = found.matches.max(page.matches_seen);
        exact = found.range_complete || page.range_complete;
        complete = found.decided;
        page_complete = page.range_complete;
        partial = page.partial || !found.decided;
        next = page.next_offset;
        positions = page.positions;
        stats = cost;
        if partial && positions.is_empty() { return Err(CoreError::limit("Route action discovery made no progress")); }
    } else if offset != 0 { return Err(CoreError::input("Unsupported route has no candidate continuation")); }
    let status = if labels.is_none() { "unsupported_route_or_naming" }
        else if !complete || partial_capture { "discovery_incomplete" }
        else if count >= 2 { "ambiguous_static_candidates" }
        else if count == 1 { "unique_static_candidate_binding_unknown" }
        else { "no_eligible_recorded_candidate" };
    // Locks have been released. Projection is bounded by 16 compact identities;
    // no candidate source files, expanded facts or live code are consulted.
    let candidates = positions.iter().map(|index| {
            let fact = &reader.facts[*index];
            let source = fact["path"].is_string() && fact["location"].is_object();
            json!({"fact":identity(fact,&reader.generation),"source_status":if source {"saved_source_available"} else {"saved_source_absent"},
                "owner_name_resolution":fact["attributes"]["name_resolution"].as_str().filter(|value| value.len() <= 128),
                "source":if source {json!({"operation":"source","generation":reader.generation,"id":fact["id"]})} else {Value::Null}})
    }).collect::<Vec<_>>();
    let cursor = next.map(|offset| recorded_domain::cursor(&reader.generation,&scope,(offset,0))).transpose()?;
    let continuation = cursor.as_ref().map(|cursor| json!({"operation":"route_actions","generation":reader.generation,"id":query.id,"cursor":cursor}));
    let mut out = json!({"version":1,"generation":reader.generation,"root":identity(route,&reader.generation),
            "route":{"attributes":route["attributes"],"links":route["links"]},
            "naming":{"rule":"ascii_snake_path_v1","owner":labels.as_ref().map(|v| &v.0),"action":labels.as_ref().map(|v| v.1),
                "status":if labels.is_some() {"conventional_labels_only"} else {"unsupported"},
                "reason":if labels.is_some() {"Custom inflections and loaded endpoint binding are unknown"} else {"Requires observed route with literal lowercase snake-case controller path and action; mounts, Rack/redirect endpoints without these defaults and custom spellings are unresolved"}},
            "status":status,"candidates":candidates,"candidate_count":{"lower_bound":count,"exact":exact},
            "coverage":{"capture_partial_or_unknown":partial_capture,"discovery_complete":complete,"page_complete":page_complete,
                "work_partial":partial,"remaining":!page_complete},"offset":offset,"next_cursor":cursor,"continuation":continuation,
            "unknowns":{"binding":"unknown","coherence":"unknown","dispatch":"unknown","reachability":"unknown","execution":"unknown"},
            "semantics":"Conventional saved-label candidates only. No inherited action resolution, runtime binding, route recognition, constraint execution or invocation is established.",
            "usage":{"candidate_visits":work.visits,"comparisons":work.comparisons,"label_bytes":work.bytes,
                "method_directory":stats,"scratch_reservation":query.scratch(),"source_reads":0,
                "budgets":{"candidate_visits":MAX_VISITS,"comparisons":MAX_COMPARISONS,"label_bytes":MAX_LABEL_BYTES},
                "scope":"Directory construction is lazy and retained on this Reader. Page offsets repeat and charge prefix work; zero progress refuses. No latency, heap or RSS claim."}});
    loop {
        // Preserve one byte of headroom; the FFI JSON CString has no newline.
        let fit = schema::encoded_bytes(&SuccessEnvelope { ok:true, result:&out },query.max_bytes.saturating_sub(1));
        match fit {
            Ok(_) => return Ok(out),
            Err(error) => {
                let rows = out["candidates"].as_array_mut().unwrap();
                if rows.len() <= 1 { return Err(error); }
                rows.pop();
                let kept = rows.len();
                let cursor = recorded_domain::cursor(&reader.generation,&scope,(offset+kept,0))?;
                out["next_cursor"] = cursor.clone();
                out["continuation"] = json!({"operation":"route_actions","generation":reader.generation,"id":query.id,"cursor":cursor});
                out["coverage"]["page_complete"] = json!(false);
                out["coverage"]["remaining"] = json!(true);
            }
        }
    }
}

#[cfg(test)]
#[path = "route_actions_tests.rs"]
mod tests;
