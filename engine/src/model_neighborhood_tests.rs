use super::*;

// Native tests AUTHORED UNRUN in the source-only assignment.
fn fixture() -> (tempfile::TempDir, Reader, String, Value) {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("sites.rb"), "class User; end\nclass User; end\nclass Caller; def one; ::Order.find; end; def two; ::Order.count; end; end\n").unwrap();
    let mut capture = {
        let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
        crate::capture::capture(root.path(), &json!({})).unwrap()
    };
    let mut observation: Value = serde_json::from_str(include_str!("../tests/fixtures/models.json")).unwrap();
    let model = &mut observation["models"][0];
    let association = model["associations"]["entries"][0].clone();
    model["associations"]["entries"] = json!([]);
    for ordinal in 0..10 {
        let mut entry = association.clone(); entry["name"] = json!(format!("related_{ordinal}"));
        entry["target"] = json!(if ordinal == 9 { "NotLoadedGhost" } else { "User" });
        model["associations"]["entries"].as_array_mut().unwrap().push(entry);
    }
    let mut polymorphic = association;
    polymorphic["name"] = json!("attachable"); polymorphic["target"] = Value::Null; polymorphic["polymorphic"] = json!(true);
    model["associations"]["entries"].as_array_mut().unwrap().push(polymorphic);
    let column = model["columns"]["entries"][0].clone();
    model["columns"]["entries"] = json!([]);
    for (ordinal, default) in [json!({"kind":"literal","value":false}), json!({"kind":"literal","value":0}),
        json!({"kind":"literal","value":""}), json!({"kind":"literal","value":null}), json!({"kind":"expression"}), json!({"kind":"opaque"})].into_iter().enumerate() {
        let mut entry = column.clone(); entry["name"] = json!(format!("column_{ordinal}")); entry["default"] = default;
        model["columns"]["entries"].as_array_mut().unwrap().push(entry);
    }
    let mut batch = crate::model::batch(&json!({"limits":{"max_facts":100000,"max_links":100000,"max_entries":100000,"max_diagnostics":100},"facts":0,"links":0,"diagnostics":0,"fact_bytes":2}), &observation).unwrap();
    let id = batch["facts"][0]["id"].as_str().unwrap().to_owned();
    capture["facts"].as_array_mut().unwrap().append(batch["facts"].as_array_mut().unwrap());
    let store = tempfile::tempdir().unwrap();
    crate::store::publish(store.path(), &capture).unwrap();
    let reader = Reader::open(store.path(), None).unwrap();
    (store, reader, id, capture)
}
fn page(reader: &Reader, parameters: &Value) -> Value { select(reader, &Query::parse(parameters).unwrap()).unwrap() }

#[test]
fn schema_defaults_one_hop_ambiguity_unknown_targets_and_finite_filter_pages() {
    let (_store, reader, id, _) = fixture();
    let columns = page(&reader, &json!({"id":id,"family":"columns"}));
    let defaults: Vec<Value> = columns["items"].as_array().unwrap().iter().map(|row| row["column"]["default"].clone()).collect();
    assert_eq!(defaults, vec![json!({"kind":"literal","value":false}),json!({"kind":"literal","value":0}),json!({"kind":"literal","value":""}),json!({"kind":"literal","value":null}),json!({"kind":"expression"}),json!({"kind":"opaque"})]);
    assert_eq!(columns["coverage"]["default_presence"], "not_recorded");
    let mut cursor = Value::Null; let mut rows = Vec::new(); let mut finished = false;
    for _ in 0..20 {
        let answer = page(&reader, &json!({"id":id,"type":"association","limit":2,"cursor":cursor}));
        assert!(wire_bytes(&answer, 32768).unwrap() <= 32768);
        rows.extend(answer["items"].as_array().unwrap().iter().cloned());
        if answer["coverage"]["page_complete"] == true { finished = true; break; }
        assert_ne!(answer["next_cursor"], cursor); cursor = answer["next_cursor"].clone();
    }
    assert!(finished); assert_eq!(rows.len(), 11);
    assert_eq!(rows[0]["candidate_matches"], 2); // two captured declaration sites, no invented runtime binding
    assert_eq!(rows[9]["target_status"], "missing_or_unloaded");
    assert_eq!(rows[10]["target_status"], "unknown_target");
    assert!(rows.iter().all(|r|r["binding"]=="unknown" && r.get("recorded").is_none()));
    let candidates = page(&reader, &json!({"id":id,"family":"candidates","candidate":"a:0","limit":1}));
    assert_eq!(candidates["coverage"]["known_remaining"],1);
    assert_ne!(candidates["next_cursor"], Value::Null);
    assert_eq!(page(&reader,&json!({"id":id,"family":"candidates","candidate":"a:0","cursor":candidates["next_cursor"]}))["items"].as_array().unwrap().len(),1);
}

#[test]
fn byte_cut_continues_from_dropped_row_input_not_its_post_row_cursor() {
    let (_store, reader, id, _) = fixture();
    let full = page(&reader,&json!({"id":id,"type":"association","limit":2}));
    let first = page(&reader,&json!({"id":id,"type":"association","limit":1}));
    let budget = wire_bytes(&first,65536).unwrap() + 64;
    assert!(wire_bytes(&full,65536).unwrap() > budget);
    let cut = page(&reader,&json!({"id":id,"type":"association","limit":2,"max_bytes":budget}));
    assert_eq!(cut["items"],first["items"]);
    let next = page(&reader,&json!({"id":id,"type":"association","limit":1,"cursor":cut["next_cursor"]}));
    assert_eq!(next["items"][0],full["items"][1]);
    assert_eq!(select(&reader,&Query::parse(&json!({"id":id,"max_bytes":1})).unwrap()).unwrap_err().code,"limit_exceeded");
    let full = page(&reader,&json!({"id":id,"direction":"incoming","limit":2}));
    assert_eq!(full["items"].as_array().unwrap().len(),2);
    let first = page(&reader,&json!({"id":id,"direction":"incoming","limit":1}));
    let budget = wire_bytes(&first,65536).unwrap() + 64;
    assert!(wire_bytes(&full,65536).unwrap() > budget);
    let cut = page(&reader,&json!({"id":id,"direction":"incoming","limit":2,"max_bytes":budget}));
    assert_eq!(cut["items"], first["items"]);
    let next = page(&reader,&json!({"id":id,"direction":"incoming","limit":1,"cursor":cut["next_cursor"]}));
    assert_eq!(next["items"][0],full["items"][1]);
}

#[test]
fn one_admitted_incoming_row_then_shared_zero_progress_is_not_completion() {
    let (_store, reader, id, _) = fixture();
    let parameters = json!({"id":id,"direction":"incoming","limit":1});
    let component = references::select(&reader,&references::Query::parse(&parameters).unwrap()).unwrap();
    assert_eq!(component["relationships"].as_array().unwrap().len(),1);
    let visits = component["coverage"]["facts_scanned"].as_u64().unwrap() as usize;
    let mut work = RequestWork::default(); assert!(work.facts(20000-visits-4));
    let parameters = json!({"id":id,"direction":"incoming","limit":2});
    let answer = select_with_work(&reader,&Query::parse(&parameters).unwrap(),&mut work).unwrap();
    assert_eq!(answer["items"].as_array().unwrap().len(),1);
    assert_eq!(answer["coverage"]["page_complete"],false);
    assert_eq!(answer["coverage"]["reference_scan"]["scan_complete"],false);
    assert_ne!(answer["next_cursor"],Value::Null);
    let resumed = page(&reader,&json!({"id":id,"direction":"incoming","limit":1,"cursor":answer["next_cursor"]}));
    let key = |row: &Value| json!([row["recorded"]["origin"]["id"],row["recorded"]["link_ordinal"]]);
    assert_ne!(key(&resumed["items"][0]),key(&answer["items"][0]));
    let mut work = RequestWork::default(); assert!(work.facts(19998));
    assert_eq!(select_with_work(&reader,&Query::parse(&parameters).unwrap(),&mut work).unwrap_err().code,"limit_exceeded");
}

#[test]
fn wrong_kind_generation_filter_candidate_scope_and_limits_refuse() {
    let (_store, reader, id, _) = fixture();
    for parameters in [json!({"id":id,"limit":0}),json!({"id":id,"limit":17}),json!({"id":id,"max_bytes":65537}),
        json!({"id":id,"type":"sql_fk"}),json!({"id":id,"family":"candidates","candidate":"a:00"})] {
        assert_eq!(Query::parse(&parameters).err().unwrap().code,"invalid_input");
    }
    let first = page(&reader,&json!({"id":id,"limit":1}));
    assert!(select(&reader,&Query::parse(&json!({"id":id,"direction":"incoming","cursor":first["next_cursor"]})).unwrap()).is_err());
    let wrong = reader.facts.iter().find(|f|f["kind"]=="class").unwrap()["id"].as_str().unwrap();
    assert_eq!(select(&reader,&Query::parse(&json!({"id":wrong})).unwrap()).unwrap_err().code,"invalid_input");
}
