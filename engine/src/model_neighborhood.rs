//! One saved model, raw schema and one-hop evidence. Never a resolver or ERD.
use crate::{error::{CoreError, Result}, model_brief::RequestWork, recorded_domain,
    references, schema, store::Reader};
use serde::Serialize;
use serde_json::{json, Value};

const SEMANTICS: &str = "Saved one-hop evidence: declarations, references and DB constraints are distinct. Name candidates are saved representations, not distinct definitions or resolved bindings. Missing targets may be unloaded/uncaptured. Runtime/source coherence and execution remain unknown. Empty searched evidence never proves absence.";

pub(crate) struct Query<'a> {
    id: &'a str, family: &'a str, direction: &'a str, kind: &'a str,
    candidate: Option<&'a str>, limit: usize, cursor: Option<&'a Value>, max_bytes: usize,
}
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let choice = |key: &str, default: &'a str, allowed: &[&str]| -> Result<&'a str> {
            request.get(key).map_or(Some(default), Value::as_str).filter(|s| allowed.contains(s))
                .ok_or_else(|| CoreError::input(format!("Invalid model neighborhood {key}")))
        };
        let number = |key: &str, default: usize, max: usize| -> Result<usize> {
            request.get(key).map_or(Some(default as u64), Value::as_u64)
                .filter(|n| *n > 0 && *n <= max as u64).map(|n| n as usize)
                .ok_or_else(|| CoreError::input(format!("Invalid model neighborhood {key}")))
        };
        let family = choice("family", "edges", &["edges", "columns", "database", "candidates"])?;
        let direction = choice("direction", "outgoing", &["incoming", "outgoing"])?;
        let kind = choice("type", "all", &["all", "association", "reference"])?;
        let candidate = match request.get("candidate") {
            None | Some(Value::Null) => None,
            Some(v) => Some(v.as_str().ok_or_else(|| CoreError::input("Candidate selector required"))?),
        };
        if (family == "candidates") != candidate.is_some() || family == "candidates" && direction != "outgoing" {
            return Err(CoreError::input("Candidates require outgoing scope and exactly one selector"));
        }
        if let Some(selector) = candidate { candidate_position(selector)?; }
        if matches!(family, "columns" | "database") && (direction != "outgoing" || kind != "all") {
            return Err(CoreError::input("Schema families require outgoing/all scope"));
        }
        Ok(Self { id: schema::hash(schema::string(request, "id")?)?, family, direction, kind, candidate,
            limit: number("limit", 8, 16)?, cursor: request.get("cursor"), max_bytes: number("max_bytes", 32768, 65536)? })
    }
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
    fn scope(&self) -> Value { json!(["model_neighborhood", self.id, self.family, self.direction, self.kind, self.candidate]) }
}

fn candidate_position(selector: &str) -> Result<(&str, usize)> {
    let (family, ordinal) = selector.split_once(':').ok_or_else(|| CoreError::input("Invalid candidate selector"))?;
    if !["a", "r"].contains(&family) || ordinal.is_empty() || ordinal.len() > 6 ||
        !ordinal.bytes().all(|b| b.is_ascii_digit()) || ordinal.len() > 1 && ordinal.starts_with('0') {
        return Err(CoreError::input("Invalid candidate selector"));
    }
    Ok((family, ordinal.parse().map_err(|_| CoreError::input("Invalid candidate ordinal"))?))
}
fn project(value: &Value, fields: &[&str], work: &mut RequestWork) -> Result<Value> {
    let mut out = serde_json::Map::new();
    for key in fields { work.metadata(&value[*key], 2)?; out.insert((*key).into(), value[*key].clone()); }
    Ok(Value::Object(out))
}
fn identity(fact: &Value, work: &mut RequestWork) -> Result<Value> {
    if !work.facts(1) { return Err(CoreError::limit("Neighborhood identity allowance")); }
    project(fact, &["id", "name", "kind", "evidence", "path", "location"], work)
}
fn candidates(reader: &Reader, label: Option<&str>, offset: usize, limit: usize,
    work: &mut RequestWork) -> Result<(Vec<Value>, usize, Value)> {
    let Some(label) = label else {
        if offset != 0 { return Err(CoreError::input("Unknown target has no candidates")); }
        return Ok((Vec::new(), 0, json!({"status":"not_needed"})));
    };
    // Reuse the generation-local borrowed-label directory, never copy/build an index here.
    struct Labels<'a> { work: &'a mut RequestWork, original: &'a str }
    impl recorded_domain::LabelWork for Labels<'_> {
        fn compare(&mut self, a: &str, b: &str) -> Result<std::cmp::Ordering> {
            if !self.work.labels(a.len().saturating_add(self.original.len())) {
                return Err(CoreError::limit("Association candidate label allowance"));
            }
            Ok(a.cmp(b))
        }
    }
    let (page, cost) = reader.recorded_candidates(recorded_domain::constant_label(label), None, offset, limit,
        &mut Labels { work, original:label })?;
    let mut items = Vec::new();
    for position in page.positions { items.push(identity(&reader.facts[position], work)?); }
    Ok((items, page.total, cost))
}
fn status(label: Option<&str>, count: usize) -> &'static str {
    if label.is_none() { "unknown_target" } else if count == 0 { "missing_or_unloaded" }
    else if count == 1 { "one_saved_representation_binding_unknown" } else { "ambiguous_saved_representations" }
}
fn remember_directory(response: &mut Value, mut cost: Value) {
    // Keep the actual construction/retention counters, without repeating the
    // directory's long constant accounting prose in every compact page.
    if let Some(fields) = cost.as_object_mut() {
        for key in ["accounting", "eligible_facts", "slot_capacity", "slot_bytes"] { fields.remove(key); }
    }
    if response["cost"]["recorded_directory"]["built_this_request"] != true && cost["status"] == "complete" {
        response["cost"]["recorded_directory"] = cost;
    }
}
#[derive(Serialize)]
struct Success<'a> { ok: bool, result: &'a Value }
fn wire_bytes(response: &Value, max: usize) -> Result<usize> {
    // C uses this success envelope; one additional byte covers a line-oriented caller.
    Ok(schema::encoded_bytes(&Success { ok: true, result: response }, max.saturating_sub(1))? + 1)
}

pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    select_with_work(reader, query, &mut RequestWork::default())
}
struct Step { item: Option<Value>, next: (usize, usize), complete: bool, total: Option<usize> }
struct AdmittedDiagnostics {
    coverage: Value, cost: Value, position: (usize, usize), complete: bool, total: Option<usize>,
}
fn page_state(response: &mut Value, reader: &Reader, query: &Query<'_>, position: (usize, usize),
    complete: bool, total: Option<usize>) -> Result<()> {
    response["coverage"]["page_complete"] = json!(complete);
    response["coverage"]["unsearched"] = json!(!complete);
    response["coverage"]["known_remaining"] = if complete { json!(0) } else { total.map(|n| json!(n.saturating_sub(position.0))).unwrap_or(Value::Null) };
    response["coverage"]["recorded_candidates_total"] = if query.family == "candidates" { total.map(|n| json!(n)).unwrap_or(Value::Null) } else { Value::Null };
    response["next_cursor"] = if complete { Value::Null } else { recorded_domain::cursor(&reader.generation, &query.scope(), position)? };
    response["usage"]["returned_items"] = json!(response["items"].as_array().unwrap().len());
    response["usage"]["wire_bytes_including_envelope_and_newline"] = json!(65536);
    Ok(())
}
fn select_with_work(reader: &Reader, query: &Query<'_>, work: &mut RequestWork) -> Result<Value> {
    let root = reader.stored_fact(query.id)?;
    if root["kind"] != "rails_model" { return Err(CoreError::input("Neighborhood requires a rails_model saved ID")); }
    let model = &root["attributes"]["model"];
    let associations = schema::array(&model["associations"], "entries")?;
    let start = recorded_domain::position(query.cursor, &reader.generation, &query.scope())?;
    let mut position = start;
    if query.family=="edges" && query.direction=="outgoing" && query.kind=="association" &&
        (position.0>associations.len() || position.1!=0) {
        return Err(CoreError::input("Association continuation is outside model metadata"));
    }
    if query.family == "edges" && query.direction == "outgoing" && query.kind == "reference" && position.0 < associations.len() {
        if position.1 != 0 { return Err(CoreError::input("Invalid excluded association position")); }
        position = (associations.len(), 0);
    }
    let coverage = schema::array(&reader.manifest, "coverage")?;
    let mut capture = Vec::new();
    for family in coverage.iter().take(256).filter(|v| v["status"] != "complete") {
        capture.push(project(family, &["family", "status"], work)?);
    }
    let mut response = json!({"version":1,"generation":reader.generation,"root":null,"model":null,
        "family":query.family,"direction":query.direction,"type":query.kind,"candidate":query.candidate,
        "candidate_context":null,"semantics":SEMANTICS,"items":[],"next_cursor":null,
        "coverage":{"page_complete":false,"unsearched":false,"known_remaining":null,"recorded_candidates_total":null,
            "columns_status":model["columns"]["status"],"associations_status":model["associations"]["status"],
            "recorded_associations":associations.len(),"capture_partial_or_unknown":coverage.is_empty() || coverage.len()>256 || !capture.is_empty(),
            "noncomplete_capture_families":capture,"capture_families":coverage.len(),"capture_families_not_examined":coverage.len().saturating_sub(256),
            "candidate_count_unit":"saved_representations_not_distinct_model_definitions",
            "default_presence":"not_recorded","database_constraints_indexes_on_delete":"not_recorded","last_reference_step":null},
        "cost":{"reader_open":null,"recorded_directory":{"status":"not_requested","built_this_request":false},
            "reference_attempts":0,"completed_reference_steps":0,"completed_step_work":{"facts_scanned":0,"links_scanned":0,"comparisons":0,"label_bytes":0},
            "transient_reservation_bytes":query.scratch(),"source_attempts":0},
        "usage":{"returned_items":0,"wire_bytes_including_envelope_and_newline":65536}});
    response["root"] = identity(root, work)?;
    response["model"] = project(model, &["name", "table", "primary_key", "base_class", "superclass", "abstract", "inheritance_column", "source", "coherence"], work)?;
    let open = reader.method_lookup_baseline();
    work.metadata(&open, 1)?;
    let mut open_visits = 0u64;
    for count in open["completed_open_fact_passes"].as_object().ok_or_else(|| CoreError::new("internal_error", "Reader-open accounting unavailable"))?.values() {
        open_visits = open_visits.checked_add(count.as_u64().ok_or_else(|| CoreError::new("internal_error", "Reader-open count unavailable"))?)
            .ok_or_else(|| CoreError::limit("Reader-open count overflow"))?;
    }
    response["cost"]["reader_open"] = json!({"facts":open["facts"],"fact_visits":open_visits});
    if let Some(selector) = query.candidate {
        let (family, ordinal) = candidate_position(selector)?;
        if family == "a" {
            if query.kind == "reference" { return Err(CoreError::input("Association candidate outside type filter")); }
            let entry = associations.get(ordinal).ok_or_else(|| CoreError::input("Association outside model"))?;
            let context = project(entry, &["name", "target", "macro"], work)?;
            response["candidate_context"] = json!({"kind":"association","name":context["name"],"target_label":context["target"],"selector":selector});
        } else {
            let links = schema::array(root, "links")?;
            let wire = links.get(ordinal).ok_or_else(|| CoreError::input("Reference outside model"))?;
            if !work.links(1) { return Err(CoreError::limit("Candidate link allowance")); }
            let link = crate::link_encoding::SemanticLinkView::from_wire(wire, reader.schema_version(), schema::string(root, "evidence")?)?;
            let association = link.relation() == "association_target_label";
            if query.kind == "association" && !association || query.kind == "reference" && association {
                return Err(CoreError::input("Reference candidate outside type filter"));
            }
            work.metadata(&link.target(), 2)?;
            work.metadata(&link.relation(), 2)?;
            response["candidate_context"] = json!({"kind":"reference","name":link.relation(),"target_label":link.target(),"selector":selector});
        }
    }
    work.metadata(&response, 1)?;
    wire_bytes(&response, query.max_bytes)?;
    let mut admitted = None;
    let mut complete = false;
    let mut known_total = None;
    while response["items"].as_array().unwrap().len() < query.limit && !complete {
        let before = position;
        let mut failure_position = before;
        // Only positions/owned temporary rows are staged. RequestWork is never
        // cloned/restored: visits, failed metadata and all attempts remain charged.
        let attempt = (|| -> Result<Step> {
            if query.family == "columns" {
                let columns = schema::array(&model["columns"], "entries")?;
                if before.1 != 0 || before.0 > columns.len() { return Err(CoreError::input("Invalid columns position")); }
                if before.0 == columns.len() { return Ok(Step { item:None,next:before,complete:true,total:Some(columns.len()) }); }
                if !work.facts(1) { return Err(CoreError::limit("Neighborhood column allowance")); }
                // Current saved model schema requires the tagged value. It says
                // nothing about whether an explicit DEFAULT clause was present.
                let data = project(&columns[before.0], &["name", "type", "sql_type", "null", "default"], work)?;
                let item = json!({"kind":"column","ordinal":before.0,"column":data});
                work.metadata(&item, 2)?;
                return Ok(Step { item:Some(item),next:(before.0+1,0),complete:before.0+1==columns.len(),total:Some(columns.len()) });
            }
            if query.family == "database" {
                if before != (0, 0) { return Err(CoreError::input("Database facts have no continuation")); }
                return Ok(Step { item:None,next:before,complete:true,total:Some(0) });
            }
            if query.family == "candidates" {
                if before.1 != 0 { return Err(CoreError::input("Invalid candidate position")); }
                let (family, ordinal) = candidate_position(query.candidate.unwrap())?;
                let (mut found, total, cost) = if family == "a" {
                    candidates(reader, associations[ordinal]["target"].as_str(), before.0, 1, work)?
                } else {
                    let reference_scope = json!(["references", query.id, false, ordinal]);
                    let cursor = recorded_domain::cursor(&reader.generation, &reference_scope, before)?;
                    let parameters = json!({"id":query.id,"direction":"outgoing","candidate_link":ordinal,"cursor":cursor,"limit":1});
                    let mut selected = references::select_scoped(reader, &references::Query::parse(&parameters)?, Some(work))?;
                    let found = match selected["candidates"].take() { Value::Array(items) => items, _ => unreachable!() };
                    (found, selected["candidate_matches"].as_u64().unwrap() as usize, selected["cost"]["recorded_directory"].take())
                };
                remember_directory(&mut response, cost);
                if found.is_empty() { return Ok(Step { item:None,next:before,complete:true,total:Some(total) }); }
                let item = json!({"kind":"candidate","identity":found.remove(0)});
                work.metadata(&item, 2)?;
                return Ok(Step { item:Some(item),next:(before.0+1,0),complete:before.0+1==total,total:Some(total) });
            }
            if query.direction == "outgoing" && before.0 < associations.len() {
                if before.1 != 0 { return Err(CoreError::input("Invalid association position")); }
                if !work.facts(1) { return Err(CoreError::limit("Neighborhood association allowance")); }
                let entry = &associations[before.0];
                work.metadata(entry, 2)?;
                let (found, total, cost) = candidates(reader, entry["target"].as_str(), 0, 4, work)?;
                remember_directory(&mut response, cost);
                work.metadata(&found, 2)?;
                let mut item = json!({"kind":"edge","type":"association","direction":"outgoing","origin_id":query.id,
                    "target_label":entry["target"],"relation":entry["macro"],"association":entry,
                    "witness":{"fact_id":query.id,"family":"associations","ordinal":before.0},
                    "target_status":status(entry["target"].as_str(),total),"candidates":[],
                    "candidate_matches":total,"candidate_search_complete":true,"candidate_selector":format!("a:{}",before.0),
                    "candidate_known_omitted":total.saturating_sub(found.len()),"binding":"unknown"});
                item["candidates"] = Value::Array(found);
                work.metadata(&item, 2)?;
                return Ok(Step { item:Some(item),next:(before.0+1,0),
                    complete:query.kind=="association" && before.0+1==associations.len(),
                    total:if query.kind=="association" {Some(associations.len())} else {None} });
            }
            if query.direction == "outgoing" && query.kind == "association" && before == (associations.len(), 0) {
                return Ok(Step { item:None,next:before,complete:true,total:Some(associations.len()) });
            }
            let shift = if query.direction == "outgoing" { associations.len() } else { 0 };
            let input = (before.0.checked_sub(shift).ok_or_else(|| CoreError::input("Invalid edge position"))?, before.1);
            let filter = if query.direction == "outgoing" || query.kind == "reference" { references::RelationFilter::References }
                else if query.kind == "association" { references::RelationFilter::Associations } else { references::RelationFilter::All };
            let reference_scope = references::filtered_scope(query.id, query.direction=="incoming", filter);
            let cursor = recorded_domain::cursor(&reader.generation, &reference_scope, input)?;
            let parameters = json!({"id":query.id,"direction":query.direction,"cursor":cursor,"limit":1});
            response["cost"]["reference_attempts"] = json!(response["cost"]["reference_attempts"].as_u64().unwrap()+1);
            let mut consumed = input;
            let selected = references::select_filtered(reader, &references::Query::parse(&parameters)?, work, filter, &mut consumed);
            let mut selected = match selected {
                Ok(value) => value,
                Err(error) => {
                    // The adapter reports only safely consumed skips, never its
                    // partially materialized/failed row or a post-row position.
                    failure_position = (consumed.0+shift,consumed.1);
                    response["coverage"]["last_reference_step"] = json!({"status":"component_refused","input_position":[input.0,input.1],
                        "consumed_skips_position":[consumed.0,consumed.1],"row_retained":false});
                    return Err(error);
                }
            };
            response["cost"]["completed_reference_steps"] = json!(response["cost"]["completed_reference_steps"].as_u64().unwrap()+1);
            remember_directory(&mut response, selected["cost"]["recorded_directory"].take());
            for field in ["facts_scanned","links_scanned","comparisons","label_bytes"] {
                response["cost"]["completed_step_work"][field] = json!(response["cost"]["completed_step_work"][field].as_u64().unwrap()+selected["coverage"][field].as_u64().unwrap_or(0));
            }
            let done = selected["coverage"]["scan_complete"] == true;
            let next = if done { (if query.direction=="incoming" {reader.facts.len()} else {1},0) }
                else if selected["next_cursor"].is_null() { consumed }
                else { recorded_domain::position(Some(&selected["next_cursor"]), &reader.generation, &reference_scope)? };
            response["coverage"]["last_reference_step"] = json!({"status":"completed_component","input_position":[input.0,input.1],
                "next_position":[next.0,next.1],"scan_complete":done,"row_retained":false,
                "facts_scanned":selected["coverage"]["facts_scanned"],"links_scanned":selected["coverage"]["links_scanned"]});
            let rows = selected["relationships"].as_array_mut().unwrap();
            if rows.is_empty() {
                if !done && next==input { return Err(CoreError::limit("Shared reference allowance made no progress")); }
                return Ok(Step { item:None,next:(next.0+shift,next.1),complete:done,total:None });
            }
            let mut row = rows.remove(0);
            work.metadata(&row, 2)?;
            let total = row["candidate_matches"].as_u64().unwrap_or(0) as usize;
            let shown = row["candidates"].as_array().unwrap().len();
            let mut item = json!({"kind":"edge","type":if row["link"]["relation"]=="association_target_label" {"association"} else {"reference"},
                "direction":query.direction,"relation":row["link"]["relation"],"target_label":row["candidate_label"],
                "target_status":if query.direction=="incoming" {"selected_label_binding_unknown"} else {status(row["candidate_label"].as_str(),total)},
                "candidate_matches":total,"candidate_search_complete":row["candidate_search_complete"],
                "candidate_known_omitted":total.saturating_sub(shown),"candidate_selector":if query.direction=="outgoing" {json!(format!("r:{}",row["link_ordinal"]))} else {Value::Null},
                "binding":"unknown"});
            item["origin"] = row["origin"].take();
            item["candidates"] = row["candidates"].take();
            // Keep the effective original link + exact witness, without aliases
            // of identities/candidate fields already owned by the typed edge.
            row.as_object_mut().unwrap().retain(|key,_| ["link","link_ordinal","detail_omitted","match_basis"].contains(&key.as_str()));
            item["recorded"] = row;
            work.metadata(&item, 2)?;
            Ok(Step { item:Some(item),next:(next.0+shift,next.1),complete:done,total:None })
        })();
        let step = match attempt {
            Ok(value) => value,
            Err(error) if error.code=="limit_exceeded" &&
                (!response["items"].as_array().unwrap().is_empty() || failure_position!=start) => {
                position = failure_position;
                break;
            },
            Err(error) => return Err(error),
        };
        known_total = step.total;
        if let Some(item) = step.item {
            response["items"].as_array_mut().unwrap().push(item);
            if !response["coverage"]["last_reference_step"].is_null() {
                response["coverage"]["last_reference_step"]["row_retained"] = json!(true);
            }
            page_state(&mut response, reader, query, step.next, step.complete, known_total)?;
            let admission = work.metadata(&response,1)
                .and_then(|_| work.metadata(&(&response["coverage"], &response["cost"]),2))
                .and_then(|_| wire_bytes(&response,query.max_bytes));
            if let Err(error) = admission {
                response["items"].as_array_mut().unwrap().pop();
                if !response["coverage"]["last_reference_step"].is_null() {
                    response["coverage"]["last_reference_step"]["row_retained"] = json!(false);
                }
                if error.code!="limit_exceeded" || response["items"].as_array().unwrap().is_empty() { return Err(error); }
                // Component INPUT is still position; never commit its post-row
                // cursor when native wire/metadata admission defers this row.
                break;
            }
            // One bounded checkpoint, replaced after each successful admission.
            // Its clone/copy work is charged above; RequestWork is never copied.
            admitted = Some(AdmittedDiagnostics { coverage: response["coverage"].clone(),
                cost: response["cost"].clone(), position: step.next, complete: step.complete, total: known_total });
        } else if !step.complete && step.next==before { return Err(CoreError::limit("Neighborhood made no progress")); }
        position = step.next; complete = step.complete;
        if response["items"].as_array().unwrap().is_empty() && !complete { break; }
    }
    // Only final bounded response sizing/serialization uses the existing reserve.
    work.finish_metadata();
    loop {
        page_state(&mut response, reader, query, position, complete, known_total)?;
        if !complete && position==start { return Err(CoreError::limit("Neighborhood page made no progress; increase max_bytes")); }
        work.metadata(&response,1)?;
        match wire_bytes(&response,query.max_bytes) {
            Ok(_) => break,
            Err(error) if error.code=="limit_exceeded" && admitted.is_some() => {
                // A later refused/deferred step may enlarge diagnostics even
                // though its row was never admitted. Restore the last fitting
                // prefix's diagnostics and cursor, not the charged work. Taking
                // the checkpoint also makes this a single bounded retry.
                let checkpoint = admitted.take().unwrap();
                response["coverage"] = checkpoint.coverage; response["cost"] = checkpoint.cost;
                position = checkpoint.position; complete = checkpoint.complete; known_total = checkpoint.total;
            },
            Err(error) => return Err(error),
        }
    }
    work.metadata(&Success { ok:true,result:&response },5)?;
    for _ in 0..3 {
        let bytes=wire_bytes(&response,query.max_bytes)?;
        if response["usage"]["wire_bytes_including_envelope_and_newline"]==bytes { break; }
        response["usage"]["wire_bytes_including_envelope_and_newline"]=json!(bytes);
    }
    wire_bytes(&response,query.max_bytes)?;
    Ok(response)
}

#[cfg(test)]
#[path = "model_neighborhood_tests.rs"]
mod tests;
