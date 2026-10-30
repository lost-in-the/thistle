//! One bounded, pinned investigation. No retained product state or query framework.
use crate::{callback_effects, error::{CoreError, Result}, references, schema, store::Reader};
use serde::Serialize;
use serde_json::{json, Value};

const FACTS: usize = 20_000;
const LINKS: usize = 50_000;
const COMPARISONS: usize = 100_000;
const LABEL_BYTES: usize = 32 * 1024 * 1024;
const METADATA_BYTES: usize = 8 * 1024 * 1024;
const SOURCE_BYTES: usize = 1024 * 1024;
const FILES: usize = 16;
const SEMANTICS: &str = "Generation-local recorded evidence only. Labels and registry candidates never establish model identity, canonical targets or dispatch. Registered metadata, captured-source potential and execution are distinct. Runtime/source coherence, invocation, ActiveJob ancestry, delivery, conditions and execution order are unknown. Empty searched evidence never proves absence; partial capture and unsearched prefixes remain unknown. Source/Links follow-ups must use this generation.";

pub(crate) struct Query<'a> { id: &'a str, limit: usize, max_bytes: usize }
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let id = schema::hash(schema::string(request, "id")?)?;
        fn integer(request: &Value, key: &str, default: usize, max: usize) -> Result<usize> {
            match request.get(key) { None => Ok(default), Some(v) => v.as_u64()
                .filter(|n| *n > 0 && *n <= max as u64).map(|n| n as usize)
                .ok_or_else(|| CoreError::input(format!("{key} must be an integer between 1 and {max}"))) }
        }
        Ok(Self { id, limit: integer(request, "limit", 8, 16)?, max_bytes: integer(request, "max_bytes", 32768, 65536)? })
    }
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
}

/// Concrete admission shared by this operation's existing selectors. Units are
/// visits and encoded bytes processed, not instructions, heap bytes or latency.
#[derive(Default)]
pub(crate) struct RequestWork {
    facts: usize, links: usize, comparisons: usize, label_bytes: usize,
    files: usize, source_bytes: usize, metadata_bytes: usize,
}
impl RequestWork {
    pub(crate) fn facts(&mut self, n: usize) -> bool {
        if n > FACTS.saturating_sub(self.facts) { return false; } self.facts += n; true
    }
    pub(crate) fn links(&mut self, n: usize) -> bool {
        if n > LINKS.saturating_sub(self.links) { return false; } self.links += n; true
    }
    pub(crate) fn method(&mut self, facts: usize, links: usize) -> bool {
        if facts > FACTS.saturating_sub(self.facts) || links > LINKS.saturating_sub(self.links) { return false; }
        self.facts += facts; self.links += links; true
    }
    #[cfg(test)]
    pub(crate) fn comparison(&mut self) -> bool {
        if self.comparisons == COMPARISONS { return false; } self.comparisons += 1; true
    }
    pub(crate) fn label_bytes(&mut self, n: usize) -> bool {
        if n > LABEL_BYTES.saturating_sub(self.label_bytes) { return false; } self.label_bytes += n; true
    }
    pub(crate) fn labels(&mut self, n: usize) -> bool {
        if self.comparisons == COMPARISONS || n > LABEL_BYTES.saturating_sub(self.label_bytes) { return false; }
        self.comparisons += 1; self.label_bytes += n; true
    }
    pub(crate) fn source_attempt(&mut self) -> bool {
        if self.files == FILES { return false; } self.files += 1; true
    }
    pub(crate) fn source_bytes(&mut self, n: usize) -> bool {
        if n > SOURCE_BYTES.saturating_sub(self.source_bytes) { return false; } self.source_bytes += n; true
    }
    pub(crate) fn metadata(&mut self, value: &impl Serialize, passes: usize) -> Result<usize> {
        let bytes = schema::encoded_bytes(value, METADATA_BYTES.saturating_sub(self.metadata_bytes) / passes)?;
        self.metadata_bytes += bytes * passes;
        Ok(bytes)
    }
    fn value(&self) -> Value {
        json!({"fact_visits":self.facts,"link_visits":self.links,"label_comparisons":self.comparisons,
            "compared_or_hashed_label_bytes":self.label_bytes,"source_attempts":self.files,"source_bytes":self.source_bytes,
            "processed_encoded_metadata_bytes":self.metadata_bytes})
    }
}

fn project(value: &Value, fields: &[&str], work: &mut RequestWork) -> Result<Value> {
    let mut output = serde_json::Map::new();
    for key in fields {
        // Count the borrowed value before copying; never inspect an attribute or
        // full link tree just to make a small identity.
        work.metadata(&value[*key], 2)?;
        output.insert((*key).into(), value[*key].clone());
    }
    Ok(Value::Object(output))
}
fn identity(fact: &Value, work: &mut RequestWork) -> Result<Value> {
    project(fact, &["id", "kind", "name", "evidence", "path", "location"], work)
}
fn family(generation: &str, id: &str, provenance: &str) -> Value {
    json!({"generation":generation,"fact_id":id,"provenance":provenance,"status":"not_searched",
        "reason":"not_admitted","items":[],"known_omitted":0,"unsearched":true})
}
fn skip(family: &mut Value, reason: &str) { family["status"] = json!("not_searched"); family["reason"] = json!(reason); family["unsearched"] = json!(true); }
fn limited(error: CoreError, family: &mut Value) -> Result<()> {
    if error.code != "limit_exceeded" { return Err(error); }
    skip(family, "shared_work_or_component_admission_unavailable"); family["known_omitted"] = Value::Null; Ok(())
}
fn fields(reader: &Reader, root: &Value, name: &str, limit: usize, work: &mut RequestWork) -> Result<Value> {
    let mut out = family(&reader.generation, root["id"].as_str().unwrap(), "recorded_model_metadata");
    if !work.facts(1) { return Ok(out); }
    let data = &root["attributes"]["model"][name];
    let entries = schema::array(data, "entries")?;
    out["status"] = data["status"].clone(); out["reason"] = json!("recorded_family_status");
    out["recorded_items"] = json!(entries.len()); out["known_omitted"] = json!(entries.len().saturating_sub(limit));
    out["unsearched"] = json!(false);
    let keys: &[&str] = if name == "columns" { &["name", "type", "null"] } else { &["name", "macro", "target", "polymorphic"] };
    let mut items = Vec::new();
    for entry in entries.iter().take(limit) {
        let mut item = project(entry, keys, work)?;
        if name == "associations" { item["status"] = json!("recorded_label_binding_unknown"); }
        items.push(item);
    }
    out["items"] = Value::Array(items); Ok(out)
}

fn registries<'a>(reader: &'a Reader, root: &Value, work: &mut RequestWork) -> Result<(Value, Option<&'a str>)> {
    let mut out = family(&reader.generation, root["id"].as_str().unwrap(), "registered_metadata_label_candidates");
    out["model_registry_binding"] = json!("unknown");
    out["candidate_matches"] = json!(0); out["scan_complete"] = json!(false);
    let Some(label) = root["attributes"]["model"]["name"].as_str() else { skip(&mut out, "anonymous_model_has_no_label"); return Ok((out, None)); };
    let mut matches = 0; let mut complete = true; let mut selected = None; let mut items = Vec::new();
    let mut visited = 0;
    for fact in &reader.facts {
        if !work.facts(1) { complete = false; break; } visited += 1;
        if fact["kind"] != "rails_save_callbacks" { continue; }
        let Some(candidate) = fact["attributes"]["callbacks"]["name"].as_str() else { continue; };
        if !work.labels(label.len().saturating_add(candidate.len())) { complete = false; break; }
        if label != candidate { continue; }
        matches += 1; selected = fact["id"].as_str();
        if items.len() < 2 { items.push(identity(fact, work)?); }
    }
    out["status"] = json!(if !complete { "not_searched" } else if matches == 1 { "unique_label_candidate" } else if matches > 1 { "ambiguous" } else { "unavailable" });
    out["reason"] = json!(if !complete { "registry_discovery_incomplete" } else if matches == 1 { "complete_unique_label_match_binding_unknown" } else if matches > 1 { "multiple_registry_label_candidates" } else { "no_registry_label_candidate_in_saved_evidence" });
    out["scan_complete"] = json!(complete); out["unsearched"] = json!(!complete); out["facts_visited"] = json!(visited);
    out["candidate_matches"] = json!(matches); out["known_omitted"] = json!(matches.saturating_sub(items.len()));
    out["items"] = Value::Array(items);
    Ok((out, (complete && matches == 1).then_some(selected).flatten()))
}

fn reference_family(reader: &Reader, query: &Query<'_>, direction: &str, work: &mut RequestWork) -> Result<Value> {
    let mut out = family(&reader.generation, query.id, "recorded_relationship_label_candidates");
    let parameters = json!({"id":query.id,"direction":direction,"limit":query.limit});
    let parameters = references::Query::parse(&parameters)?;
    match references::select_scoped(reader, &parameters, Some(work)) {
        Ok(mut result) => {
            out["status"] = json!(if result["coverage"]["scan_complete"] == true { "searched" } else { "not_searched" });
            out["reason"] = json!("recorded_labels_binding_unknown");
            out["known_omitted"] = result["coverage"]["known_omitted"].take();
            out["unsearched"] = result["coverage"]["not_searched"].take();
            out["coverage"] = result["coverage"].take(); out["items"] = result["relationships"].take();
        },
        Err(error) => limited(error, &mut out)?,
    }
    Ok(out)
}

pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    select_with_work(reader, query, &mut RequestWork::default())
}
fn select_with_work(reader: &Reader, query: &Query<'_>, work: &mut RequestWork) -> Result<Value> {
    let root = reader.stored_fact(query.id)?;
    if root["kind"] != "rails_model" { return Err(CoreError::input("model_brief requires a rails_model fact ID")); }
    if !work.facts(1) { return Err(CoreError::limit("Model root visit unavailable")); }
    let mut response = json!({"version":1,"generation":reader.generation,"root":null,
        "generation_scope":"Every enclosed family, item, fact ID and source anchor belongs only to this immutable generation",
        "limits":{"items_per_family":query.limit,"wire_bytes_including_newline":query.max_bytes,
            "request":{"fact_visits":FACTS,"link_visits":LINKS,"label_comparisons":COMPARISONS,"label_bytes":LABEL_BYTES,
                "source_attempts":FILES,"source_bytes":SOURCE_BYTES,"source_file_bytes":262144,"processed_encoded_metadata_bytes":METADATA_BYTES},
            "transient_reservation_bytes":query.scratch()},
        "coverage":null,"uncertainty":SEMANTICS,"model":null,"families":{},
        "cost":{"reader_open":reader.method_lookup_baseline(),"method_directory":{"status":"not_requested","built_this_request":false},
            "incremental_request":{},"whole_job":{},
            "units":"Fact visits include revisits and both reference scans. Reader-open five passes and optional directory construction are separate, counted once in whole_job. Encoded metadata charges count input checks/copies, component construction/encoding, projection and response/native/Ruby serialization copies; not exact heap or instructions.",
            "native_crossings":1,"fresh_reader_rebuilds_directory":true},
        "usage":{"returned_items":0,"wire_bytes_including_newline":65536}});
    response["root"] = identity(root, work)?;
    response["model"] = project(&root["attributes"]["model"], &["name", "base_class", "superclass", "abstract", "table", "inheritance_column", "source", "coherence"], work)?;
    let coverage = schema::array(&reader.manifest, "coverage")?;
    let mut captured = Vec::new();
    for entry in coverage.iter().take(256) { captured.push(project(entry, &["family", "status"], work)?); }
    response["coverage"] = json!({"capture_partial_or_unknown":coverage.is_empty() || coverage.len() > 256 || captured.iter().any(|v| v["status"] != "complete"),
        "families_not_projected":coverage.len().saturating_sub(256),"families":captured});
    // Components are consumed/projected sequentially, never accumulated beside
    // independent full selector outputs. Existing selector admission is shared.
    response["families"]["columns"] = fields(reader, root, "columns", query.limit, work)?;
    response["families"]["associations"] = fields(reader, root, "associations", query.limit, work)?;
    let (registry, candidate) = registries(reader, root, work)?;
    response["families"]["registry_candidates"] = registry;
    let mut callbacks = family(&reader.generation, query.id, "registered_metadata_and_captured_source_potential");
    callbacks["model_registry_binding"] = json!("unknown");
    if let Some(id) = candidate {
        callbacks["fact_id"] = json!(id);
        let parameters = json!({"id":id,"limit":query.limit});
        match callback_effects::select_scoped(reader, &callback_effects::Query::parse(&parameters)?, crate::query::budget(), Some(work)) {
            Ok(mut result) => {
                callbacks["status"] = result["registry_status"].take(); callbacks["reason"] = json!("unique_label_candidate_only_binding_unknown");
                callbacks["observed_model_label"] = result["model"].take();
                callbacks["known_omitted"] = json!(result["coverage"]["rows_not_searched"].as_u64().unwrap_or(0) + result["coverage"]["rows_metadata_omitted"].as_u64().unwrap_or(0) + result["coverage"]["rows_output_omitted"].as_u64().unwrap_or(0));
                callbacks["unsearched"] = json!(result["coverage"]["source_rows_not_searched"] != 0 || result["coverage"]["rows_not_searched"] != 0);
                response["cost"]["method_directory"] = result["coverage"]["method_directory"].take();
                result["coverage"].as_object_mut().unwrap().remove("reader_open");
                callbacks["coverage"] = result["coverage"].take(); callbacks["items"] = result["callbacks"].take();
            },
            Err(error) => limited(error, &mut callbacks)?,
        }
    } else { skip(&mut callbacks, "unique_complete_registry_label_candidate_unavailable"); }
    response["families"]["callbacks"] = callbacks;
    for direction in ["outgoing", "incoming"] {
        response["families"][direction] = reference_family(reader, query, direction, work)?;
    }
    finish(response, query, work)
}

fn costs(response: &mut Value, work: &RequestWork) {
    response["cost"]["incremental_request"] = work.value();
    let baseline = &response["cost"]["reader_open"];
    let directory = &response["cost"]["method_directory"];
    let build = directory["built_this_request"] == true;
    response["cost"]["whole_job"] = json!({"reader_opens":1,"reader_open_fact_visits":baseline["facts"].as_u64().unwrap_or(0)*5,
        "directory_build_fact_visits":if build { directory["facts_visited"].as_u64().unwrap_or(0) } else {0},
        "fact_visits":baseline["facts"].as_u64().unwrap_or(0)*5 + if build {directory["facts_visited"].as_u64().unwrap_or(0)} else {0} + work.facts as u64,
        "directory_build_key_bytes":if build {directory["key_bytes"].as_u64().unwrap_or(0)} else {0},
        "directory_build_sort_comparisons":if build {directory["sort_comparisons"].as_u64().unwrap_or(0)} else {0},
        "directory_retained_bytes":directory["retained_bytes"].as_u64().unwrap_or(0)});
}
fn finish(mut response: Value, query: &Query<'_>, work: &mut RequestWork) -> Result<Value> {
    // Remove all item arrays once, fit items by encoded size, then move admitted
    // Values back. Avoid repeated whole-response serialize/pop quadratic work.
    let names = ["columns", "associations", "registry_candidates", "callbacks", "outgoing", "incoming"];
    let mut pending = Vec::new();
    for name in names {
        let items = response["families"][name]["items"].take();
        response["families"][name]["items"] = json!([]);
        pending.push(match items { Value::Array(items) => items, _ => Vec::new() });
    }
    costs(&mut response, work);
    // Reserve decimal counter growth and the final serialization/copy accounting
    // fields. A fitting mandatory envelope never needs an optional item.
    let base = work.metadata(&response, 1)? + 1;
    if base > query.max_bytes { return Err(CoreError::limit("Mandatory model brief envelope exceeds max_bytes")); }
    let mut remaining = query.max_bytes.saturating_sub(base + 512);
    let mut returned = 0;
    for (name, items) in names.into_iter().zip(pending) {
        let mut admitted = Vec::new(); let mut omitted = 0;
        for item in items {
            let bytes = work.metadata(&item, 1)? + 1; // comma upper bound
            if admitted.len() == query.limit || bytes > remaining { omitted += 1; continue; }
            remaining -= bytes; returned += 1; admitted.push(item);
        }
        if omitted > 0 {
            let family = &mut response["families"][name];
            family["known_omitted"] = json!(family["known_omitted"].as_u64().unwrap_or(0) + omitted);
            family["output_truncated"] = json!(true);
        }
        response["families"][name]["items"] = Value::Array(admitted);
    }
    response["usage"]["returned_items"] = json!(returned);
    costs(&mut response, work);
    // Count final sizing, native envelope serialization, bridge copy/parse and
    // Ruby JSON emission as declared encoded-byte passes, including the newline.
    let bytes = work.metadata(&response, 5)? + 1;
    response["usage"]["wire_bytes_including_newline"] = json!(bytes);
    costs(&mut response, work);
    // Sizing/counter updates can change decimal width. Each attempt charges
    // two sizing passes; the second uses a 64-byte conservative width allowance.
    for _ in 0..8 {
        let measured = work.metadata(&response, 1)? + 1;
        if measured + 64 > METADATA_BYTES.saturating_sub(work.metadata_bytes) {
            return Err(CoreError::limit("Model brief encoding allowance unavailable"));
        }
        work.metadata_bytes += measured + 64;
        response["usage"]["wire_bytes_including_newline"] = json!(measured);
        costs(&mut response, work);
        let actual = schema::encoded_bytes(&response, query.max_bytes.saturating_sub(1))? + 1;
        if actual == measured { return Ok(response); }
    }
    Err(CoreError::limit("Model brief wire accounting did not converge"))
}

#[cfg(test)]
#[path = "model_brief_tests.rs"]
mod tests;
