use super::*;
use serde_json::json;

fn call(data: Value) -> Value {
    json!({"relation":"calls","target":"héllo\"\\\n","resolution":"unresolved",
        "attributes":{"thistle_call":{"version":2,"data":data}}})
}

fn implicit() -> Value { json!(["implicit",null,false,false,[0,6,1,1],null]) }

fn fact(links: Value) -> Value {
    json!({"id":"a".repeat(64),"kind":"method","name":"Box#run","path":"a.rb",
        "location":null,"evidence":"static","attributes":{},"links":links,
        "unknown":{"null":null,"escaped":"\u{0000}\"\\\né雪","integer":u64::MAX}})
}

fn projected(link: &Value, version: u64) -> Value {
    serde_json::to_value(WireLink::new(link, version, "static").unwrap()).unwrap()
}

#[test]
fn exact_envelope_roundtrips_with_format_arithmetic_only() {
    let link = call(implicit());
    let wire = WireLink::new(&link, 3, "static").unwrap();
    let bytes = serde_json::to_vec(&wire).unwrap();
    assert_eq!(serde_json::to_vec(&link).unwrap().len() - bytes.len(), 103);
    let row: Value = serde_json::from_slice(&bytes).unwrap();
    assert_eq!(row, json!([0,link["target"],link["attributes"]["thistle_call"]["data"]]));
    let view = SemanticLinkView::from_wire(&row, 3, "static").unwrap();
    assert_eq!((view.relation(), view.target(), view.resolution()),
        ("calls", link["target"].as_str().unwrap(), "unresolved"));
    assert_eq!(view.call_metadata().unwrap().kind, "implicit");
    assert_eq!(view.materialize().unwrap(), link);
    assert_eq!(serde_json::to_vec(&view).unwrap(), serde_json::to_vec(&link).unwrap());
}

#[test]
fn all_receiver_values_survive_without_default_elision() {
    for kind in ["implicit", "self", "constant", "local", "instance_variable", "call", "literal", "expression"] {
        let named = matches!(kind, "constant" | "local" | "instance_variable");
        for omitted in [false, true] {
            if omitted && !named { continue; }
            for safe in [false, true] {
                if safe && kind == "implicit" { continue; }
                let name = if named && !omitted { json!("é".repeat(128)) } else { Value::Null };
                // Bounds against the source are validated by schema::facts,
                // not inferred from a surrounding declaration in the codec.
                let receiver = if kind == "implicit" { Value::Null } else { json!([8,10,2,2]) };
                let link = call(json!([kind,name,omitted,safe,[0,6,1,1],receiver]));
                let row = projected(&link, 3);
                assert_eq!(SemanticLinkView::from_wire(&row, 3, "static").unwrap().materialize().unwrap(), link);
            }
        }
    }
}

#[test]
fn extra_keys_at_each_envelope_level_preserve_the_complete_object() {
    for pointer in ["", "/attributes", "/attributes/thistle_call"] {
        let mut link = call(implicit());
        link.pointer_mut(pointer).unwrap().as_object_mut().unwrap()
            .insert("future".into(), json!({"kept":[null,false,"é雪\"\\",u64::MAX]}));
        assert_eq!(projected(&link, 3), link, "{pointer}");
        assert_eq!(serde_json::to_vec(&WireLink::new(&link, 3, "static").unwrap()).unwrap(),
            serde_json::to_vec(&link).unwrap());
    }
    let objects = [
        json!({"relation":"inherits","target":"Box","resolution":"unresolved"}),
        json!({"relation":"calls","target":"x","resolution":"unresolved","attributes":null}),
        json!({"relation":"calls","target":"x","resolution":"unresolved"}),
        json!({"relation":"calls","target":"x","resolution":"unresolved",
            "attributes":{"thistle_call":{"version":99,"opaque":[null,false,1]}}}),
        json!({"relation":"calls","target":"x","resolution":"resolved"}),
    ];
    for link in objects { assert_eq!(projected(&link, 3), link); }
}

#[test]
fn extra_keys_do_not_hide_recognized_malformed_data() {
    for pointer in ["", "/attributes", "/attributes/thistle_call"] {
        let mut link = call(implicit());
        link.pointer_mut(pointer).unwrap().as_object_mut().unwrap().insert("future".into(), json!(true));
        link["attributes"]["thistle_call"]["data"][2] = json!(0);
        assert!(WireLink::new(&link, 3, "static").is_err());
    }
}

#[test]
fn malformed_rows_and_semantic_row_inputs_refuse() {
    let valid = json!([0,"target",implicit()]);
    let mut rows = vec![Value::Null, json!(false), json!([]), json!([0,"target"]),
        json!([0,"target",implicit(),null]), json!([0,"target",valid]),
        json!([0,"target",["implicit",null,false,false,[0,6,1,1],null,0]])];
    for tag in [json!(false),json!(0.0),json!(-1),json!("0"),json!(1),Value::Null] {
        rows.push(json!([tag,"target",implicit()]));
    }
    for target in [json!(""),json!("x".repeat(4097)),json!(0),Value::Null,json!([])] {
        rows.push(json!([0,target,implicit()]));
    }
    for (slot, value) in [(0,json!("future")),(1,json!(false)),(2,json!(0)),(3,json!(1)),
        (4,json!([0,6,1])),(4,json!([false,6,1,1])),(4,json!([-1,6,1,1])),
        (4,json!([0.0,6,1,1])),(5,json!([0,1,1,1])),(3,json!(true))] {
        let mut data = implicit(); data[slot] = value; rows.push(json!([0,"target",data]));
    }
    rows.push(json!([0,"target",["local","x".repeat(257),false,false,[0,6,1,1],[0,1,1,1]]]));
    rows.push(json!([0,"target",["local","x",false,false,[0,6,1,1],null]]));
    for row in rows { assert!(SemanticLinkView::from_wire(&row, 3, "static").is_err(), "{row}"); }
    assert!(WireLink::new(&valid, 3, "static").is_err());
    assert!(SemanticLinkView::from_semantic(&valid, 3, "static").is_err());
    let capture_fact = fact(json!([valid]));
    assert!(serde_json::to_vec(&WireFact::new(&capture_fact, 3).unwrap()).is_err());
}

#[test]
fn explicit_context_preserves_schema_one_opaque_exact_v2_lookalike() {
    assert_eq!(schema::VERSION, 2); // Executable foundation does not enable schema3 stores.
    assert!(schema::snapshot_version(&json!(3)).is_err());
    assert_eq!(schema::capture_version(&json!({})).unwrap(), 1);
    let link = call(implicit()); // A perfectly valid compact extension remains opaque in schema 1.
    let row = projected(&link, 3);
    for version in [1,2] {
        let view = SemanticLinkView::from_wire(&link, version, "static").unwrap();
        assert_eq!(view.call_metadata().is_some(), version == 2);
        assert_eq!(view.materialize().unwrap(), link);
        assert_eq!(serde_json::to_vec(&WireLink::new(&link, version, "static").unwrap()).unwrap(),
            serde_json::to_vec(&link).unwrap());
        assert!(SemanticLinkView::from_wire(&row, version, "static").is_err());
    }
    // Opaque schema-1 v2 metadata does not acquire new static provenance rules.
    assert!(SemanticLinkView::from_semantic(&link, 1, "runtime").unwrap().call_metadata().is_none());
    assert!(SemanticLinkView::from_wire(&row, 3, "runtime").is_err());
    assert!(WireLink::new(&link, 3, "runtime").is_err());
    assert!(WireLink::new(&link, 4, "static").is_err());
    assert!(WireLink::new(&link, 3, "unknown").is_err());
    let mut extra = link.clone(); extra["attributes"]["thistle_call"]["future"] = json!(true);
    assert!(WireLink::new(&extra, 2, "static").is_err()); // Existing schema-2 strictness.
    assert_eq!(projected(&extra, 3), extra);
}

#[test]
fn strict_v1_remains_object_shaped_and_unknown_versions_opaque() {
    let mut link = call(implicit());
    link["attributes"]["thistle_call"] = json!({"version":1,
        "receiver":{"kind":"implicit","name":null,"omitted_limit":false},
        "safe_navigation":false,"call_location":{"start_byte":0,"end_byte":6,"start_line":1,"end_line":1},
        "receiver_location":null});
    for version in [1,2,3] {
        assert!(SemanticLinkView::from_semantic(&link, version, "static").unwrap().call_metadata().is_some());
        assert_eq!(projected(&link, version), link);
    }
    link["attributes"]["thistle_call"] = json!({"version":99,"data":{"opaque":[0,"target",implicit()]}});
    for version in [1,2,3] {
        assert!(SemanticLinkView::from_wire(&link, version, "static").unwrap().call_metadata().is_none());
        assert_eq!(projected(&link, version), link);
    }
}

#[test]
fn actual_serializer_count_agrees_for_mixed_facts_escapes_unicode_and_exact_boundary() {
    let link = call(implicit());
    let mut fallback = link.clone(); fallback["future"] = json!([null,"\u{0000}\"\\é雪",u64::MAX]);
    let facts = [fact(json!([])),fact(json!([link,fallback,
        {"relation":"inherits","target":"B雪","resolution":"unresolved"}]))];
    let refs: Vec<_> = facts.iter().collect();
    for version in [1,2,3] {
        let projected = WireFacts::new(&refs, version);
        let bytes = serde_json::to_vec(&projected).unwrap();
        assert_eq!(schema::encoded_bytes(&projected, bytes.len()).unwrap(), bytes.len());
        assert!(schema::encoded_bytes(&projected, bytes.len() - 1).is_err());
        let stored: Vec<Value> = serde_json::from_slice(&bytes).unwrap();
        for (original, stored) in facts.iter().zip(&stored) {
            assert_eq!(materialize_fact(stored, version).unwrap(), *original);
            assert_eq!(materialize_links(stored, version).unwrap(), original["links"]);
        }
        if version != 3 { assert_eq!(bytes, serde_json::to_vec(&refs).unwrap()); }
    }
    let empty: [&Value; 0] = [];
    assert_eq!(schema::encoded_bytes(&WireFacts::new(&empty, 3), 2).unwrap(), 2);
    assert!(schema::encoded_bytes(&WireFacts::new(&empty, 3), 1).is_err());
    assert!(serde_json::to_vec(&WireFacts::new(&empty, 4)).is_err());
}

#[test]
fn requested_fact_expansion_leaves_rows_retained_and_unrelated_facts_unvisited() {
    let link = call(implicit());
    let semantic = fact(json!([link]));
    let stored = serde_json::to_value(WireFact::new(&semantic, 3).unwrap()).unwrap();
    let retained = [stored, json!({"evidence":"static","links":[[999]]})];
    assert_eq!(materialize_fact(&retained[0], 3).unwrap(), semantic);
    assert_eq!(materialize_links(&retained[0], 3).unwrap(), semantic["links"]);
    assert!(retained[0]["links"][0].is_array());
    assert!(materialize_fact(&retained[1], 3).is_err());
}
