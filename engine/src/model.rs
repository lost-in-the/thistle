//! Loaded Rails model observations. Ruby supplies primitives, never engine facts.
use crate::{error::{CoreError, Result}, schema};
use serde_json::{json, Value};

const SCOPE: &str = "Already loaded ActiveRecord::Base descendants in the supplied application's process; no eager load, reload, target resolution or record execution";

/// Append one observation batch to the existing static/route capture, atomically.
/// Consume the request-owned capture without cloning its files or existing facts.
/// The caller publishes only a successful result; a refused request is discarded.
pub fn append(capture: Value, observation: &Value) -> Result<Value> {
    schema::capture(&capture)?;
    schema::depth(observation)?;
    schema::model_object(observation, &["version", "active_record_version", "status", "models"])?;
    if observation["version"] != 1 || !matches!(observation["status"].as_str(), Some("observed" | "unavailable")) {
        return Err(CoreError::input("Unsupported model observation"));
    }
    schema::model_label(&observation["active_record_version"])?;
    let models = schema::array(observation, "models")?;
    if observation["status"] == "unavailable" && !models.is_empty() {
        return Err(CoreError::input("Unavailable inventory cannot contain models"));
    }
    if observation["status"] == "observed" && observation["active_record_version"] != "8.1.4" {
        return Err(CoreError::input("Unsupported Active Record observation version"));
    }
    let limits = &capture["producer"]["effective_limits"];
    let limit = |key, ceiling| -> Result<usize> {
        let value = limits[key].as_u64().filter(|n| *n > 0 && *n <= ceiling)
            .ok_or_else(|| CoreError::input(format!("Invalid combined capture limit {key}")))?;
        Ok(value as usize)
    };
    let max_facts = limit("max_facts", 100_000)?;
    let max_links = limit("max_links", 500_000)?;
    let max_entries = limit("max_entries", 100_000)?;
    let max_diagnostics = limit("max_diagnostics", 1_000)?;
    let original = schema::array(&capture, "facts")?;
    if original.len().saturating_add(models.len()) > max_facts || schema::array(&capture, "diagnostics")?.len() > max_diagnostics {
        return Err(CoreError::limit("Combined model capture exceeds max_facts or max_diagnostics"));
    }
    let mut links: usize = original.iter().map(|f| f["links"].as_array().map_or(0, Vec::len)).sum();
    let mut bytes = schema::canonical(&capture["facts"])?.len();
    let mut entries = 0usize;
    // Refuse an oversized observation before building facts.
    if schema::canonical(observation)?.len() > schema::MAX_FACTS_BYTES {
        return Err(CoreError::limit("Model observation exceeds 64 MiB"));
    }
    let mut result = capture;
    for (ordinal, observed) in models.iter().enumerate() {
        schema::model_observation(observed)?;
        entries = entries.saturating_add(observed["primary_key"].as_array().map_or(0, Vec::len));
        entries = entries.saturating_add(observed["columns"]["entries"].as_array().unwrap().len())
            .saturating_add(observed["associations"]["entries"].as_array().unwrap().len());
        if entries > max_entries { return Err(CoreError::limit("Model metadata exceeds max_entries")); }
        let mut data = observed.clone();
        let object = data.as_object_mut().unwrap();
        object.insert("version".into(), json!(1));
        object.insert("ordinal".into(), json!(ordinal));
        object.insert("active_record_version".into(), observation["active_record_version"].clone());
        object.insert("coherence".into(), json!("unknown"));
        object.insert("source".into(), json!("unavailable"));
        let name = observed["name"].as_str().map(str::to_owned).unwrap_or_else(|| format!("Anonymous model {ordinal}"));
        let id = schema::digest(&schema::canonical(&json!(["rails_model", 1, ordinal, observed["name"]]))?);
        let fact = json!({"id":id,"kind":"rails_model","name":name,"evidence":"runtime",
            "path":null,"location":null,"attributes":{"model":data},"links":model_links(observed)});
        links = links.saturating_add(fact["links"].as_array().unwrap().len());
        // Existing [] already charged; every appended member needs at most one comma.
        bytes = bytes.saturating_add(schema::canonical(&fact)?.len() + 1);
        if links > max_links { return Err(CoreError::limit("Combined capture exceeds max_links")); }
        if bytes > schema::MAX_FACTS_BYTES { return Err(CoreError::limit("Combined capture exceeds 64 MiB fact budget")); }
        result["facts"].as_array_mut().unwrap().push(fact);
    }
    if links > max_links || bytes > schema::MAX_FACTS_BYTES { return Err(CoreError::limit("Combined capture exceeds evidence budget")); }
    result["producer"]["model_observer"] = json!({"version":1,"active_record_version":observation["active_record_version"],"scope":SCOPE});
    let coverage = result["coverage"].as_array_mut().unwrap();
    coverage.retain(|c| !matches!(c["family"].as_str(), Some("rails_models" | "rails_model_effects")));
    coverage.push(json!({"family":"rails_models","status":if observation["status"] == "observed" {"partial"} else {"unavailable"},
        "scope":SCOPE,"reason":"Per-model family status distinguishes observed empty from unavailable. Database column defaults only; Ruby attribute defaults and source/runtime coherence unknown. Names are labels, not runtime dispatch."}));
    coverage.push(json!({"family":"rails_model_effects","status":"unavailable",
        "scope":"Callbacks, scopes, predicates, custom attribute defaults, indexes, concerns and all-adapter behavior",
        "reason":"Not executed or inferred by this observer"}));
    schema::capture(&result)?;
    Ok(result)
}

pub(crate) fn model_links(data: &Value) -> Vec<Value> {
    let mut links = Vec::new();
    if let Some(base) = data["base_class"].as_str() {
        links.push(json!({"relation":"model_base_label","target":base,"resolution":"unresolved"}));
    }
    if let Some(associations) = data["associations"]["entries"].as_array() {
        for association in associations {
            if let (Some(name), Some(target)) = (association["name"].as_str(), association["target"].as_str()) {
                links.push(json!({"relation":"association_target_label","target":target,"resolution":"unresolved",
                    "attributes":{"association":name}}));
            }
        }
    }
    links
}

#[cfg(test)]
mod tests {
    use super::*;
    fn observation() -> Value { serde_json::from_str(include_str!("../tests/fixtures/models.json")).unwrap() }
    fn capture() -> Value {
        json!({"root_id":"a".repeat(64),"files":[],"facts":[],"diagnostics":[],
            "coverage":[{"family":"source","status":"partial","scope":"fixture","reason":null}],
            "producer":{"effective_limits":{"max_facts":100,"max_links":100,"max_entries":100,"max_diagnostics":10}}})
    }
    #[test]
    fn separate_reflections_and_snapshot_identity_survive_validation() {
        let result = append(capture(), &observation()).unwrap();
        let fact = &result["facts"][0];
        assert_eq!(fact["kind"], "rails_model");
        assert!(fact["path"].is_null());
        assert_eq!(fact["attributes"]["model"]["associations"]["entries"].as_array().unwrap().len(), 2);
        assert_ne!(fact["links"][1]["attributes"], fact["links"][2]["attributes"]);
        let mut duplicated = observation();
        let second = duplicated["models"][0].clone();
        duplicated["models"].as_array_mut().unwrap().push(second);
        let facts = append(capture(), &duplicated).unwrap()["facts"].clone();
        assert_ne!(facts[0]["id"], facts[1]["id"]);
    }
    #[test]
    fn rejects_malformed_and_combined_limits_without_mutating_input() {
        let original = capture();
        for key in ["max_facts", "max_links", "max_entries"] {
            let mut limited = original.clone();
            limited["producer"]["effective_limits"][key] = json!(1);
            let mut observations = observation();
            let second = observations["models"][0].clone();
            observations["models"].as_array_mut().unwrap().push(second);
            assert!(append(limited, &observations).is_err(), "{key}");
        }
        let mut bad = observation();
        bad["models"][0]["columns"]["entries"][0]["default"] = json!({"kind":"opaque","value":"secret"});
        assert!(append(original.clone(), &bad).is_err());
        assert_eq!(original, capture());
        let mut result = append(original.clone(), &observation()).unwrap();
        result["facts"][0]["links"][0]["resolution"] = json!("resolved");
        assert!(schema::capture(&result).is_err());
    }
    #[test]
    fn reuses_owned_source_buffers_instead_of_cloning_the_capture() {
        let content = "x".repeat(4096);
        let mut captured = capture();
        captured["files"] = json!([{"path":"fixture.rb", "bytes":content.len(),
            "sha256":schema::digest(content.as_bytes()),"encoding":"UTF-8","content":content}]);
        let before = captured["files"][0]["content"].as_str().unwrap().as_ptr();
        let result = append(captured, &observation()).unwrap();
        assert_eq!(before, result["files"][0]["content"].as_str().unwrap().as_ptr());
    }
    #[test]
    fn unavailable_is_not_empty_success_and_unknown_versions_are_refused() {
        let mut obs = observation();
        obs["status"] = json!("unavailable");
        assert!(append(capture(), &obs).is_err());
        obs["models"] = json!([]);
        let result = append(capture(), &obs).unwrap();
        assert_eq!(result["coverage"][1]["status"], "unavailable");
        obs["version"] = json!(99);
        assert!(append(capture(), &obs).is_err());
    }
}
