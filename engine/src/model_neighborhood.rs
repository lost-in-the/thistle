//! One saved model, raw schema and one-hop evidence. Never a resolver or ERD.
use crate::{error::{CoreError, Result}, model_brief::RequestWork, recorded_domain,
    references, schema, store::Reader};
use serde::Serialize;
use serde_json::{json, Value};

const SEMANTICS: &str = "Saved one-hop evidence only. Association declarations, recorded references and database constraints are different facts. Name candidates are saved representations, not distinct model definitions or resolved bindings. Missing matches can mean unloaded or uncaptured targets. Runtime/source coherence and execution remain unknown. Empty searched evidence never proves absence.";

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
    let (page, cost) = reader.recorded_candidates(label, None, offset, limit, work)?;
    let mut items = Vec::new();
    for position in page.positions { items.push(identity(&reader.facts[position], work)?); }
    Ok((items, page.total, cost))
}
fn status(label: Option<&str>, count: usize) -> &'static str {
    if label.is_none() { "unknown_target" } else if count == 0 { "missing_or_unloaded" }
    else if count == 1 { "one_saved_representation_binding_unknown" } else { "ambiguous_saved_representations" }
}
fn remember_directory(response: &mut Value, cost: Value) {
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
fn select_with_work(reader: &Reader, query: &Query<'_>, mut work: &mut RequestWork) -> Result<Value> {
    let root = reader.stored_fact(query.id)?;
    if root["kind"] != "rails_model" { return Err(CoreError::input("Neighborhood requires a rails_model saved ID")); }
    let model = &root["attributes"]["model"];
    let associations = schema::array(&model["associations"], "entries")?;
    let scope = query.scope();
    let start = recorded_domain::position(query.cursor, &reader.generation, &scope)?;
    let mut position = start;
    // Type-excluded metadata needs no entry traversal or attribute expansion.
    if query.family == "edges" && query.direction == "outgoing" && query.kind == "reference" && position.0 < associations.len() {
        if position.1 != 0 { return Err(CoreError::input("Invalid excluded association position")); }
        position = (associations.len(), 0);
    }
    let coverage = schema::array(&reader.manifest, "coverage")?;
    let mut capture = Vec::new();
    for family in coverage.iter().take(256) { capture.push(project(family, &["family", "status"], &mut work)?); }
    let mut response = json!({"version":1,"generation":reader.generation,"root":null,"model":null,
        "family":query.family,"direction":query.direction,"type":query.kind,"candidate":query.candidate,
        "semantics":SEMANTICS,"items":[],"next_cursor":null,
        "coverage":{"page_complete":false,"unsearched":false,"known_remaining":null,
            "columns_status":model["columns"]["status"],"associations_status":model["associations"]["status"],
            "recorded_associations":associations.len(),"capture_partial_or_unknown":coverage.is_empty() || coverage.len()>256 || capture.iter().any(|v|v["status"]!="complete"),
            "capture_families":capture,"capture_families_omitted":coverage.len().saturating_sub(256),
            "candidate_count_unit":"saved_representations_not_distinct_model_definitions",
            "default_presence":"not_recorded","database_constraints_indexes_on_delete":"not_recorded"},
        "cost":{"reader_open":reader.method_lookup_baseline(),"recorded_directory":{"status":"not_requested","built_this_request":false},
            "reference_steps":0,"facts_scanned":0,"links_scanned":0,"label_comparisons":0,"label_bytes":0,
            "transient_reservation_bytes":query.scratch(),"shared_work_report":"private_RequestWork_enforces_existing_limits",
            "source_attempts":0},
        "usage":{"returned_items":0,"wire_bytes_including_envelope_and_newline":65536}});
    response["root"] = identity(root, &mut work)?;
    response["model"] = project(model, &["name", "table", "primary_key", "base_class", "superclass", "abstract", "inheritance_column", "source", "coherence"], &mut work)?;
    work.metadata(&response, 1)?;
    wire_bytes(&response, query.max_bytes)?;
    let mut items = Vec::new();
    let mut starts = Vec::new();
    let mut complete = false;
    let mut known_total = None;
    let mut last_reference_coverage = Value::Null;
    while items.len() < query.limit && !complete {
        let before = position;
        let item;
        if query.family == "columns" {
            let columns = schema::array(&model["columns"], "entries")?;
            if position.1 != 0 || position.0 > columns.len() { return Err(CoreError::input("Invalid columns position")); }
            known_total = Some(columns.len());
            if position.0 == columns.len() { complete = true; break; }
            if !work.facts(1) { return Err(CoreError::limit("Neighborhood column allowance")); }
            let column = &columns[position.0];
            // Missing is distinct from literal null; schema versions may lack a value.
            let mut data = project(column, &["name", "type", "sql_type", "null", "default"], &mut work)?;
            data["default_recorded"] = json!(column.get("default").is_some());
            data["default_presence"] = json!("not_recorded");
            item = json!({"kind":"column","ordinal":position.0,"column":data});
            position.0 += 1; complete = position.0 == columns.len();
        } else if query.family == "database" {
            if position != (0, 0) { return Err(CoreError::input("Database facts have no continuation")); }
            complete = true; known_total = Some(0); break;
        } else if query.family == "candidates" {
            if position.1 != 0 { return Err(CoreError::input("Invalid candidate position")); }
            let (family, ordinal) = candidate_position(query.candidate.unwrap())?;
            if family == "a" {
                if query.kind == "reference" { return Err(CoreError::input("Association candidate outside type filter")); }
                let entry = associations.get(ordinal).ok_or_else(|| CoreError::input("Association outside model"))?;
                let (found, total, cost) = candidates(reader, entry["target"].as_str(), position.0, 1, &mut work)?;
                remember_directory(&mut response, cost); known_total = Some(total);
                if found.is_empty() { complete = true; break; }
                item = json!({"kind":"candidate","identity":found.into_iter().next().unwrap()});
                position.0 += 1; complete = position.0 == total;
            } else {
                let links = schema::array(root, "links")?;
                let wire = links.get(ordinal).ok_or_else(|| CoreError::input("Reference outside model"))?;
                if !work.links(1) { return Err(CoreError::limit("Candidate link allowance")); }
                let link = crate::link_encoding::SemanticLinkView::from_wire(wire, reader.schema_version(), schema::string(root, "evidence")?)?;
                let association = link.relation() == "association_target_label";
                if query.kind == "association" && !association || query.kind == "reference" && association {
                    return Err(CoreError::input("Reference candidate outside type filter"));
                }
                let reference_scope = json!(["references", query.id, false, ordinal]);
                let cursor = recorded_domain::cursor(&reader.generation, &reference_scope, position)?;
                let parameters = json!({"id":query.id,"direction":"outgoing","candidate_link":ordinal,"cursor":cursor,"limit":1});
                let mut selected = references::select_scoped(reader, &references::Query::parse(&parameters)?, Some(&mut work))?;
                remember_directory(&mut response, selected["cost"]["recorded_directory"].take());
                let total = selected["candidate_matches"].as_u64().unwrap() as usize; known_total = Some(total);
                let mut found = match selected["candidates"].take() { Value::Array(items) => items, _ => unreachable!() };
                if found.is_empty() { complete = true; break; }
                item = json!({"kind":"candidate","identity":found.remove(0)});
                position.0 += 1; complete = position.0 == total;
            }
        } else if query.direction == "outgoing" && position.0 < associations.len() {
            if position.1 != 0 { return Err(CoreError::input("Invalid association position")); }
            if !work.facts(1) { return Err(CoreError::limit("Neighborhood association allowance")); }
            let ordinal = position.0; position.0 += 1;
            if query.kind == "reference" { continue; }
            let entry = &associations[ordinal];
            work.metadata(entry, 2)?;
            let (found, total, cost) = candidates(reader, entry["target"].as_str(), 0, 4, &mut work)?;
            remember_directory(&mut response, cost);
            work.metadata(&response["root"], 2)?;
            work.metadata(&found, 2)?;
            item = json!({"kind":"edge","type":"association","direction":"outgoing","origin":response["root"],
                "target_label":entry["target"],"relation":entry["macro"],"association":entry,
                "witness":{"fact_id":query.id,"family":"associations","ordinal":ordinal},
                "target_status":status(entry["target"].as_str(),total),"candidates":found,
                "candidate_matches":total,"candidate_search_complete":true,"candidate_selector":format!("a:{ordinal}"),
                "candidate_known_omitted":total.saturating_sub(4),"binding":"unknown"});
            complete = query.kind == "association" && position.0 == associations.len();
        } else {
            if query.direction == "outgoing" && query.kind == "association" && position == (associations.len(), 0) {
                complete = true; break;
            }
            let shift = if query.direction == "outgoing" { associations.len() } else { 0 };
            let reference_position = (position.0.checked_sub(shift).ok_or_else(|| CoreError::input("Invalid edge position"))?, position.1);
            let reference_scope = json!(["references", query.id, query.direction == "incoming", null]);
            let cursor = recorded_domain::cursor(&reader.generation, &reference_scope, reference_position)?;
            let parameters = json!({"id":query.id,"direction":query.direction,"cursor":cursor,"limit":1});
            let mut selected = references::select_scoped(reader, &references::Query::parse(&parameters)?, Some(&mut work))?;
            remember_directory(&mut response, selected["cost"]["recorded_directory"].take());
            response["cost"]["reference_steps"] = json!(response["cost"]["reference_steps"].as_u64().unwrap()+1);
            for (output, input) in [("facts_scanned","facts_scanned"),("links_scanned","links_scanned"),("label_comparisons","comparisons"),("label_bytes","label_bytes")] {
                response["cost"][output] = json!(response["cost"][output].as_u64().unwrap()+selected["coverage"][input].as_u64().unwrap_or(0));
            }
            last_reference_coverage = selected["coverage"].take();
            complete = last_reference_coverage["scan_complete"] == true;
            if !complete {
                if selected["next_cursor"].is_null() {
                    // The component can exhaust shared work at its INPUT cursor.
                    // An admitted outer prefix can continue from there on a fresh
                    // request. A first-row zero-progress refusal stays a refusal.
                    if !items.is_empty() { break; }
                    return Err(CoreError::limit("Shared reference allowance made no resumable progress"));
                }
                let next = recorded_domain::position(Some(&selected["next_cursor"]), &reader.generation, &reference_scope)?;
                position = (next.0 + shift, next.1);
                if position == before { return Err(CoreError::limit("Reference continuation made no progress")); }
            }
            let rows = selected["relationships"].as_array_mut().unwrap();
            if rows.is_empty() { break; }
            let mut row = rows.remove(0);
            work.metadata(&row, 2)?;
            let association = row["link"]["relation"] == "association_target_label";
            // The outgoing declaration already carries this exact saved evidence;
            // do not render its link representation as a second association edge.
            if query.direction == "outgoing" && association || query.kind == "association" && !association || query.kind == "reference" && association { continue; }
            let total = row["candidate_matches"].as_u64().unwrap_or(0) as usize;
            let shown = row["candidates"].as_array().unwrap().len();
            item = json!({"kind":"edge","type":if association {"association"} else {"reference"},
                "direction":query.direction,"relation":row["link"]["relation"],"origin":row["origin"],
                "target_label":row["candidate_label"],"target_status":if query.direction=="incoming" {"selected_label_binding_unknown"} else {status(row["candidate_label"].as_str(),total)},
                "candidate_matches":total,"candidate_search_complete":row["candidate_search_complete"],
                "candidate_known_omitted":total.saturating_sub(shown),"candidate_selector":if query.direction=="outgoing" {json!(format!("r:{}",row["link_ordinal"]))} else {Value::Null},
                "binding":"unknown"});
            let mut item = item;
            item["candidates"] = row["candidates"].take(); item["recorded"] = row;
            starts.push(before); items.push(item); continue;
        }
        starts.push(before); items.push(item);
    }
    response["coverage"]["reference_scan"] = last_reference_coverage;
    response["items"] = Value::Array(items);
    loop {
        let count = response["items"].as_array().unwrap().len();
        response["coverage"]["page_complete"] = json!(complete);
        response["coverage"]["unsearched"] = json!(!complete);
        response["coverage"]["known_remaining"] = if complete { json!(0) } else { known_total.map(|total| json!(total.saturating_sub(position.0))).unwrap_or(Value::Null) };
        response["coverage"]["recorded_candidates_total"] = if query.family == "candidates" { known_total.map(|n|json!(n)).unwrap_or(Value::Null) } else { Value::Null };
        response["next_cursor"] = if complete { Value::Null } else { recorded_domain::cursor(&reader.generation, &scope, position)? };
        if !complete && position == start { return Err(CoreError::limit("Neighborhood page made no progress; increase max_bytes")); }
        response["usage"]["returned_items"] = json!(count);
        // Fixed upper-width placeholder makes the first measurement conservative.
        response["usage"]["wire_bytes_including_envelope_and_newline"] = json!(65536);
        work.metadata(&response, 1)?;
        match wire_bytes(&response, query.max_bytes) {
            Ok(_) => break,
            Err(error) if error.code == "limit_exceeded" && count > 1 => {
                response["items"].as_array_mut().unwrap().pop();
                position = starts.pop().unwrap(); complete = false;
            },
            Err(error) => return Err(error),
        }
    }
    // Final construction/sizing/native/Ruby copies debit the same metadata work.
    work.metadata(&Success { ok: true, result: &response }, 5)?;
    for _ in 0..3 {
        let bytes = wire_bytes(&response, query.max_bytes)?;
        if response["usage"]["wire_bytes_including_envelope_and_newline"] == bytes { break; }
        response["usage"]["wire_bytes_including_envelope_and_newline"] = json!(bytes);
    }
    wire_bytes(&response, query.max_bytes)?;
    Ok(response)
}

#[cfg(test)]
#[path = "model_neighborhood_tests.rs"]
mod tests;
