use super::*;

fn fixture() -> (tempfile::TempDir, Reader, String, Value) {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("records.rb"), "class Item; def visit; Order.find; end; end\n").unwrap();
    let mut capture = crate::capture::capture(root.path(), &json!({})).unwrap();
    let observation: Value = serde_json::from_str(include_str!("../tests/fixtures/models.json")).unwrap();
    let mut batch = crate::model::batch(&json!({"limits":{"max_facts":100000,"max_links":100000,"max_entries":100000,"max_diagnostics":100},"facts":0,"links":0,"diagnostics":0,"fact_bytes":2}), &observation).unwrap();
    let id = batch["facts"][0]["id"].as_str().unwrap().to_owned();
    capture["facts"].as_array_mut().unwrap().append(batch["facts"].as_array_mut().unwrap());
    let store = tempfile::tempdir().unwrap();
    crate::store::publish(store.path(), &capture).unwrap();
    let reader = Reader::open(store.path(), None).unwrap();
    (store, reader, id, capture)
}
fn query(id: &str, limit: usize, max_bytes: usize) -> Value { json!({"id":id,"limit":limit,"max_bytes":max_bytes}) }

#[test]
fn projection_pinned_families_wire_usage_and_low_item_budget() {
    let (_store, reader, id, _) = fixture();
    let parameters = query(&id, 1, 32768);
    let result = select(&reader, &Query::parse(&parameters).unwrap()).unwrap();
    assert_eq!(result["generation"], reader.generation);
    assert_eq!(result["root"]["id"], id);
    assert!(result["root"].get("attributes").is_none());
    assert_eq!(result["families"]["columns"]["items"][0], json!({"name":"state","type":"string","null":false}));
    assert_eq!(result["families"]["associations"]["known_omitted"], 1);
    assert_eq!(result["families"]["registry_candidates"]["status"], "unavailable");
    assert_eq!(result["families"]["callbacks"]["status"], "not_searched");
    assert_eq!(result["families"]["incoming"]["items"][0]["origin"]["id"], id);
    assert_eq!(result["families"]["incoming"]["items"][0]["candidate_search_complete"], false);
    assert_eq!(result["usage"]["wire_bytes_including_newline"], schema::canonical(&result).unwrap().len()+1);
    let visits = result["cost"]["incremental_request"]["fact_visits"].as_u64().unwrap();
    assert!(visits < FACTS as u64);
    assert_eq!(result["cost"]["whole_job"]["fact_visits"], visits + 5*reader.facts.len() as u64);
    assert!(result["coverage"]["capture_partial_or_unknown"].as_bool().unwrap());
}

#[test]
fn one_remaining_fact_never_becomes_independent_selector_allowances() {
    let (_store, reader, id, _) = fixture();
    let parameters = query(&id, 8, 32768);
    let mut work = RequestWork { facts:FACTS-1, ..RequestWork::default() };
    let result = select_with_work(&reader, &Query::parse(&parameters).unwrap(), &mut work).unwrap();
    assert_eq!(work.facts, FACTS);
    for name in ["columns", "associations", "registry_candidates", "callbacks", "outgoing", "incoming"] {
        assert_eq!(result["families"][name]["unsearched"], true, "{name}");
        assert!(result["families"][name]["items"].as_array().unwrap().is_empty());
    }
}

#[test]
fn strict_request_and_mandatory_envelope_refusals() {
    let (_store, reader, id, _) = fixture();
    for parameters in [query(&id,0,32768),query(&id,17,32768),query(&id,8,0),query(&id,8,65537),json!({"id":id,"limit":1.5}),json!({"id":"Order"})] {
        assert_eq!(Query::parse(&parameters).err().unwrap().code, "invalid_input");
    }
    assert_eq!(select(&reader,&Query::parse(&query(&id,8,1)).unwrap()).unwrap_err().code,"limit_exceeded");
    assert_eq!(select(&reader,&Query::parse(&query(&"f".repeat(64),8,32768)).unwrap()).unwrap_err().code,"not_found");
    let wrong = reader.facts.iter().find(|f| f["kind"] == "class").unwrap()["id"].as_str().unwrap();
    assert_eq!(select(&reader,&Query::parse(&query(wrong,8,32768)).unwrap()).unwrap_err().code,"invalid_input");
}

#[test]
fn shared_admission_counters_are_atomic_and_bound_every_dimension() {
    let mut work = RequestWork { facts:FACTS-1, links:LINKS, comparisons:COMPARISONS,
        label_bytes:LABEL_BYTES, files:FILES, source_bytes:SOURCE_BYTES, metadata_bytes:METADATA_BYTES, finishing:false };
    assert!(!work.method(1,1)); assert_eq!(work.facts,FACTS-1);
    assert!(work.facts(1)); assert!(!work.facts(1)); assert!(!work.links(1));
    assert!(!work.labels(0)); assert!(!work.comparison()); assert!(!work.label_bytes(1));
    assert!(!work.source_attempt()); assert!(!work.source_bytes(1));
    assert!(work.metadata(&json!({}),1).is_err());
}

#[test]
fn scoped_reference_default_matches_standalone_without_extra_incoming_expansion() {
    let (_store,reader,id,_) = fixture();
    for direction in ["incoming","outgoing"] {
        let parameters = json!({"id":id,"direction":direction});
        let query=references::Query::parse(&parameters).unwrap();
        let standalone=references::select(&reader,&query).unwrap();
        let mut work=RequestWork::default();
        assert_eq!(references::select_scoped(&reader,&query,Some(&mut work)).unwrap(),standalone);
        assert!(work.facts>0);
        if direction == "incoming" { assert_eq!(standalone["coverage"]["candidate_facts_scanned"],0); }
    }
}

#[test]
fn registry_label_discovery_keeps_global_ambiguity_incomplete_and_anonymous_distinct() {
    let (_store, reader, id, mut capture) = fixture();
    let context = json!({"limits":{"max_facts":100000,"max_links":100000,"max_entries":100000,"max_diagnostics":100},"facts":0,"links":0,"diagnostics":0,"fact_bytes":2});
    let observed = json!({"name":"Order","superclass":null,"save":{"status":"observed","entries":[]}});
    let mut observation = json!({"version":1,"active_record_version":"8.1.4","root":"/fixture","status":"observed","models":[observed]});
    let mut batch = crate::callbacks::batch(&context,&observation).unwrap();
    capture["facts"].as_array_mut().unwrap().append(batch["facts"].as_array_mut().unwrap());
    let single = tempfile::tempdir().unwrap();
    crate::store::publish(single.path(),&capture).unwrap();
    let single_reader = Reader::open(single.path(),None).unwrap();
    let root=single_reader.stored_fact(&id).unwrap();
    let (result,candidate)=registries(&single_reader,root,&mut RequestWork::default()).unwrap();
    assert_eq!(result["status"],"unique_label_candidate"); assert!(candidate.is_some());
    let cb_query=json!({"id":candidate.unwrap()});
    let cb_query=callback_effects::Query::parse(&cb_query).unwrap();
    let plain=callback_effects::select(&single_reader,&cb_query).unwrap();
    assert_eq!(callback_effects::select_scoped(&single_reader,&cb_query,crate::query::budget(),Some(&mut RequestWork::default())).unwrap(),plain);
    let incomplete=registries(&single_reader,root,&mut RequestWork {facts:FACTS-1,..RequestWork::default()}).unwrap();
    assert_eq!(incomplete.0["scan_complete"],false); assert!(incomplete.1.is_none());
    observation["models"].as_array_mut().unwrap().push(json!({"name":"Order","superclass":null,"save":{"status":"unavailable","entries":[]}}));
    let mut batch=crate::callbacks::batch(&context,&observation).unwrap();
    capture["facts"].as_array_mut().unwrap().retain(|f| f["kind"]!="rails_save_callbacks");
    capture["facts"].as_array_mut().unwrap().append(batch["facts"].as_array_mut().unwrap());
    let multiple=tempfile::tempdir().unwrap();crate::store::publish(multiple.path(),&capture).unwrap();
    let multiple_reader=Reader::open(multiple.path(),None).unwrap();
    let result=select(&multiple_reader,&Query::parse(&query(&id,8,32768)).unwrap()).unwrap();
    assert_eq!(result["families"]["registry_candidates"]["status"],"ambiguous");
    assert_eq!(result["families"]["registry_candidates"]["items"].as_array().unwrap().len(),2);
    assert_eq!(result["families"]["callbacks"]["status"],"not_searched");
    let mut anonymous=reader.stored_fact(&id).unwrap().clone();anonymous["attributes"]["model"]["name"]=Value::Null;
    let result=registries(&reader,&anonymous,&mut RequestWork::default()).unwrap();
    assert_eq!(result.0["reason"],"anonymous_model_has_no_label"); assert!(result.1.is_none());
}
