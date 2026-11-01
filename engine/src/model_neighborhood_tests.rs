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
        entry["target"] = json!(if ordinal == 9 { "NotLoadedGhost" } else if ordinal == 0 { "::User" } else { "User" });
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
    assert!(columns["items"][0]["column"].get("default_recorded").is_none());
    assert!(columns["items"][0]["column"].get("default_presence").is_none());
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
    assert_eq!(rows[0]["target_label"], "::User");
    assert_eq!(rows[0]["origin_id"], id);
    assert!(rows[0].get("origin").is_none());
    assert_eq!(rows[9]["target_status"], "missing_or_unloaded");
    assert_eq!(rows[10]["target_status"], "unknown_target");
    assert!(rows.iter().all(|r|r["binding"]=="unknown" && r.get("recorded").is_none()));
    let candidates = page(&reader, &json!({"id":id,"family":"candidates","candidate":"a:0","limit":1}));
    assert_eq!(candidates["candidate_context"]["name"], "related_0");
    assert_eq!(candidates["candidate_context"]["target_label"], "::User");
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
    let parameters = json!({"id":id,"direction":"incoming","limit":2});
    for allowance in [3,4] {
        let mut work = RequestWork::default(); assert!(work.facts(20000-visits-allowance));
        let answer = select_with_work(&reader,&Query::parse(&parameters).unwrap(),&mut work).unwrap();
        assert_eq!(answer["items"].as_array().unwrap().len(),1,"allowance {allowance}");
        assert_eq!(answer["coverage"]["page_complete"],false);
        assert_eq!(answer["coverage"]["last_reference_step"]["row_retained"],false);
        assert_ne!(answer["next_cursor"],Value::Null);
        let resumed = page(&reader,&json!({"id":id,"direction":"incoming","limit":1,"cursor":answer["next_cursor"]}));
        let key = |row: &Value| json!([row["origin"]["id"],row["recorded"]["link_ordinal"]]);
        assert_ne!(key(&resumed["items"][0]),key(&answer["items"][0]));
    }
    let mut work = RequestWork::default(); assert!(work.facts(19998));
    assert_eq!(select_with_work(&reader,&Query::parse(&parameters).unwrap(),&mut work).unwrap_err().code,"limit_exceeded");
}

#[test]
fn metadata_exhaustion_keeps_prefix_and_only_opens_existing_final_reserve() {
    let (_store, mut reader, id, _) = fixture();
    // Two equal raw links each charge >4 MiB before their oversized detail is
    // omitted from the small public row. One fits the existing 5-MiB component
    // allowance; two cannot. This forces exhaustion after an admitted row
    // without guessing how much the repeated identity/envelope charges cost.
    let link=json!({"relation":"references","target":"Order","resolution":"unresolved",
        "attributes":{"budget_fixture":"x".repeat(2*1024*1024)}});
    for fact in &mut reader.facts { fact["links"]=json!([]); }
    reader.facts[0]["links"]=json!([link,link]);
    let parameters = json!({"id":id,"direction":"incoming","limit":3});
    let first=page(&reader,&json!({"id":id,"direction":"incoming","limit":1}));
    let second=page(&reader,&json!({"id":id,"direction":"incoming","limit":1,"cursor":first["next_cursor"]}));
    assert_eq!(first["items"].as_array().unwrap().len(),1);
    assert_eq!(second["items"].as_array().unwrap().len(),1);
    assert_eq!(first["items"][0]["recorded"]["link_ordinal"],0);
    assert_eq!(second["items"][0]["recorded"]["link_ordinal"],1);
    assert_eq!(first["items"][0]["recorded"]["detail_omitted"],true);
    let mut work = RequestWork::default();
    let answer=select_with_work(&reader,&Query::parse(&parameters).unwrap(),&mut work).unwrap();
    assert_eq!(answer["items"],first["items"]);
    assert_eq!(answer["coverage"]["page_complete"],false);
    assert_eq!(answer["coverage"]["last_reference_step"]["status"],"component_refused");
    assert_eq!(answer["coverage"]["last_reference_step"]["row_retained"],false);
    assert_eq!(answer["next_cursor"],first["next_cursor"]);
    let suffix=page(&reader,&json!({"id":id,"direction":"incoming","limit":3,"cursor":answer["next_cursor"]}));
    assert_eq!(suffix["items"],second["items"]);
    assert_eq!(suffix["coverage"]["page_complete"],true);
    assert!(work.metadata(&"x".repeat(3*1024*1024),1).is_err()); // final total still <=8 MiB
    let mut work=RequestWork::default();
    work.metadata(&"x".repeat(2*1024*1024),1).unwrap();
    assert_eq!(select_with_work(&reader,&Query::parse(&parameters).unwrap(),&mut work).unwrap_err().code,"limit_exceeded");
}

#[test]
fn sparse_interleaved_incoming_filter_and_wire_cut_exhaust_without_row_loss() {
    let (_original, _reader, id, mut capture) = fixture();
    for i in 0..403 {
        capture["facts"].as_array_mut().unwrap().push(json!({"id":format!("{:064x}",10000+i),"kind":"class","name":format!("Site{i}"),
            "evidence":"static","path":null,"location":null,"attributes":{},"links":[{"relation":if i%100==0 {"association_target_label"} else {"references"},
                "target":"Order","resolution":"unresolved"}]}));
    }
    let store=tempfile::tempdir().unwrap();crate::store::publish(store.path(),&capture).unwrap();
    let reader=Reader::open(store.path(),None).unwrap();
    let full=page(&reader,&json!({"id":id,"direction":"incoming","type":"association","limit":16}));
    assert_eq!(full["items"].as_array().unwrap().len(),5);
    assert!(full["cost"]["completed_reference_steps"].as_u64().unwrap()<=6);
    assert!(full["cost"]["completed_step_work"]["links_scanned"].as_u64().unwrap()>400);
    let first=page(&reader,&json!({"id":id,"direction":"incoming","type":"association","limit":1}));
    let budget=wire_bytes(&first,65536).unwrap()+64;
    let mut cursor=Value::Null;let mut rows=Vec::new();let mut done=false;
    for _ in 0..12 {
        let answer=page(&reader,&json!({"id":id,"direction":"incoming","type":"association","limit":2,"max_bytes":budget,"cursor":cursor}));
        rows.extend(answer["items"].as_array().unwrap().iter().cloned());
        if answer["coverage"]["page_complete"]==true {done=true;break;}
        assert_ne!(answer["next_cursor"],cursor);
        if answer["coverage"]["last_reference_step"]["scan_complete"]==true {
            assert_eq!(answer["coverage"]["last_reference_step"]["row_retained"],false);
        }
        cursor=answer["next_cursor"].clone();
    }
    assert!(done);assert_eq!(json!(rows),full["items"]);
}

#[test]
fn malformed_component_evidence_never_becomes_successful_budget_prefix() {
    let (_store, mut reader, id, _) = fixture();
    reader.facts[0]["links"]=json!([{"relation":3,"target":"Order","resolution":"unresolved"}]);
    let parameters=json!({"id":id,"direction":"incoming"});
    let error=select(&reader,&Query::parse(&parameters).unwrap()).unwrap_err();
    assert_ne!(error.code,"limit_exceeded");
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
