//! LOS-147: saved definitions and builtin ownership observations are separate.
//! Root wires admission/index lifetime/public Reader; no source/runtime binding.
use crate::{error::{CoreError, Result}, method_lookup, query, recorded_domain, schema, store::Reader};
use serde_json::{json, Value};
use std::{cmp::Ordering, collections::{HashMap, HashSet}};

pub(crate) const MAX_OWNERS: usize = 64;
pub(crate) const MAX_METHODS: usize = 2048;
pub(crate) const MAX_PAGE: usize = 16;
const MAX_INPUT: usize = 2 * 1024 * 1024;
const MAX_OUTPUT: usize = 64 * 1024;

pub(crate) struct Query<'a> {
    pub id: &'a str, pub family: &'a str, pub limit: usize, pub cursor: Option<&'a Value>, pub max_bytes: usize,
}
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let id = schema::hash(schema::string(request,"id")?)?;
        let family = match request.get("family") {
            None | Some(Value::Null) => "contributions",
            Some(value) => value.as_str().filter(|s| ["contributions","methods"].contains(s))
                .ok_or_else(|| CoreError::input("Unknown source comprehension family"))?,
        };
        let limit = match request.get("limit") {
            None => 8,
            Some(value) => value.as_u64().filter(|n| *n>0 && *n<=MAX_PAGE as u64)
                .ok_or_else(|| CoreError::input("Invalid source comprehension page limit"))? as usize,
        };
        let max_bytes = match request.get("max_bytes") {
            None => 32768,
            Some(value) => value.as_u64().filter(|n| *n>0 && *n<=MAX_OUTPUT as u64)
                .ok_or_else(|| CoreError::input("Invalid source comprehension byte limit"))? as usize,
        };
        Ok(Self { id,family,limit,cursor:request.get("cursor"),max_bytes })
    }
    pub(crate) fn scratch(&self) -> usize { 8 * 1024 * 1024 }
    pub(crate) fn position(&self, generation: &str) -> Result<(usize,usize)> {
        recorded_domain::position(self.cursor,generation,&json!(["source_comprehension",self.id,self.family]))
    }
}

fn label(value: &Value, nullable: bool) -> Result<()> {
    if nullable && value.is_null() { return Ok(()); }
    match value.as_str() {
        Some(s) if !s.is_empty() && s.len() <= 4096 => Ok(()),
        _ => Err(CoreError::input("Invalid ownership label")),
    }
}
fn hint(value: &Value) -> Result<()> {
    if value.is_null() { return Ok(()); }
    schema::model_object(value, &["path", "line"])?;
    label(&value["path"], false)?;
    if !value["line"].as_u64().is_some_and(|n| n > 0 && n <= u32::MAX as u64) {
        return Err(CoreError::input("Invalid ownership source hint line"));
    }
    Ok(())
}

/// Validates raw descriptors, including anonymous owners and explicit undef gaps.
/// Order is observed Ruby ancestry, never an inferred source include order.
pub(crate) fn validate_observation(data: &Value) -> Result<usize> {
    schema::depth(data)?;
    schema::encoded_bytes(data, MAX_INPUT)?;
    schema::model_object(data, &["name", "status", "superclass", "stop_before", "ancestors", "effective_methods"])?;
    for key in ["name", "superclass", "stop_before"] { label(&data[key], true)?; }
    if data["status"] != "observed" { return Err(CoreError::input("Invalid ownership status")); }
    let owners = schema::array(data, "ancestors")?;
    let methods = schema::array(data, "effective_methods")?;
    if owners.len() > MAX_OWNERS || methods.len() > MAX_METHODS { return Err(CoreError::limit("Ownership inventory exceeds allowance")); }
    let mut entries = owners.len();
    let mut names = HashSet::new();
    for (index, owner) in owners.iter().enumerate() {
        schema::model_object(owner, &["index", "name", "kind", "methods"])?;
        label(&owner["name"], true)?;
        if owner["index"].as_u64() != Some(index as u64) || !matches!(owner["kind"].as_str(), Some("class" | "module")) {
            return Err(CoreError::input("Invalid ownership ancestor"));
        }
        let mut direct = HashSet::new();
        let rows = schema::array(owner, "methods")?;
        entries = entries.checked_add(rows.len()).filter(|n| *n <= 100_000)
            .ok_or_else(|| CoreError::limit("Ownership entries exceed allowance"))?;
        for method in rows {
            schema::model_object(method, &["name", "visibility", "source"])?;
            label(&method["name"], false)?;
            let name = method["name"].as_str().unwrap();
            if !direct.insert(name) || !matches!(method["visibility"].as_str(), Some("public" | "protected" | "private")) {
                return Err(CoreError::input("Duplicate or invalid ownership method"));
            }
            names.insert(name);
            if names.len() > MAX_METHODS { return Err(CoreError::limit("Ownership names exceed allowance")); }
            hint(&method["source"])?;
        }
    }
    let mut seen = HashSet::new();
    for method in methods {
        schema::model_object(method, &["name", "owner_index", "source"])?;
        label(&method["name"], false)?;
        let name = method["name"].as_str().unwrap();
        if !names.contains(name) || !seen.insert(name) { return Err(CoreError::input("Invalid effective ownership name")); }
        hint(&method["source"])?;
        if method["owner_index"].is_null() {
            if !method["source"].is_null() { return Err(CoreError::input("Unknown owner cannot supply a source hint")); }
        } else {
            let index = method["owner_index"].as_u64().filter(|i| *i < owners.len() as u64)
                .ok_or_else(|| CoreError::input("Invalid effective owner index"))? as usize;
            let direct = owners[index]["methods"].as_array().unwrap().iter().find(|row| row["name"] == method["name"])
                .ok_or_else(|| CoreError::input("Effective owner does not define method"))?;
            if direct["source"] != method["source"] { return Err(CoreError::input("Effective descriptor hint disagrees")); }
        }
    }
    if seen != names { return Err(CoreError::input("Incomplete effective ownership inventory")); }
    Ok(entries + methods.len())
}

fn normalize_hints(data: &mut Value, root: &str) {
    fn normalize(row: &mut Value, root: &str) {
        if let Some(path) = row["source"]["path"].as_str() {
            let path = path.strip_prefix(root).and_then(|tail| tail.strip_prefix('/'))
                .or_else(|| (!path.starts_with('/')).then_some(path));
            row["source"] = match path.filter(|path| schema::path(path).is_ok()) {
                Some(path) => json!({"path":path,"line":row["source"]["line"]}),
                None => Value::Null,
            };
        }
    }
    for owner in data["ancestors"].as_array_mut().unwrap() {
        for method in owner["methods"].as_array_mut().unwrap() { normalize(method,root); }
    }
    for method in data["effective_methods"].as_array_mut().unwrap() { normalize(method,root); }
}

pub(crate) fn batch(context: &Value, observation: &Value, root: &str) -> Result<Value> {
    if !root.starts_with('/') || root.ends_with('/') { return Err(CoreError::input("Expected absolute ownership root without trailing slash")); }
    schema::depth(observation)?;
    schema::encoded_bytes(observation, schema::MAX_FACTS_BYTES)?;
    schema::model_object(observation, &["version", "models"])?;
    if observation["version"] != 1 { return Err(CoreError::input("Unknown ownership observation version")); }
    let models = schema::array(observation, "models")?;
    let mut admission = schema::ObservationAdmission::new(context)?;
    admission.ensure_facts(models.len())?;
    let mut facts = Vec::with_capacity(models.len());
    for (ordinal, data) in models.iter().enumerate() {
        let entries = validate_observation(data)?;
        // Registry ordinals distinguish duplicate/anonymous labels; not source identity.
        let id = schema::digest(&schema::canonical(&json!(["rails_source_ownership", 1, ordinal, data["name"]]))?);
        let mut fact = json!({"id":id,"kind":"rails_source_ownership","name":data["name"].as_str().unwrap_or("Anonymous model"),
            "evidence":"runtime","path":null,"location":null,"links":[],
            "attributes":{"source_comprehension":{"version":1,"ordinal":ordinal,"observation":null}}});
        // Input is sized and validated before this sole bounded tree copy.
        let mut data = data.clone();
        normalize_hints(&mut data,root);
        fact["attributes"]["source_comprehension"]["observation"] = data;
        admission.admit(&fact, entries)?;
        facts.push(fact);
    }
    let mut out = json!({"appended":admission.appended(),"coverage":[{"family":"source_ownership","status":"partial",
        "scope":"Explicit loaded classes, builtin instance-method descriptors before a supplied stop boundary; no method execution",
        "reason":"Ordered loaded ancestry and hints only. Saved-source coherence, conditions, dispatch and execution unknown."}]});
    out["facts"] = Value::Array(facts);
    Ok(out)
}

pub(crate) fn validate_fact(fact: &Value) -> Result<()> {
    if fact["kind"] != "rails_source_ownership" || fact["evidence"] != "runtime" || !fact["path"].is_null() ||
        !fact["location"].is_null() || !schema::array(fact,"links")?.is_empty() {
        return Err(CoreError::input("Invalid ownership fact provenance"));
    }
    schema::model_object(&fact["attributes"], &["source_comprehension"])?;
    let data = &fact["attributes"]["source_comprehension"];
    schema::model_object(data, &["version", "ordinal", "observation"])?;
    if data["version"] != 1 || data["ordinal"].as_u64().is_none() { return Err(CoreError::input("Unknown ownership fact version")); }
    validate_observation(&data["observation"])?;
    let observation = &data["observation"];
    for method in observation["ancestors"].as_array().unwrap().iter().flat_map(|row| row["methods"].as_array().unwrap())
        .chain(observation["effective_methods"].as_array().unwrap()) {
        if let Some(path) = method["source"]["path"].as_str() { schema::path(path)?; }
    }
    let name = data["observation"]["name"].as_str().unwrap_or("Anonymous model");
    let expected = schema::digest(&schema::canonical(&json!(["rails_source_ownership",1,data["ordinal"],data["observation"]["name"]]))?);
    if fact["id"] != expected || fact["name"] != name { return Err(CoreError::input("Ownership identity disagrees")); }
    Ok(())
}

fn owner(fact: &Value) -> Option<&str> {
    if fact["evidence"] != "static" { return None; }
    match fact["kind"].as_str()? {
        "class" | "module" => fact["name"].as_str(),
        "method" => method_lookup::key(fact).map(|(owner,_)| owner),
        _ => None,
    }
}
fn identity(fact: &Value) -> Value {
    json!({"id":fact["id"],"kind":fact["kind"],"name":fact["name"],"evidence":fact["evidence"],"path":fact["path"],"location":fact["location"]})
}

/// Root supplies one owner page from Directory, and zero/one/multiple selected
/// ownership facts through the existing recorded-domain index. No Ruby analysis.
/// A unique label is still only a candidate for the saved model's loaded registry.
pub(crate) fn project(generation: &str, model: &Value, ownership: &[&Value], owner_label: &str,
    candidates: &[&Value], matches_seen: usize, offset: usize, range_complete: bool) -> Result<Value> {
    schema::hash(generation)?;
    schema::hash(schema::string(model,"id")?)?;
    if candidates.len() > MAX_PAGE || ownership.len() > 2 || candidates.len() > matches_seen.saturating_sub(offset) {
        return Err(CoreError::input("Invalid source comprehension page"));
    }
    if owner_label.is_empty() || owner_label.len() > 4096 { return Err(CoreError::input("Invalid owner label")); }
    if !matches!(model["kind"].as_str(),Some("rails_model" | "class")) { return Err(CoreError::input("Expected model or class fact")); }
    // Charge borrowed inputs before copying any identity/projection metadata.
    schema::encoded_bytes(&candidates, MAX_INPUT)?;
    schema::encoded_bytes(&ownership, MAX_INPUT)?;
    for fact in ownership { validate_fact(fact)?; }
    let model_label = if model["kind"] == "rails_model" { &model["attributes"]["model"]["name"] } else { &model["name"] };
    for fact in ownership {
        if model_label.is_null() || fact["attributes"]["source_comprehension"]["observation"]["name"] != *model_label {
            return Err(CoreError::input("Ownership label candidate disagrees with model"));
        }
    }
    let observed = (ownership.len() == 1).then(|| &ownership[0]["attributes"]["source_comprehension"]["observation"]);
    let owners = observed.and_then(|data| data["ancestors"].as_array());
    let owner_matches = owners.map_or(0, |rows| rows.iter().filter(|row| row["name"] == owner_label).count());
    let in_chain = owner_matches == 1;
    if model_label.as_str() != Some(owner_label) && !in_chain {
        return Err(CoreError::input("Owner is not a unique observed contribution candidate"));
    }
    let complete = range_complete && offset == 0 && candidates.len() == matches_seen;
    let mut counts = HashMap::new();
    let mut ids = HashSet::new();
    for fact in candidates {
        if owner(fact) != Some(owner_label) || !ids.insert(schema::hash(schema::string(fact,"id")?)?) { return Err(CoreError::input("Invalid owner candidate selection")); }
        if fact["kind"] == "method" { *counts.entry(schema::string(&fact["attributes"],"method_name")?).or_insert(0usize) += 1; }
    }
    let mut contributions = Vec::with_capacity(candidates.len());
    for fact in candidates {
        let name = fact["attributes"]["method_name"].as_str();
        let effective = observed.and_then(|data| data["effective_methods"].as_array()).and_then(|rows| rows.iter().find(|row| row["name"].as_str() == name));
        let effective_owner = effective.and_then(|row| row["owner_index"].as_u64()).and_then(|index| owners?.get(index as usize));
        let status = if fact["kind"] != "method" { "as_written_declaration" }
            else if !complete { "unknown_incomplete_candidates" }
            else if fact["attributes"]["name_resolution"] != "lexical" { "unknown_precedence" }
            else if counts.get(name.unwrap()).copied().unwrap_or(0) > 1 { "ambiguous_definitions" }
            else if owner_matches > 1 { "unknown_duplicate_owner_labels" }
            else if effective_owner.is_some_and(|row| row["name"] == owner_label) { "observed_loaded_owner_source_binding_unknown" }
            else if effective_owner.is_some() { "alternative_to_observed_loaded_owner" }
            else { "unknown_precedence" };
        contributions.push(json!({"fact":identity(fact),"owner":owner_label,"method_name":name,"status":status,
            "observed_owner":effective_owner.map(|row| &row["name"]),
            "observed_source_hint":effective.map(|row| &row["source"]),
            "source":{"operation":"source","generation":generation,"id":fact["id"]},
            "callers":{"operation":"references","generation":generation,"id":fact["id"],"direction":"incoming","cursor":null}}));
    }
    let mut out = json!({"version":1,"generation":generation,"model":identity(model),"owner":owner_label,
        "composition":"identified_contributions","source_runtime_coherence":"unknown",
        "ownership_status":if ownership.len()==1 {"unique_label_candidate_binding_unknown"} else if ownership.is_empty() {"unavailable"} else {"ambiguous"},
        "ownership_evidence_ids":ownership.iter().map(|fact| &fact["id"]).collect::<Vec<_>>(),
        "owners":owners.map(|rows| rows.iter().map(|row| json!({"index":row["index"],"name":row["name"],"kind":row["kind"]})).collect::<Vec<_>>()),
        "coverage":{"candidate_matches_seen":matches_seen,"range_complete":range_complete,"offset":offset,"returned":contributions.len(),"page_complete":complete,
            "scope":"Indexed saved definitions for one exact owner label; labels do not establish runtime binding"},
        "continuation":null,
        "semantics":"Separate as-written contributions, not a concatenated effective runtime class. Loaded owner is observed; saved-source binding, conditions, invocation and execution remain unknown."});
    out["contributions"] = Value::Array(contributions);
    out["observed_only"] = json!([]);
    schema::encoded_bytes(&out, MAX_OUTPUT)?;
    Ok(out)
}

#[derive(Default)]
struct Work { visits: usize, comparisons: usize, bytes: usize }
impl method_lookup::Work for Work {
    fn visit(&mut self) -> bool {
        if self.visits==20_000 { return false; } self.visits+=1; true
    }
    fn bytes(&mut self, bytes: usize) -> bool {
        if bytes> (32*1024*1024usize).saturating_sub(self.bytes) { return false; } self.bytes+=bytes; true
    }
    fn compare(&mut self, a: &str, b: &str) -> Option<Ordering> {
        if self.comparisons==100_000 || !self.bytes(a.len().saturating_add(b.len())) { return None; }
        self.comparisons+=1; Some(a.cmp(b))
    }
    fn compare_digest(&mut self, a: &[u8;32], b: &[u8;32]) -> Option<Ordering> {
        if self.comparisons==100_000 || !self.bytes(64) { return None; }
        self.comparisons+=1; Some(a.cmp(b))
    }
}
impl recorded_domain::LabelWork for Work {
    fn compare(&mut self, a: &str, b: &str) -> Result<Ordering> {
        method_lookup::Work::compare(self,a,b).ok_or_else(|| CoreError::limit("Ownership label work exhausted"))
    }
}

/// One owner/declaration or one owner/method candidate range per response.
/// Two cursor positions identify the owner/method row and its candidate offset.
/// No automatic whole-family traversal or source I/O. Root's thin Reader dispatch
/// calls this with its pinned Reader after reserving Query::scratch.
pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    let root = reader.stored_fact(query.id)?;
    if !matches!(root["kind"].as_str(),Some("rails_model" | "class")) { return Err(CoreError::input("Expected saved model or class")); }
    let label = if root["kind"]=="rails_model" { root["attributes"]["model"]["name"].as_str() } else { root["name"].as_str() };
    let label = label.ok_or_else(|| CoreError::input("Anonymous model source composition is unavailable"))?;
    let mut work = Work::default();
    let (registries,registry_stats) = reader.recorded_candidates(label,Some("rails_source_ownership"),0,2,&mut work)?;
    // A two-element witness means ambiguity, irrespective of omitted matches.
    let ownership = registries.positions.iter().map(|index| &reader.facts[*index]).collect::<Vec<_>>();
    for fact in &ownership { validate_fact(fact)?; }
    let observed = (registries.total==1).then(|| &ownership[0]["attributes"]["source_comprehension"]["observation"]);
    let (row,offset) = query.position(&reader.generation)?;
    let fallback = json!([{"index":0,"name":label,"kind":"class","methods":[]}]);
    let owners = observed.map_or(&fallback, |data| &data["ancestors"]).as_array().unwrap();
    let rows = if query.family=="contributions" { owners.len() }
        else { owners.iter().map(|owner| owner["methods"].as_array().unwrap().len()).sum() };
    if row>=rows && !(row==0 && rows==0) { return Err(CoreError::input("Source comprehension cursor is beyond family")); }
    if rows==0 {
        if offset!=0 { return Err(CoreError::input("Invalid empty-family candidate offset")); }
        let mut out = project(&reader.generation,root,&ownership,label,&[],0,0,true)?;
        out["family"] = json!(query.family);
        out["coverage"]["reason"] = json!("no_observed_method_inventory_not_evidence_of_absence");
        return finish(out,query,&work,registry_stats,Value::Null);
    }
    let (selected_owner,method) = if query.family=="contributions" {
        // Read the model's as-written declaration first without changing the
        // separately reported observed ancestry order or claiming precedence.
        let direct = owners.iter().position(|owner| owner["name"]==label);
        let position = match direct {
            Some(direct) if row==0 => direct,
            Some(direct) if row<=direct => row-1,
            _ => row,
        };
        (&owners[position],None)
    } else {
        let mut position = row;
        let mut selected = None;
        for owner in owners {
            let methods = owner["methods"].as_array().unwrap();
            if position<methods.len() { selected=Some((owner,Some(&methods[position]))); break; }
            position-=methods.len();
        }
        selected.ok_or_else(|| CoreError::input("Invalid source comprehension method position"))?
    };
    // Anonymous/duplicate owner labels are not resolved to a different class.
    let owner = selected_owner["name"].as_str().ok_or_else(|| CoreError::input("Anonymous contribution has no source label candidate"))?;
    let mut method_stats = Value::Null;
    let (positions,matches_seen,complete,partial,next_offset) = if let Some(method) = method {
        let name = schema::string(method,"name")?;
        let (page,stats) = reader.with_method_directory(query::budget(), |directory,built| {
            (directory.page(&reader.facts,owner,name,offset,query.limit,&mut work),directory.stats(built).value())
        })?;
        let page = page?;
        method_stats=stats;
        (page.positions,page.matches_seen,page.range_complete,page.partial,page.next_offset)
    } else {
        let kind = if selected_owner["kind"]=="module" {"module"} else {"class"};
        let (page,_) = reader.recorded_candidates(owner,Some(kind),offset,query.limit,&mut work)?;
        if offset>page.total { return Err(CoreError::input("Contribution cursor exceeds candidate range")); }
        let next = offset+page.positions.len();
        let complete = next==page.total;
        (page.positions,page.total,complete,false,(next<page.total).then_some(next))
    };
    let candidates = positions.iter().map(|index| &reader.facts[*index]).collect::<Vec<_>>();
    let mut out = project(&reader.generation,root,&ownership,owner,&candidates,matches_seen,offset,complete)?;
    if candidates.is_empty() && complete && offset==0 {
        if let Some(method) = method {
            out["observed_only"] = json!([{"name":method["name"],"visibility":method["visibility"],"source_hint":method["source"],
                "status":"no_saved_definition_candidate","source_runtime_coherence":"unknown"}]);
        }
    }
    out["family"] = json!(query.family);
    out["coverage"]["partial"] = json!(partial);
    out["coverage"]["family_rows"] = json!(rows);
    out["coverage"]["row"] = json!(row);
    // Stop on zero-progress exhaustion. Never advertise a looping continuation.
    let next = next_offset.map(|offset| (row,offset)).or_else(|| (!partial && row+1<rows).then_some((row+1,0)));
    if let Some(position) = next {
        let cursor = recorded_domain::cursor(&reader.generation,&json!(["source_comprehension",query.id,query.family]),position)?;
        out["continuation"] = json!({"operation":"source_comprehension","id":query.id,"generation":reader.generation,"family":query.family,"cursor":cursor});
    }
    finish(out,query,&work,registry_stats,method_stats)
}

fn finish(mut out: Value, query: &Query<'_>, work: &Work, registry_stats: Value, method_stats: Value) -> Result<Value> {
    out["usage"] = json!({"candidate_fact_visits":work.visits,"label_comparisons":work.comparisons,"label_bytes":work.bytes,
        "recorded_directory":registry_stats,"method_directory":method_stats,"source_reads":0,
        "scratch_reservation":query.scratch(),"max_wire_bytes":query.max_bytes,
        "scope":"Reader open and lazy directory construction are separate from these request counters; no latency or RSS claim"});
    // Output counting precedes native envelope serialization. The dispatch owns
    // its existing envelope/bridge reservation; keep one newline byte here.
    schema::encoded_bytes(&out,query.max_bytes.saturating_sub(1))?;
    Ok(out)
}

#[cfg(test)]
#[path = "source_comprehension_tests.rs"]
mod tests;
