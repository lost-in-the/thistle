//! One bounded, pinned investigation with optional generation-local name lookup.
use crate::{callback_effects, error::{CoreError, Result}, references, recorded_domain, schema, store::Reader};
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

pub(crate) struct Query<'a> { id: &'a str, limit: usize, max_bytes: usize, family: Option<&'a str>, cursor: Option<&'a Value> }
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let id = schema::hash(schema::string(request, "id")?)?;
        fn integer(request: &Value, key: &str, default: usize, max: usize) -> Result<usize> {
            match request.get(key) { None => Ok(default), Some(v) => v.as_u64()
                .filter(|n| *n > 0 && *n <= max as u64).map(|n| n as usize)
                .ok_or_else(|| CoreError::input(format!("{key} must be an integer between 1 and {max}"))) }
        }
        let family = match request.get("family") { None | Some(Value::Null) => None,
            Some(v) => Some(v.as_str().filter(|s| ["columns","associations","registry_candidates"].contains(s))
                .ok_or_else(|| CoreError::input("Family must be columns, associations or registry_candidates"))?) };
        if family.is_none() && request.get("cursor").is_some_and(|v| !v.is_null()) {
            return Err(CoreError::input("A model brief cursor requires a family"));
        }
        Ok(Self { id, limit: integer(request, "limit", 8, 16)?, max_bytes: integer(request, "max_bytes", 32768, 65536)?, family, cursor:request.get("cursor") })
    }
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
}

/// Concrete admission shared by this operation's existing selectors. Units are
/// visits and encoded bytes processed, not instructions, heap bytes or latency.
#[derive(Default, Clone, Copy)]
pub(crate) struct RequestWork {
    facts: usize, links: usize, comparisons: usize, label_bytes: usize,
    files: usize, source_bytes: usize, metadata_bytes: usize, finishing: bool,
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
        // Keep three MiB for compact final projection/encoding even when a
        // component runs out. Never spend the final envelope's allowance first.
        let ceiling = if self.finishing { METADATA_BYTES } else { METADATA_BYTES - 3 * 1024 * 1024 };
        let bytes = match schema::encoded_bytes(value, ceiling.saturating_sub(self.metadata_bytes) / passes) {
            Ok(bytes) => bytes,
            Err(error) => { self.metadata_bytes = self.metadata_bytes.max(ceiling); return Err(error); },
        };
        self.metadata_bytes += bytes * passes;
        Ok(bytes)
    }
    fn since(&self, before: Self) -> Value {
        let mut delta = *self;
        delta.facts -= before.facts; delta.links -= before.links;
        delta.comparisons -= before.comparisons; delta.label_bytes -= before.label_bytes;
        delta.files -= before.files; delta.source_bytes -= before.source_bytes;
        delta.metadata_bytes -= before.metadata_bytes;
        delta.value()
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

impl recorded_domain::LabelWork for RequestWork {
    fn compare(&mut self, a: &str, b: &str) -> Result<std::cmp::Ordering> {
        if !self.labels(a.len().saturating_add(b.len())) { return Err(CoreError::limit("Registry label allowance unavailable")); }
        Ok(a.cmp(b))
    }
}
fn followup(reader: &Reader, id: &str, name: &str) -> Value {
    if ["incoming","outgoing"].contains(&name) {
        json!({"operation":"references","generation":reader.generation,"id":id,"direction":name,"cursor":null})
    } else {
        json!({"operation":"model_brief","generation":reader.generation,"id":id,"family":name,"cursor":null})
    }
}
fn registries<'a>(reader: &'a Reader, root: &Value, work: &mut RequestWork) -> Result<(Value, Option<&'a str>)> {
    registry_page(reader,root,0,2,work)
}
fn registry_page<'a>(reader: &'a Reader, root: &Value, offset: usize, limit: usize, work: &mut RequestWork) -> Result<(Value, Option<&'a str>)> {
    let mut out = family(&reader.generation,root["id"].as_str().unwrap(),"registered_metadata_label_candidates");
    out["model_registry_binding"] = json!("unknown");
    out["candidate_matches"] = json!(0); out["scan_complete"] = json!(false);
    if !work.facts(1) { return Ok((out,None)); }
    let Some(label) = root["attributes"]["model"]["name"].as_str() else {
        if offset != 0 { return Err(CoreError::input("Invalid anonymous registry cursor")); }
        skip(&mut out,"anonymous_model_has_no_label"); return Ok((out,None));
    };
    let (page, directory) = match reader.recorded_candidates(label,Some("rails_save_callbacks"),offset,limit,work) {
        Ok(value)=>value, Err(error) if error.code=="limit_exceeded"=> { limited(error,&mut out)?; return Ok((out,None)); }, Err(error)=>return Err(error),
    };
    // Count is for the entire label/kind range, never just this output page.
    let matches=page.total;
    let candidate = if matches==1 { page.positions.first().map(|index| reader.facts[*index]["id"].as_str().unwrap()) } else { None };
    let mut items=Vec::new();
    if !work.facts(page.positions.len()) { limited(CoreError::limit("Registry identity visits unavailable"),&mut out)?; return Ok((out,None)); }
    for index in page.positions { items.push(identity(&reader.facts[index],work)?); }
    out["status"] = json!(if matches==1 {"unique_label_candidate"} else if matches>1 {"ambiguous"} else {"unavailable"});
    out["reason"] = json!(if matches==1 {"complete_unique_label_match_binding_unknown"} else if matches>1 {"multiple_registry_label_candidates"} else {"no_registry_label_candidate_in_saved_evidence"});
    out["scan_complete"] = json!(true); out["unsearched"] = json!(false); out["facts_visited"] = json!(items.len()+1);
    out["candidate_matches"] = json!(matches); out["known_omitted"] = json!(matches.saturating_sub(offset+items.len()));
    out["items"] = Value::Array(items); out["directory"] = directory;
    Ok((out,candidate))
}

/// A family page is independently bounded. Summary display pruning never supplies
/// its continuation: the public follow-up enumerates the selected family at zero.
fn family_page(reader: &Reader, query: &Query<'_>, root: &Value, work: &mut RequestWork) -> Result<Value> {
    let name=query.family.unwrap();
    let scope=json!(["model_brief",query.id,name]);
    let (offset,other)=recorded_domain::position(query.cursor,&reader.generation,&scope)?;
    if other!=0 { return Err(CoreError::input("Invalid family continuation position")); }
    let mut family = if name=="registry_candidates" {
        registry_page(reader,root,offset,query.limit,work)?.0
    } else {
        let data=&root["attributes"]["model"][name];
        let entries=schema::array(data,"entries")?;
        if offset>entries.len() { return Err(CoreError::input("Continuation exceeds the family")); }
        let mut out=family(&reader.generation,query.id,"recorded_model_metadata");
        let keys: &[&str]=if name=="columns" {&["name","type","null"]} else {&["name","macro","target","polymorphic"]};
        let mut items=Vec::new();
        for entry in entries.iter().skip(offset).take(query.limit) {
            let mut item=project(entry,keys,work)?;
            if name=="associations" { item["status"]=json!("recorded_label_binding_unknown"); }
            items.push(item);
        }
        out["items"]=Value::Array(items); out["recorded_items"]=json!(entries.len()); out["status"]=data["status"].clone();
        out["unsearched"]=json!(false); out
    };
    if family["unsearched"]==true && family["reason"]!="anonymous_model_has_no_label" {
        return Err(CoreError::limit("Family discovery admission unavailable"));
    }
    let total=family["candidate_matches"].as_u64().or_else(|| family["recorded_items"].as_u64()).unwrap_or(0) as usize;
    let pending=match family["items"].take() { Value::Array(items)=>items, _=>Vec::new() };
    family["items"]=json!([]); family["known_omitted"]=json!(total.saturating_sub(offset));
    let mut response=json!({"version":1,"generation":reader.generation,"root":identity(root,work)?,"family":name,
        "result":family,"offset":offset,"next_cursor":null,"page_complete":false,"uncertainty":SEMANTICS,
        "capture_partial_or_unknown":reader.manifest["coverage"].as_array().unwrap().is_empty() ||
            reader.manifest["coverage"].as_array().unwrap().len()>256 ||
            reader.manifest["coverage"].as_array().unwrap().iter().take(256).any(|v| v["status"]!="complete"),
        "capture_coverage":reader.manifest["coverage"].as_array().unwrap().iter().take(256).map(|v| json!({"family":v["family"],"status":v["status"]})).collect::<Vec<_>>()});
    // Reserve maximum cursor/counter growth before fitting optional identities.
    // Each item is encoded once for admission; the final wire bound is checked.
    let base=work.metadata(&response,1)?+1+768;
    if base>query.max_bytes { return Err(CoreError::limit("Mandatory family page exceeds max_bytes")); }
    let mut remaining=query.max_bytes-base; let mut accepted=Vec::new();
    for item in pending {
        let bytes=work.metadata(&item,1)?+1;
        if bytes>remaining { break; }
        remaining-=bytes; accepted.push(item);
    }
    let next=offset+accepted.len();
    if next<total && next==offset { return Err(CoreError::limit("Family page made no progress; increase max_bytes")); }
    response["result"]["items"]=Value::Array(accepted);
    response["result"]["known_omitted"]=json!(total.saturating_sub(next));
    response["page_complete"]=json!(next==total);
    if next<total { response["next_cursor"]=recorded_domain::cursor(&reader.generation,&scope,(next,0))?; }
    response["cost"]=json!({"reader_open":reader.method_lookup_baseline(),"incremental_request":work.value()});
    work.metadata(&response,5)?;
    response["cost"]["incremental_request"]=work.value();
    schema::encoded_bytes(&response,query.max_bytes.saturating_sub(1))?;
    Ok(response)
}

fn reference_family(reader: &Reader, query: &Query<'_>, direction: &str, work: &mut RequestWork) -> Result<Value> {
    let mut out = family(&reader.generation, query.id, "recorded_relationship_label_candidates");
    let parameters = json!({"id":query.id,"direction":direction,"limit":query.limit});
    let parameters = references::Query::parse(&parameters)?;
    match references::select_scoped(reader, &parameters, Some(work)) {
        Ok(mut result) => {
            // Incoming intentionally has no global candidate search. Outgoing
            // prefix rows still require that search's incompleteness notice.
            let complete = result["coverage"]["scan_complete"] == true &&
                (direction == "incoming" || result["coverage"]["candidate_search_complete"] == true);
            out["status"] = json!(if complete { "searched" } else { "not_searched" });
            out["reason"] = json!("recorded_labels_binding_unknown");
            out["known_omitted"] = result["coverage"]["known_omitted"].clone();
            out["unsearched"] = json!(!complete);
            out["coverage"] = result["coverage"].take(); out["items"] = result["relationships"].take();
            out["next_cursor"] = result["next_cursor"].take(); out["cost"] = result["cost"].take();
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
    if query.family.is_some() { return family_page(reader,query,root,work); }
    let mut response = json!({"version":1,"generation":reader.generation,"root":null,
        "generation_scope":"Every enclosed family, item, fact ID and source anchor belongs only to this immutable generation",
        "limits":{"items_per_family":query.limit,"wire_bytes_including_newline":query.max_bytes,
            "request":{"fact_visits":FACTS,"link_visits":LINKS,"label_comparisons":COMPARISONS,"label_bytes":LABEL_BYTES,
                "source_attempts":FILES,"source_bytes":SOURCE_BYTES,"source_file_bytes":262144,"processed_encoded_metadata_bytes":METADATA_BYTES},
            "transient_reservation_bytes":query.scratch()},
        "coverage":null,"uncertainty":SEMANTICS,"model":null,"families":{},
        "cost":{"reader_open":reader.method_lookup_baseline(),"method_directory":{"status":"not_requested","built_this_request":false},
            "incremental_request":{},"whole_job":{},
            "units":"Fact visits include revisits and reference traversal. Reader-open five passes and optional method/name directory construction are separate, counted once in whole_job. Encoded metadata charges count input checks/copies, component construction/encoding, projection and response/native/Ruby serialization copies; not exact heap or instructions.",
            "native_crossings":1,"fresh_reader_rebuilds_directory":true},
        "usage":{"returned_items":0,"wire_bytes_including_newline":65536}});
    response["root"] = identity(root, work)?;
    response["model"] = project(&root["attributes"]["model"], &["name", "base_class", "superclass", "abstract", "table", "inheritance_column", "source", "coherence"], work)?;
    let coverage = schema::array(&reader.manifest, "coverage")?;
    let mut captured = Vec::new();
    for entry in coverage.iter().take(256) { captured.push(project(entry, &["family", "status"], work)?); }
    response["coverage"] = json!({"capture_partial_or_unknown":coverage.is_empty() || coverage.len() > 256 || captured.iter().any(|v| v["status"] != "complete"),
        "families_not_projected":coverage.len().saturating_sub(256),"families":captured});
    if work.metadata(&response, 1)? + 1 > query.max_bytes {
        return Err(CoreError::limit("Mandatory model brief envelope exceeds max_bytes"));
    }
    // Components are consumed/projected sequentially, never accumulated beside
    // independent full selector outputs. Existing selector admission is shared.
    for name in ["columns", "associations"] {
        let before = *work;
        let mut family = fields(reader, root, name, query.limit, work)?;
        family["work"] = work.since(before);
        family["followup"] = followup(reader,query.id,name);
        response["families"][name] = family;
    }
    let before = *work;
    let (mut registry, candidate) = registries(reader, root, work)?;
    registry["work"] = work.since(before);
    registry["followup"] = followup(reader,query.id,"registry_candidates");
    response["families"]["registry_candidates"] = registry;
    let mut callbacks = family(&reader.generation, query.id, "registered_metadata_and_captured_source_potential");
    callbacks["model_registry_binding"] = json!("unknown");
    let before = *work;
    if let Some(id) = candidate {
        callbacks["fact_id"] = json!(id);
        callbacks["followup"] = json!({"operation":"callback_effects","generation":reader.generation,"id":id});
        let parameters = json!({"id":id,"limit":query.limit});
        match callback_effects::select_scoped(reader, &callback_effects::Query::parse(&parameters)?, crate::query::budget(), Some(work)) {
            Ok(mut result) => {
                callbacks["status"] = result["registry_status"].take(); callbacks["reason"] = json!("unique_label_candidate_only_binding_unknown");
                callbacks["observed_model_label"] = result["model"].take();
                callbacks["known_omitted"] = json!(result["coverage"]["rows_not_searched"].as_u64().unwrap_or(0) + result["coverage"]["rows_metadata_omitted"].as_u64().unwrap_or(0) + result["coverage"]["rows_output_omitted"].as_u64().unwrap_or(0));
                callbacks["unsearched"] = json!(result["coverage"]["source_rows_not_searched"] != 0 || result["coverage"]["rows_not_searched"] != 0);
                response["cost"]["method_directory"] = result["coverage"]["method_directory"].take();
                result["coverage"].as_object_mut().unwrap().remove("reader_open");
                result["coverage"].as_object_mut().unwrap().remove("method_directory");
                callbacks["coverage"] = result["coverage"].take(); callbacks["items"] = result["callbacks"].take();
            },
            Err(error) => limited(error, &mut callbacks)?,
        }
    } else { skip(&mut callbacks, "unique_complete_registry_label_candidate_unavailable"); }
    callbacks["work"] = work.since(before);
    response["families"]["callbacks"] = callbacks;
    for direction in ["outgoing", "incoming"] {
        let before = *work;
        let mut family = reference_family(reader, query, direction, work)?;
        family["work"] = work.since(before);
        family["followup"] = followup(reader,query.id,direction);
        // A summary can prune any item: only a fresh family enumeration is safe.
        family.as_object_mut().unwrap().remove("next_cursor");
        response["families"][direction] = family;
    }
    finish(response, query, work)
}

fn costs(response: &mut Value, work: &RequestWork) {
    response["cost"]["incremental_request"] = work.value();
    let mut recorded = json!({"status":"not_requested","built_this_request":false});
    for value in [&response["families"]["registry_candidates"]["directory"],
        &response["families"]["outgoing"]["cost"]["recorded_directory"],
        &response["families"]["incoming"]["cost"]["recorded_directory"]] {
        if value["status"]=="complete" && recorded["built_this_request"]!=true { recorded=value.clone(); }
    }
    response["cost"]["recorded_directory"]=recorded;
    let recorded=&response["cost"]["recorded_directory"];
    let recorded_build=recorded["built_this_request"]==true;
    let recorded_facts=if recorded_build {recorded["facts_visited"].as_u64().unwrap_or(0)} else {0};
    let baseline = &response["cost"]["reader_open"];
    let directory = &response["cost"]["method_directory"];
    let build = directory["built_this_request"] == true;
    response["cost"]["whole_job"] = json!({"reader_opens":1,"reader_open_fact_visits":baseline["facts"].as_u64().unwrap_or(0)*5,
        "directory_build_fact_visits":if build { directory["facts_visited"].as_u64().unwrap_or(0) } else {0},
        "recorded_directory_build_fact_visits":recorded_facts,
        "recorded_directory_retained_bytes":recorded["retained_bytes"].as_u64().unwrap_or(0),
        "fact_visits":recorded_facts + baseline["facts"].as_u64().unwrap_or(0)*5 + if build {directory["facts_visited"].as_u64().unwrap_or(0)} else {0} + work.facts as u64,
        "directory_build_key_bytes":if build {directory["key_bytes"].as_u64().unwrap_or(0)} else {0},
        "directory_build_sort_comparisons":if build {directory["sort_comparisons"].as_u64().unwrap_or(0)} else {0},
        "directory_retained_bytes":directory["retained_bytes"].as_u64().unwrap_or(0)});
}
fn finish(mut response: Value, query: &Query<'_>, work: &mut RequestWork) -> Result<Value> {
    work.finishing = true;
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
