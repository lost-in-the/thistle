//! Registered save-chain evidence, never callback execution or dispatch proof.
use crate::{error::{CoreError, Result}, schema};
use serde_json::{json, Value};
use std::path::Path;

const SCOPE: &str = "Registered save chains of already loaded supported Active Record descendants in the supplied process";

// Both runtime families share native admission; publication validates actual facts.
pub fn batch(context: &Value, observation: &Value) -> Result<Value> {
    schema::depth(observation)?;
    schema::model_object(observation, &["version", "active_record_version", "root", "status", "models"])?;
    schema::model_label(&observation["active_record_version"])?;
    schema::model_label(&observation["root"])?;
    if observation["version"] != 1 || !matches!(observation["status"].as_str(), Some("observed" | "unavailable")) {
        return Err(CoreError::input("Unsupported callback observation"));
    }
    let models = schema::array(observation, "models")?;
    if observation["status"] == "unavailable" && !models.is_empty() ||
        observation["status"] == "observed" && !schema::supported_active_record(&observation["active_record_version"]) {
        return Err(CoreError::input("Invalid callback inventory provenance"));
    }
    schema::encoded_bytes(observation, schema::MAX_FACTS_BYTES)?;
    let mut admission = schema::ObservationAdmission::new(context)?;
    admission.ensure_facts(models.len())?;
    let mut facts = Vec::with_capacity(models.len());
    for (ordinal, model) in models.iter().enumerate() {
        schema::model_object(model, &["name", "superclass", "save"])?;
        schema::model_label(&model["name"])?;
        schema::model_label(&model["superclass"])?;
        family(&model["save"], false)?;
        let mut data = model.clone();
        let object = data.as_object_mut().unwrap();
        object.insert("version".into(), json!(1));
        object.insert("ordinal".into(), json!(ordinal));
        object.insert("active_record_version".into(), observation["active_record_version"].clone());
        object.insert("coherence".into(), json!("unknown"));
        object.insert("provenance".into(), json!("registered_metadata"));
        let mut count = 0usize;
        for (position, entry) in data["save"]["entries"].as_array_mut().unwrap().iter_mut().enumerate() {
            count += 1;
            entry.as_object_mut().unwrap().insert("position".into(), json!(position));
            normalize_reference(&mut entry["filter"], &observation["root"]);
            for key in ["if", "unless"] {
                if let Some(conditions) = entry[key].as_array_mut() {
                    count += conditions.len();
                    for condition in conditions { normalize_reference(condition, &observation["root"]); }
                }
            }
        }
        let (id, name) = identity(&data)?;
        let fact = json!({"id":id,"kind":"rails_save_callbacks","name":name,"evidence":"runtime",
            "path":null,"location":null,"attributes":{"callbacks":data},"links":links(&data)});
        validate_fact(&fact)?;
        admission.admit(&fact, count)?;
        facts.push(fact);
    }
    Ok(json!({"facts":facts,"appended":admission.appended(),"coverage":[
        {"family":"rails_save_callbacks","status":if observation["status"] == "observed" {"partial"} else {"unavailable"},
         "scope":SCOPE,"reason":"Per-model observed/partial/unavailable chains. Zero-based registered positions are not execution chronology. Shared superclass entries and effective method owners do not prove registration sites. Source hints do not prove source/runtime coherence."},
        {"family":"rails_callback_execution","status":"unavailable","scope":"Callback bodies, conditions, scopes, effects and around-callback chronology",
         "reason":"Never executed or inferred"}],
        "callback_observer":{"version":1,"active_record_version":observation["active_record_version"],"scope":SCOPE}}))
}

fn reference(value: &Value, normalized: bool) -> Result<()> {
    match value["kind"].as_str() {
        Some("method") => {
            schema::model_object(value, &["kind", "name", "owner", "source"])?;
            schema::string(value, "name")?;
            schema::model_label(&value["name"])?;
            schema::model_label(&value["owner"])?;
        }
        Some("proc") => schema::model_object(value, &["kind", "source"] )?,
        Some("opaque" | "unavailable") => return schema::model_object(value, &["kind"]),
        _ => return Err(CoreError::input("Invalid callback reference")),
    }
    if !value["source"].is_null() {
        let source = &value["source"];
        schema::model_object(source, &["path", "line"])?;
        let path = schema::string(source, "path")?;
        schema::model_label(&source["path"])?;
        if normalized { schema::path(path)?; }
        if !source["line"].as_u64().is_some_and(|n| n > 0 && n <= u32::MAX as u64) {
            return Err(CoreError::input("Invalid callback source line"));
        }
    }
    Ok(())
}

fn family(value: &Value, normalized: bool) -> Result<()> {
    schema::model_object(value, &["status", "entries"])?;
    let entries = schema::array(value, "entries")?;
    if entries.len() > 100_000 { return Err(CoreError::limit("Callback chain exceeds max_entries")); }
    if !matches!(value["status"].as_str(), Some("observed" | "partial" | "unavailable")) ||
        value["status"] == "unavailable" && !entries.is_empty() {
        return Err(CoreError::input("Invalid callback chain coverage"));
    }
    let mut incomplete = false;
    let mut count = entries.len();
    for (position, entry) in entries.iter().enumerate() {
        let mut fields = vec!["kind", "filter", "if", "unless", "inherited"];
        if normalized { fields.push("position"); }
        schema::model_object(entry, &fields)?;
        if normalized && entry["position"].as_u64() != Some(position as u64) {
            return Err(CoreError::input("Invalid registered callback position"));
        }
        if !entry["kind"].is_null() && !matches!(entry["kind"].as_str(), Some("before" | "after" | "around")) ||
            !(entry["inherited"].is_null() || entry["inherited"].is_boolean()) {
            return Err(CoreError::input("Invalid callback kind or inheritance"));
        }
        incomplete |= entry["kind"].is_null();
        reference(&entry["filter"], normalized)?;
        for key in ["if", "unless"] {
            if entry[key].is_null() { incomplete = true; continue; }
            let conditions = schema::array(entry, key)?;
            count = count.saturating_add(conditions.len());
            if count > 100_000 { return Err(CoreError::limit("Callback conditions exceed max_entries")); }
            for condition in conditions { reference(condition, normalized)?; }
        }
    }
    if incomplete && value["status"] == "observed" { return Err(CoreError::input("Incomplete callback chain cannot be observed")); }
    Ok(())
}

fn normalize_reference(value: &mut Value, root: &Value) {
    if value.get("source").is_none_or(Value::is_null) { return; }
    let relative = root.as_str().filter(|r| Path::new(r).is_absolute()).and_then(|root| {
        let path = Path::new(value["source"]["path"].as_str()?);
        // Source locations are hints only. Never read files or canonicalize through
        // symlinks here, and never persist paths outside the supplied source root.
        if !path.is_absolute() || path.components().any(|c| matches!(c, std::path::Component::ParentDir | std::path::Component::CurDir)) { return None; }
        let relative = path.strip_prefix(root).ok()?.to_str()?;
        schema::path(relative).ok().map(str::to_owned)
    });
    if let Some(path) = relative { value["source"]["path"] = json!(path); }
    else { value["source"] = Value::Null; }
}

fn identity(data: &Value) -> Result<(String, String)> {
    let name = data["name"].as_str().map(str::to_owned).unwrap_or_else(|| format!("Anonymous model {}", data["ordinal"]));
    Ok((schema::digest(&schema::canonical(&json!(["rails_save_callbacks",1,data["ordinal"],data["name"]]))?), name))
}

fn links(data: &Value) -> Vec<Value> {
    let mut links = Vec::new();
    if let Some(name) = data["name"].as_str() {
        links.push(json!({"relation":"callback_model_label","target":name,"resolution":"unresolved"}));
    }
    links
}

/// Publication and reader validation hook; known v1 evidence is never opaque.
pub(crate) fn validate_fact(fact: &Value) -> Result<()> {
    schema::model_object(&fact["attributes"], &["callbacks"])?;
    let data = &fact["attributes"]["callbacks"];
    schema::model_object(data, &["name","superclass","save","version","ordinal","active_record_version","coherence","provenance"])?;
    schema::model_label(&data["name"])?;
    schema::model_label(&data["superclass"])?;
    if data["version"] != 1 || data["ordinal"].as_u64().is_none() || !schema::supported_active_record(&data["active_record_version"]) ||
        data["coherence"] != "unknown" || data["provenance"] != "registered_metadata" || fact["evidence"] != "runtime" ||
        fact["kind"] != "rails_save_callbacks" || !fact["path"].is_null() || !fact["location"].is_null() {
        return Err(CoreError::input("Invalid callback provenance"));
    }
    family(&data["save"], true)?;
    let (id, name) = identity(data)?;
    if fact["id"] != id || fact["name"] != name || fact["links"] != Value::Array(links(data)) {
        return Err(CoreError::input("Invalid callback identity or relationships"));
    }
    Ok(())
}

#[cfg(test)]
#[path = "callbacks_tests.rs"]
mod tests;
