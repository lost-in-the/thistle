//! Loaded Rails model observations. Ruby supplies primitives, never engine facts.
use crate::{error::{CoreError, Result}, schema};
use serde_json::{json, Value};

const SCOPE: &str = "Already loaded ActiveRecord::Base descendants in the supplied application's process; no eager load, reload, target resolution or record execution";

/// Normalize and admit only new model observations. Existing source/facts never
/// cross this request. The facade supplies current admission counters; native
/// publication independently validates the complete actual capture before I/O.
pub fn batch(context: &Value, observation: &Value) -> Result<Value> {
    let mut admission = schema::ObservationAdmission::new(context)?;
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
    if observation["status"] == "observed" && !schema::supported_active_record(&observation["active_record_version"]) {
        return Err(CoreError::input("Unsupported Active Record observation version"));
    }
    admission.ensure_facts(models.len())?;
    // Refuse an oversized observation before building facts.
    schema::encoded_bytes(observation, schema::MAX_FACTS_BYTES)
        .map_err(|_| CoreError::limit("Model observation exceeds 64 MiB"))?;
    let mut facts = Vec::with_capacity(models.len());
    for (ordinal, observed) in models.iter().enumerate() {
        schema::model_observation(observed)?;
        let entries = observed["primary_key"].as_array().map_or(0, Vec::len)
            + observed["columns"]["entries"].as_array().unwrap().len()
            + observed["associations"]["entries"].as_array().unwrap().len();
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
        admission.admit(&fact, entries)?;
        facts.push(fact);
    }
    schema::facts(&facts, &[], schema::VERSION)?;
    let mut coverage = Vec::new();
    coverage.push(json!({"family":"rails_models","status":if observation["status"] == "observed" {"partial"} else {"unavailable"},
        "scope":SCOPE,"reason":"Per-model family status distinguishes observed empty from unavailable. Database column defaults only; Ruby attribute defaults and source/runtime coherence unknown. Names are labels, not runtime dispatch."}));
    coverage.push(json!({"family":"rails_model_effects","status":"unavailable",
        "scope":"Callbacks, scopes, predicates, custom attribute defaults, indexes, concerns and all-adapter behavior",
        "reason":"Not executed or inferred by this observer"}));
    Ok(batch_result(facts, coverage, admission.appended(), &observation["active_record_version"]))
}

fn batch_result(facts: Vec<Value>, coverage: Vec<Value>, appended: Value, active_record_version: &Value) -> Value {
    let mut result = json!({"coverage":coverage, "appended":appended,
        "model_observer":{"version":1,"active_record_version":active_record_version,"scope":SCOPE}});
    // json! interpolation serializes by reference, rebuilding an owned Value tree.
    result["facts"] = Value::Array(facts);
    result
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
    fn append(mut capture: Value, observation: &Value) -> Result<Value> {
        schema::capture(&capture)?;
        let context = json!({"limits":capture["producer"]["effective_limits"],
            "facts":capture["facts"].as_array().unwrap().len(),
            "links":capture["facts"].as_array().unwrap().iter().map(|f| f["links"].as_array().unwrap().len()).sum::<usize>(),
            "diagnostics":capture["diagnostics"].as_array().unwrap().len(),
            "fact_bytes":schema::canonical(&capture["facts"])?.len()});
        let mut added = batch(&context, observation)?;
        capture["facts"].as_array_mut().unwrap().append(added["facts"].as_array_mut().unwrap());
        capture["coverage"].as_array_mut().unwrap().append(added["coverage"].as_array_mut().unwrap());
        capture["producer"]["model_observer"] = added["model_observer"].take();
        schema::capture(&capture)?;
        Ok(capture)
    }
    fn observation() -> Value { serde_json::from_str(include_str!("../tests/fixtures/models.json")).unwrap() }
    fn capture() -> Value {
        json!({"root_id":"a".repeat(64),"files":[],"facts":[],"diagnostics":[],
            "coverage":[{"family":"source","status":"partial","scope":"fixture","reason":null}],
            "producer":{"effective_limits":{"max_facts":100,"max_links":100,"max_entries":100,"max_diagnostics":10}}})
    }
    fn context(version: Option<u64>) -> Value {
        let mut context = json!({"limits":capture()["producer"]["effective_limits"],
            "facts":0,"links":0,"diagnostics":0,"fact_bytes":2});
        if let Some(version) = version { context["schema_version"] = json!(version); }
        context
    }
    fn expected_batch() -> Value {
        // Fixed complete answer for models.json, including conservative byte charges.
        json!({
            "facts":[{
                "id":"4b775b475bfee545bbc9e1fee032d842d8f28cb3be73ae9879c2f312a41d6573",
                "kind":"rails_model","name":"Order","evidence":"runtime","path":null,"location":null,
                "attributes":{"model":{
                    "version":1,"ordinal":0,"active_record_version":"8.1.4","coherence":"unknown","source":"unavailable",
                    "name":"Order","base_class":"Order","superclass":"ApplicationRecord","abstract":false,
                    "table":"orders","primary_key":["id"],"inheritance_column":"type",
                    "columns":{"status":"observed","entries":[{
                        "name":"state","type":"string","sql_type":"varchar","null":false,
                        "default":{"kind":"literal","value":"new"}}]},
                    "associations":{"status":"observed","entries":[{
                        "name":"items","macro":"has_many","target":"Item","polymorphic":false,
                        "through":null,"scope":"none","options":{},"omitted_options":0}, {
                        "name":"payments","macro":"has_many","target":"Payment","polymorphic":false,
                        "through":null,"scope":"none","options":{},"omitted_options":0}]}
                }},
                "links":[{"relation":"model_base_label","target":"Order","resolution":"unresolved"},
                    {"relation":"association_target_label","target":"Item","resolution":"unresolved","attributes":{"association":"items"}},
                    {"relation":"association_target_label","target":"Payment","resolution":"unresolved","attributes":{"association":"payments"}}]
            }],
            "coverage":[{
                "family":"rails_models","status":"partial",
                "scope":"Already loaded ActiveRecord::Base descendants in the supplied application's process; no eager load, reload, target resolution or record execution",
                "reason":"Per-model family status distinguishes observed empty from unavailable. Database column defaults only; Ruby attribute defaults and source/runtime coherence unknown. Names are labels, not runtime dispatch."
            }, {
                "family":"rails_model_effects","status":"unavailable",
                "scope":"Callbacks, scopes, predicates, custom attribute defaults, indexes, concerns and all-adapter behavior",
                "reason":"Not executed or inferred by this observer"
            }],
            "appended":{"facts":1,"links":3,"entries":4,"fact_bytes":1245},
            "model_observer":{"version":1,"active_record_version":"8.1.4",
                "scope":"Already loaded ActiveRecord::Base descendants in the supplied application's process; no eager load, reload, target resolution or record execution"}
        })
    }
    #[test]
    fn complete_batch_answers_include_empty_unavailable_and_all_context_versions() {
        for version in [None, Some(1), Some(2), Some(3)] {
            let context = context(version);
            let original_context = context.clone();
            let mut observation = observation();
            for status in ["populated", "empty", "unavailable"] {
                let mut expected = expected_batch();
                if status != "populated" {
                    observation["models"] = json!([]);
                    expected["facts"] = json!([]);
                    expected["appended"] = json!({"facts":0,"links":0,"entries":0,"fact_bytes":0});
                }
                if status == "unavailable" {
                    observation["status"] = json!("unavailable");
                    observation["active_record_version"] = Value::Null;
                    expected["coverage"][0]["status"] = json!("unavailable");
                    expected["model_observer"]["active_record_version"] = Value::Null;
                }
                let original_observation = observation.clone();
                let result = batch(&context, &observation).unwrap();
                assert_eq!(schema::canonical(&result).unwrap(), schema::canonical(&expected).unwrap(), "{version:?}/{status}");
                assert_eq!(context, original_context);
                assert_eq!(observation, original_observation);
            }
        }
    }
    #[test]
    fn production_result_assembly_transfers_completed_fact_allocations() {
        fn allocations(facts: &[Value]) -> [usize; 4] {
            let model = &facts[0]["attributes"]["model"];
            [facts.as_ptr() as usize,
                model["columns"]["entries"].as_array().unwrap().as_ptr() as usize,
                model["columns"]["entries"][0]["default"]["value"].as_str().unwrap().as_ptr() as usize,
                model["associations"]["entries"][1]["target"].as_str().unwrap().as_ptr() as usize]
        }
        let mut expected = expected_batch();
        let Value::Array(facts) = expected["facts"].take() else { panic!("fixture facts") };
        let before = allocations(&facts);
        // Keep both trees alive: compare addresses only, never dereference saved pointers.
        let old = json!({"facts":facts,"coverage":expected["coverage"],
            "appended":expected["appended"],"model_observer":expected["model_observer"]});
        for (original, rebuilt) in before.into_iter().zip(allocations(old["facts"].as_array().unwrap())) {
            assert_ne!(original, rebuilt, "old json! assembly must rebuild each checked allocation");
        }
        let Value::Array(coverage) = expected["coverage"].take() else { panic!("fixture coverage") };
        // batch returns this production helper's Value directly after validation.
        let result = batch_result(facts, coverage, expected["appended"].take(), &json!("8.1.4"));
        assert_eq!(allocations(result["facts"].as_array().unwrap()), before);
        assert_eq!(result, old);
    }
    #[test]
    fn second_model_refusal_returns_only_error_and_preserves_borrowed_inputs() {
        for version in [None, Some(1), Some(2), Some(3)] {
            for malformed in [false, true] {
                let mut context = context(version);
                context["limits"]["max_links"] = json!(5);
                let mut observation = observation();
                // The first model alone is valid and fits. The second fails later.
                assert!(batch(&context, &observation).is_ok());
                let mut second = observation["models"][0].clone();
                if malformed { second["columns"]["entries"][0]["default"] = json!({"kind":"opaque","value":"invalid"}); }
                observation["models"].as_array_mut().unwrap().push(second);
                let original_context = context.clone();
                let original_observation = observation.clone();
                let error = batch(&context, &observation).unwrap_err();
                assert_eq!((error.code, error.message.as_str()), if malformed {
                    ("invalid_input", "Invalid model object fields")
                } else { ("limit_exceeded", "Combined capture exceeds max_links") });
                assert_eq!(context, original_context);
                assert_eq!(observation, original_observation);
            }
        }
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
    fn admission_context_refuses_overflow_and_impossible_used_budgets() {
        let valid = json!({"limits":capture()["producer"]["effective_limits"],
            "facts":0,"links":0,"diagnostics":0,"fact_bytes":2});
        let result = batch(&valid, &observation()).unwrap();
        assert!(result.get("files").is_none());
        for (key, value, code) in [("facts",json!(u64::MAX),"limit_exceeded"), ("links",json!(101),"limit_exceeded"),
            ("diagnostics",json!(11),"limit_exceeded"), ("fact_bytes",json!(schema::MAX_FACTS_BYTES),"limit_exceeded"),
            ("facts",json!(-1),"limit_exceeded"), ("fact_bytes",json!(1),"invalid_input")] {
            let mut context = valid.clone(); context[key] = value;
            assert_eq!(batch(&context, &observation()).unwrap_err().code, code, "{key}");
        }
        let mut extra = valid.clone(); extra["files"] = json!([]);
        assert_eq!(batch(&extra, &observation()).unwrap_err().code, "invalid_input");
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
    #[test]
    fn exact_cohorts_survive_admission_and_publication_without_relabelling() {
        // Synthetic primitive admission tests, not genuine framework evidence.
        for version in ["7.1.6", "8.1.4"] {
            let mut obs = observation(); obs["active_record_version"] = json!(version);
            let result = append(capture(), &obs).unwrap();
            assert_eq!(result["producer"]["model_observer"]["active_record_version"], version);
            assert_eq!(result["facts"][0]["attributes"]["model"]["active_record_version"], version);
            for unsupported in ["7.1.5", "7.2.4", "8.1.5", "7.1.6-custom"] {
                obs["active_record_version"] = json!(unsupported);
                assert!(append(capture(), &obs).is_err());
                let mut forged = result.clone();
                forged["facts"][0]["attributes"]["model"]["active_record_version"] = json!(unsupported);
                assert!(schema::capture(&forged).is_err());
            }
        }
    }
    #[test]
    fn counted_json_preserves_escaped_bytes_and_combined_admission_boundary() {
        let escaped = json!({"text":"quote\" slash\\ newline\n 🍎", "values":[null, true, -12, 1.5]});
        let length = schema::canonical(&escaped).unwrap().len();
        assert_eq!(schema::encoded_bytes(&escaped, length).unwrap(), length);
        assert!(schema::encoded_bytes(&escaped, length - 1).is_err());
        assert!(schema::encoded_bytes(&json!(null), 0).is_err());
        let mut context = json!({"limits":capture()["producer"]["effective_limits"],
            "facts":1,"links":0,"diagnostics":0,"fact_bytes":2});
        let observations = observation();
        let result = batch(&context, &observations).unwrap();
        let added = result["facts"].as_array().unwrap().iter()
            .map(|fact| schema::canonical(fact).unwrap().len() + 1).sum::<usize>();
        context["fact_bytes"] = json!(schema::MAX_FACTS_BYTES - added);
        assert_eq!(batch(&context, &observations).unwrap(), result);
        context["fact_bytes"] = json!(schema::MAX_FACTS_BYTES - added + 1);
        assert_eq!(batch(&context, &observations).unwrap_err().code, "limit_exceeded");
    }
}
