use super::*;

fn observation() -> Value { serde_json::from_str(include_str!("../tests/fixtures/callbacks.json")).unwrap() }
fn context() -> Value {
    json!({"limits":{"max_facts":100,"max_links":100,"max_entries":100,"max_diagnostics":10},
        "facts":0,"links":0,"diagnostics":0,"fact_bytes":2})
}

#[test]
fn normalizes_registered_positions_and_keeps_hints_separate_from_source_proof() {
    let result = batch(&context(), &observation()).unwrap();
    let fact = &result["facts"][0];
    validate_fact(fact).unwrap();
    assert!(fact["path"].is_null() && fact["location"].is_null());
    let data = &fact["attributes"]["callbacks"];
    assert_eq!(data["save"]["entries"][0]["position"], 0);
    assert_eq!(data["save"]["entries"][1]["position"], 1);
    assert_eq!(data["save"]["entries"][0]["filter"]["source"]["path"], "records.rb");
    assert!(data["save"]["entries"][1]["filter"]["source"].is_null());
    assert_eq!(data["coherence"], "unknown");
    assert_eq!(fact["links"][0]["resolution"], "unresolved");
    assert!(result.get("files").is_none());
    let mut duplicate = observation();
    duplicate["models"].as_array_mut().unwrap().push(observation()["models"][0].clone());
    let facts = batch(&context(), &duplicate).unwrap()["facts"].clone();
    assert_ne!(facts[0]["id"], facts[1]["id"]);
    for path in ["/fixture/../outside.rb", "/elsewhere/records.rb", "records.rb"] {
        let mut unsafe_hint = observation();
        unsafe_hint["models"][0]["save"]["entries"][0]["filter"]["source"]["path"] = json!(path);
        let result = batch(&context(), &unsafe_hint).unwrap();
        assert!(result["facts"][0]["attributes"]["callbacks"]["save"]["entries"][0]["filter"]["source"].is_null());
    }
}

#[test]
fn rejects_forged_known_evidence_at_publication_and_reader_hook() {
    let fact = batch(&context(), &observation()).unwrap()["facts"][0].clone();
    for (pointer, value) in [
        ("/attributes/callbacks/version",json!(2)),
        ("/attributes/callbacks/coherence",json!("verified")),
        ("/attributes/callbacks/provenance",json!("execution")),
        ("/attributes/callbacks/save/entries/0/position",json!(1)),
        ("/attributes/callbacks/save/entries/0/filter/source/path",json!("../escape.rb")),
        ("/links/0/resolution",json!("resolved")), ("/id",json!("0".repeat(64))),
    ] {
        let mut bad = fact.clone(); *bad.pointer_mut(pointer).unwrap() = value;
        assert!(validate_fact(&bad).is_err(), "{pointer}");
    }
}

#[test]
fn strict_primitive_shape_and_unavailable_partial_empty_distinctions() {
    for (pointer, value) in [
        ("/version",json!(99)), ("/active_record_version",json!("8.2.0")),
        ("/models/0/save/entries/0/kind",json!("execute")),
        ("/models/0/save/entries/0/if",json!(null)),
        ("/models/0/save/entries/0/filter/source/line",json!(0)),
        ("/models/0/save/entries/1/unless/0",json!({"kind":"opaque","value":"secret"})),
    ] {
        let mut bad = observation(); *bad.pointer_mut(pointer).unwrap() = value;
        assert!(batch(&context(), &bad).is_err(), "{pointer}");
    }
    let mut partial = observation();
    partial["models"][0]["save"]["status"] = json!("partial");
    partial["models"][0]["save"]["entries"][0]["if"] = Value::Null;
    assert!(batch(&context(), &partial).is_ok());
    for status in ["observed", "unavailable"] {
        let mut empty = observation();
        empty["models"][0]["save"] = json!({"status":status,"entries":[]});
        let result = batch(&context(), &empty).unwrap();
        assert_eq!(result["facts"][0]["attributes"]["callbacks"]["save"]["status"], status);
    }
    let mut unavailable = observation(); unavailable["status"] = json!("unavailable");
    assert!(batch(&context(), &unavailable).is_err());
    unavailable["models"] = json!([]);
    assert_eq!(batch(&context(), &unavailable).unwrap()["coverage"][0]["status"], "unavailable");
}

#[test]
fn charges_existing_combined_counts_conditions_and_exact_encoded_bytes() {
    let original = context();
    for key in ["facts", "links", "diagnostics"] {
        let mut full = original.clone(); full[key] = json!(u64::MAX);
        assert!(batch(&full, &observation()).is_err(), "{key}");
    }
    let mut full = original.clone(); full["limits"]["max_entries"] = json!(3);
    assert!(batch(&full, &observation()).is_err()); // 2 callbacks + 2 conditions
    let facts = batch(&original, &observation()).unwrap()["facts"].clone();
    let bytes = schema::encoded_bytes(&facts[0], schema::MAX_FACTS_BYTES).unwrap() + 1;
    full = original.clone(); full["fact_bytes"] = json!(schema::MAX_FACTS_BYTES - bytes);
    assert!(batch(&full, &observation()).is_ok());
    full["fact_bytes"] = json!(schema::MAX_FACTS_BYTES - bytes + 1);
    assert!(batch(&full, &observation()).is_err());
    assert_eq!(original, context());
}

#[test]
fn shared_admission_preserves_counters_when_a_member_refuses() {
    let result = batch(&context(), &observation()).unwrap();
    let fact = &result["facts"][0];
    let mut limited = context(); limited["limits"]["max_entries"] = json!(4);
    let mut admission = schema::ObservationAdmission::new(&limited).unwrap();
    let before = admission.appended();
    assert!(admission.admit(fact, 5).is_err());
    assert_eq!(admission.appended(), before);
    admission.admit(fact, 4).unwrap();
    assert_eq!(admission.appended(), result["appended"]);
    assert_eq!(result["appended"]["fact_bytes"], schema::encoded_bytes(fact, schema::MAX_FACTS_BYTES).unwrap() + 1);
}

#[test]
fn publication_and_fresh_reader_preserve_generation_local_registered_evidence() {
    // This regression intentionally requires root's real schema/dispatch hooks.
    let temp = tempfile::tempdir().unwrap();
    let result = batch(&context(), &observation()).unwrap();
    let capture = json!({"schema_version":schema::VERSION,"root_id":"a".repeat(64),"files":[],
        "facts":result["facts"],"coverage":result["coverage"],"diagnostics":[],"producer":{}});
    let saved = crate::store::publish(temp.path(), &capture).unwrap();
    let reader = crate::store::Reader::open(temp.path(), Some(saved["generation"].as_str().unwrap())).unwrap();
    let id = capture["facts"][0]["id"].as_str().unwrap();
    assert_eq!(reader.fact(id).unwrap(), &capture["facts"][0]);
    assert_eq!(reader.source(id).unwrap_err().code, "source_unavailable");
    assert_eq!(reader.check().unwrap()["freshness"], "not_checked");
    let mut invalid = capture.clone();
    invalid["facts"][0]["attributes"]["callbacks"]["provenance"] = json!("executed");
    assert!(crate::store::publish(temp.path(), &invalid).is_err());
    let reopened = crate::store::Reader::open(temp.path(), None).unwrap();
    assert_eq!(reader.generation, reopened.generation);
}
