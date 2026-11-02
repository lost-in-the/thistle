use super::*;

const SOURCE: &str = "module Example\n  class Record\n    def deliver\n      DeliveryJob.perform_later('<script>') if allowed?\n      raise 'body must not execute'\n      DeliveryJob.perform_later('second representative omitted')\n    end\n    def quiet = raise('not executed')\n    def self.deliver = DeliveryJob.perform_later\n    def heredoc; puts <<~TEXT; end\n      #{DeliveryJob.perform_later}\n    TEXT\n    def other_call = Dangerous.delete_all\n    def similarly_named = DeliveryJob.perform_later!\n    def safe = DeliveryJob&.perform_later\n    def setter; Dangerous.perform_later = 1; end\n  end\nend\n";

static FIXTURE: std::sync::OnceLock<(Value, String)> = std::sync::OnceLock::new();
fn fixture() -> (Value, String) {
    let (capture, id) = FIXTURE.get_or_init(|| {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("records.rb"), SOURCE).unwrap();
    let mut capture = {
        let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
        crate::capture::capture(root.path(), &json!({})).unwrap()
    };
    let source_root = root.path().to_str().unwrap();
    let observation = json!({"version":1,"active_record_version":"8.1.4","root":source_root,"status":"observed","models":[
        {"name":"Example::Child","superclass":"Example::Record","save":{"status":"observed","entries":[
            {"kind":"before","filter":{"kind":"method","owner":"Example::Record","name":"deliver","source":{"path":format!("{source_root}/records.rb"),"line":3}},
                "if":[{"kind":"method","owner":"Example::Record","name":"allowed?","source":null}],"unless":[],"inherited":true},
            {"kind":"after","filter":{"kind":"opaque"},"if":[],"unless":[],"inherited":false}
        ]}}]});
    let batch = crate::callbacks::batch(&json!({"limits":{"max_facts":1000,"max_links":1000,"max_entries":100000,"max_diagnostics":100},"facts":0,"links":0,"diagnostics":0,"fact_bytes":2}), &observation).unwrap();
    let id = batch["facts"][0]["id"].as_str().unwrap().to_owned();
    capture["facts"].as_array_mut().unwrap().extend(batch["facts"].as_array().unwrap().iter().cloned());
    (capture, id)
    });
    (capture.clone(), id.clone())
}
fn run(capture: &Value, id: &str, limit: usize) -> Value {
    let store = tempfile::tempdir().unwrap();
    crate::store::publish(store.path(), capture).unwrap();
    let reader = Reader::open(store.path(), None).unwrap();
    select(&reader, &Query::parse(&json!({"id":id,"limit":limit})).unwrap()).unwrap()
}
fn entry(capture: &mut Value) -> &mut Value {
    &mut capture["facts"].as_array_mut().unwrap().iter_mut().find(|f| f["kind"] == "rails_save_callbacks").unwrap()["attributes"]["callbacks"]["save"]["entries"][0]
}
fn method(capture: &mut Value) -> &mut Value {
    capture["facts"].as_array_mut().unwrap().iter_mut().find(|f| f["name"] == "Example::Record#deliver").unwrap()
}
fn explanation(result: &Value) -> &Value { &result["callbacks"][0]["explanation"] }

#[test]
fn real_prism_known_answer_is_source_potential_with_exact_spans_and_effective_owner() {
    let (capture, id) = fixture();
    let result = run(&capture, &id, 50);
    assert_eq!(result["model"], "Example::Child");
    let row = &result["callbacks"][0];
    assert_eq!(row["registry_id"], id);
    assert_eq!(row["position"], 0);
    assert_eq!(row["if"][0]["name"], "allowed?");
    let explanation = explanation(&result);
    assert_eq!(explanation["binding"], "descriptor_matched_captured_declaration");
    assert_eq!(explanation["method"]["owner"], "Example::Record");
    assert_eq!(explanation["coherence"], "unknown");
    let effect = &explanation["effects"][0];
    assert_eq!(effect["operation"], "DeliveryJob.perform_later");
    assert_eq!(effect["provenance"], "captured_source_potential");
    assert_eq!(explanation["effects"].as_array().unwrap().len(), 1, "existing first-representative dedup remains intact");
    for (key, expected) in [("call_span", "DeliveryJob.perform_later('<script>')"), ("receiver_span", "DeliveryJob")] {
        let loc = &effect[key];
        assert_eq!(&SOURCE[loc["start_byte"].as_u64().unwrap() as usize..loc["end_byte"].as_u64().unwrap() as usize], expected);
        assert_eq!(loc["start_line"], 4);
    }
    assert_eq!(result["callbacks"][1]["explanation"]["reason"], "opaque_or_incomplete_observed_method_descriptor");
    assert!(result["semantics"].as_str().unwrap().contains("No observed enqueue"));
    assert!(result["coverage"]["capture_partial_or_unknown"].as_bool().unwrap());
}

#[test]
fn incomplete_stale_wrong_owner_line_type_name_resolution_and_name_only_never_bind() {
    let (capture, id) = fixture();
    for (pointer, value) in [("/filter/owner",Value::Null), ("/filter/owner",json!("Example::Child")),
        ("/filter/source/line",json!(4)), ("/filter/source",Value::Null), ("/filter/source/path",json!("old.rb"))] {
        let mut bad = capture.clone(); *entry(&mut bad).pointer_mut(pointer).unwrap() = value;
        assert!(explanation(&run(&bad, &id, 50))["effects"].as_array().unwrap().is_empty(), "{pointer}");
    }
    for (pointer, value) in [("/attributes/singleton",json!(true)), ("/attributes/name_resolution",json!("unresolved_receiver")),
        ("/attributes/owner",Value::Null), ("/attributes/method_name",Value::Null), ("/name",json!("Example::Child#deliver")), ("/location",Value::Null)] {
        let mut bad = capture.clone(); *method(&mut bad).pointer_mut(pointer).unwrap() = value;
        assert!(explanation(&run(&bad, &id, 50))["effects"].as_array().unwrap().is_empty(), "{pointer}");
    }
    let mut opaque = capture.clone(); entry(&mut opaque)["filter"] = json!({"kind":"proc","source":{"path":"records.rb","line":3}});
    assert_eq!(explanation(&run(&opaque, &id, 50))["status"], "unknown");
}

#[test]
fn duplicate_overridden_declarations_are_ambiguous_even_when_one_location_matches() {
    let (mut capture, id) = fixture();
    let mut duplicate = method(&mut capture).clone();
    duplicate["id"] = json!("f".repeat(64));
    capture["facts"].as_array_mut().unwrap().push(duplicate);
    assert_eq!(explanation(&run(&capture, &id, 50))["reason"], "ambiguous_duplicate_instance_declarations");
}

#[test]
fn no_supported_match_partial_and_unavailable_registries_preserve_unknown_absence() {
    let (mut capture, id) = fixture();
    entry(&mut capture)["filter"]["name"] = json!("quiet");
    entry(&mut capture)["filter"]["source"]["line"] = json!(8);
    assert_eq!(explanation(&run(&capture, &id, 50))["status"], "no_supported_match");
    let fact = capture["facts"].as_array_mut().unwrap().iter_mut().find(|f| f["kind"] == "rails_save_callbacks").unwrap();
    fact["attributes"]["callbacks"]["save"]["status"] = json!("partial");
    fact["attributes"]["callbacks"]["save"]["entries"][0]["if"] = Value::Null;
    assert_eq!(run(&capture, &id, 50)["registry_status"], "partial");
    let fact = capture["facts"].as_array_mut().unwrap().iter_mut().find(|f| f["kind"] == "rails_save_callbacks").unwrap();
    fact["attributes"]["callbacks"]["save"] = json!({"status":"unavailable","entries":[]});
    let result = run(&capture, &id, 50);
    assert_eq!(result["registry_status"], "unavailable");
    assert!(result["callbacks"].as_array().unwrap().is_empty());
    assert!(result["coverage"]["absence"].as_str().unwrap().contains("does not establish"));
}

#[test]
fn missing_blob_is_unavailable_but_corruption_and_bad_coordinates_fail_closed() {
    let (mut capture, id) = fixture();
    let store = tempfile::tempdir().unwrap();
    let manifest = crate::store::publish(store.path(), &capture).unwrap();
    let reader = Reader::open(store.path(), None).unwrap();
    let blob = store.path().join("blobs").join(manifest["files"][0]["sha256"].as_str().unwrap());
    std::fs::remove_file(&blob).unwrap();
    let query = json!({"id":id}); let query = Query::parse(&query).unwrap();
    assert_eq!(explanation(&select(&reader, &query).unwrap())["reason"], "saved_source_blob_missing");
    std::fs::write(&blob, "wrong bytes").unwrap();
    assert_eq!(select(&reader, &query).unwrap_err().code, "invalid_snapshot");
    // Coordinate mismatch is accepted by metadata-only Reader validation but
    // refused when verified bytes are requested. No parser or regex is reused.
    method(&mut capture)["location"]["start_line"] = json!(2);
    entry(&mut capture)["filter"]["source"]["line"] = json!(2);
    let clean_store = tempfile::tempdir().unwrap();
    // Publication validates content, so forge metadata-only input by opening a
    // valid store then changing the in-memory test reader to isolate this path.
    let (good, _) = fixture(); crate::store::publish(clean_store.path(), &good).unwrap();
    let mut reader = Reader::open(clean_store.path(), None).unwrap();
    let changed = method(&mut capture).clone();
    let target = reader.facts.iter_mut().find(|f| f["name"] == "Example::Record#deliver").unwrap(); *target = changed;
    let target = reader.facts.iter_mut().find(|f| f["kind"] == "rails_save_callbacks").unwrap();
    target["attributes"]["callbacks"]["save"]["entries"][0]["filter"]["source"]["line"] = json!(2);
    assert_eq!(select(&reader, &query).unwrap_err().code, "invalid_snapshot");
}

#[test]
fn published_beyond_boundary_answer_is_reachable_pinned_and_globally_unique() {
    let (mut capture, id) = fixture();
    let expected_id = "0ff347492e45986cc1bd8cc868b5614bd7edc3df71166bc9667de2f134cce519";
    assert_eq!(method(&mut capture)["id"], expected_id);
    assert_eq!(method(&mut capture)["location"]["start_byte"], 34);
    assert_eq!(schema::digest(SOURCE.as_bytes()), "38d4416d4b1c273ebd0335e22f422f8290c4045c637f82990ef05ebf7d426080");
    for i in 0..20_050 {
        capture["facts"].as_array_mut().unwrap().push(json!({"id":format!("{i:064x}"),"kind":"class",
            "name":format!("Neutral{i}"),"path":null,"location":null,"evidence":"static","attributes":{},"links":[]}));
    }
    let store = tempfile::tempdir().unwrap();
    let manifest = crate::store::publish(store.path(), &capture).unwrap();
    let fresh = Reader::open(store.path(), manifest["generation"].as_str()).unwrap();
    let ordinal = fresh.facts.iter().position(|f| f["id"] == expected_id).unwrap();
    assert!(ordinal >= 20_050);
    let opened = crate::dispatch(&json!({"op":"open","path":store.path().to_str().unwrap(),"generation":manifest["generation"]})).unwrap();
    let request = json!({"op":"callback_effects","handle":opened["handle"],"id":id});
    let (mut next, _) = fixture(); next["producer"]["later"] = json!(true);
    crate::store::publish(store.path(), &next).unwrap();
    let result = crate::dispatch(&request).unwrap();
    assert_eq!(result["generation"], manifest["generation"]);
    assert_eq!(explanation(&result)["method"]["id"], expected_id);
    assert_eq!(explanation(&result)["effects"][0]["operation"], "DeliveryJob.perform_later");
    assert_eq!(explanation(&result)["effects"][0]["call_span"], json!({"start_byte":52,"end_byte":89,"start_line":4,"end_line":4}));
    assert_eq!(result["coverage"]["method_directory"]["facts_visited"], capture["facts"].as_array().unwrap().len());
    assert_eq!(result["coverage"]["method_directory"]["built_this_request"], true);
    let repeated = crate::dispatch(&request).unwrap();
    assert_eq!(repeated["coverage"]["method_directory"]["built_this_request"], false);
    assert_eq!(repeated["callbacks"], result["callbacks"]);
    let input = json!({"id":id});
    let reopened = select(&fresh, &Query::parse(&input).unwrap()).unwrap();
    assert_eq!(reopened["coverage"]["method_directory"]["built_this_request"], true);
    assert_eq!(reopened["callbacks"], result["callbacks"]);
    crate::dispatch(&json!({"op":"close","handle":opened["handle"]})).unwrap();
    let mut duplicate = method(&mut capture).clone(); duplicate["id"] = json!("f".repeat(64));
    duplicate["attributes"]["name_resolution"] = json!("unresolved_receiver");
    duplicate["location"] = Value::Null;
    capture["facts"].as_array_mut().unwrap().push(duplicate);
    let ambiguous = run(&capture, &id, 50);
    assert_eq!(explanation(&ambiguous)["reason"], "ambiguous_duplicate_instance_declarations");
    assert_eq!(ambiguous["coverage"]["declaration_scan_complete"], true);
    assert_eq!(ambiguous["coverage"]["candidate_ranges_complete"], false);
    eprintln!("CALLBACK_EFFECTS_WHOLE {}", json!({"ordinal":ordinal,"reader_opens":3,"demanded_builds":3,
        "queries":4,"first":result["coverage"],"reuse":repeated["coverage"],"reopen":reopened["coverage"],"duplicate":ambiguous["coverage"]}));
}

#[test]
fn refused_initialization_is_optional_retryable_and_does_not_affect_find_or_source() {
    let (capture, id) = fixture(); let store = tempfile::tempdir().unwrap();
    crate::store::publish(store.path(), &capture).unwrap();
    let reader = Reader::open(store.path(), None).unwrap();
    let request = json!({"id":id}); let query = Query::parse(&request).unwrap();
    let budget = crate::query::Budget::new(1);
    let refused = select_with_budget(&reader, &query, &budget).unwrap();
    assert_eq!(explanation(&refused)["reason"], "method_directory_unavailable");
    assert_eq!(refused["coverage"]["declaration_scan_complete"], false);
    assert!(!reader.find("deliver", 10).unwrap()["results"].as_array().unwrap().is_empty());
    assert_eq!(reader.source_file("records.rb").unwrap()["content"], SOURCE);
    assert_eq!(select(&reader, &query).unwrap()["coverage"]["method_directory"]["built_this_request"], true);
    assert!(budget.reserve(1).is_ok());
}

#[test]
fn concurrent_initialization_builds_once_and_inflight_close_retains_until_last_arc_drop() {
    let (capture, id) = fixture(); let store = tempfile::tempdir().unwrap();
    crate::store::publish(store.path(), &capture).unwrap();
    let opened = crate::dispatch(&json!({"op":"open","path":store.path().to_str().unwrap()})).unwrap();
    let retained = crate::reader(&json!({"handle":opened["handle"]})).unwrap();
    let budget = crate::query::Budget::new(1024 * 1024);
    let gate = std::sync::Arc::new(std::sync::Barrier::new(3));
    let mut threads = Vec::new();
    for _ in 0..2 {
        let reader = retained.clone(); let budget = budget.clone(); let gate = gate.clone(); let id = id.clone();
        threads.push(std::thread::spawn(move || {
            gate.wait();
            let request = json!({"id":id});
            select_with_budget(&reader, &Query::parse(&request).unwrap(), &budget).unwrap()
        }));
    }
    crate::dispatch(&json!({"op":"close","handle":opened["handle"]})).unwrap();
    assert_eq!(crate::dispatch(&json!({"op":"callback_effects","handle":opened["handle"],"id":id})).unwrap_err().code, "closed_reader");
    gate.wait();
    let results: Vec<_> = threads.into_iter().map(|t| t.join().unwrap()).collect();
    assert_eq!(results.iter().filter(|r| r["coverage"]["method_directory"]["built_this_request"] == true).count(), 1);
    assert_eq!(results[0]["callbacks"], results[1]["callbacks"]);
    assert!(budget.reserve(1024 * 1024).is_err());
    drop(retained);
    assert!(budget.reserve(1024 * 1024).is_ok());
}

#[test]
fn limits_charge_misses_metadata_output_sources_and_links_without_false_absence() {
    let (mut capture, id) = fixture();
    let result = run(&capture, &id, 1);
    assert_eq!(result["coverage"]["rows_not_searched"], 1);
    assert_eq!(result["coverage"]["truncated"], true);
    let first = entry(&mut capture).clone();
    let fact = capture["facts"].as_array_mut().unwrap().iter_mut().find(|f| f["kind"] == "rails_save_callbacks").unwrap();
    fact["attributes"]["callbacks"]["save"]["entries"] = json!((0..200).map(|i| { let mut e=first.clone(); e["position"]=json!(i); e }).collect::<Vec<_>>());
    let result = run(&capture, &id, 200);
    assert!(result["coverage"]["rows_output_omitted"].as_u64().unwrap() > 0);
    assert!(serde_json::to_vec(&result).unwrap().len() < MAX_OUTPUT);
    assert_eq!(result["coverage"]["source_files_attempted"], 1);
    let mut big = capture.clone();
    entry(&mut big)["if"] = json!((0..400).map(|_| json!({"kind":"method","name":"a".repeat(100),"owner":null,"source":null})).collect::<Vec<_>>());
    assert_eq!(run(&big, &id, 1)["coverage"]["rows_metadata_omitted"], 1);
    let store = tempfile::tempdir().unwrap(); crate::store::publish(store.path(), &capture).unwrap();
    let mut reader = Reader::open(store.path(), None).unwrap();
    let target = reader.facts.iter_mut().find(|f| f["name"] == "Example::Record#deliver").unwrap();
    let link = target["links"][0].clone(); target["links"] = json!(vec![link; MAX_LINKS/2+1]);
    let input = json!({"id":id}); let result = select(&reader,&Query::parse(&input).unwrap()).unwrap();
    assert_eq!(explanation(&result)["reason"], "link_visit_budget");
    assert_eq!(result["coverage"]["source_files_attempted"], 1);
    let mut work=Work { label_bytes:MAX_LABEL_BYTES-1,..Work::default() };
    assert!(work.compare("a","a").is_none());
}

#[test]
fn request_validation_close_and_shared_reservation_release_are_inherited() {
    for limit in [json!(0),json!(201),json!(-1),json!(1.5),json!("1"),Value::Null] {
        assert!(Query::parse(&json!({"id":"a".repeat(64),"limit":limit})).is_err());
    }
    assert_eq!(Query::parse(&json!({"id":"a".repeat(64)})).unwrap().limit,50);
    let (capture,id)=fixture(); let store=tempfile::tempdir().unwrap();
    crate::store::publish(store.path(),&capture).unwrap();
    let opened=crate::dispatch(&json!({"op":"open","path":store.path().to_str().unwrap()})).unwrap();
    let handle=&opened["handle"];
    let request=json!({"op":"callback_effects","handle":handle,"id":id});
    assert!(crate::dispatch(&request).is_ok());
    assert_eq!(crate::dispatch(&json!({"op":"callback_effects","handle":handle,"id":"f".repeat(64)})).unwrap_err().code,"not_found");
    let static_id=capture["facts"][0]["id"].as_str().unwrap();
    assert_eq!(crate::dispatch(&json!({"op":"callback_effects","handle":handle,"id":static_id})).unwrap_err().code,"invalid_input");
    crate::dispatch(&json!({"op":"close","handle":handle})).unwrap();
    assert_eq!(crate::dispatch(&request).unwrap_err().code,"closed_reader");
}

#[test]
fn source_attempt_and_expansion_budgets_charge_missing_reads_and_reject_oversize() {
    let (mut capture, id) = fixture();
    let content = format!("{SOURCE}{}", " ".repeat(MAX_FILE_BYTES));
    capture["files"][0]["content"] = json!(content);
    capture["files"][0]["bytes"] = json!(content.len());
    capture["files"][0]["sha256"] = json!(schema::digest(content.as_bytes()));
    let result = run(&capture, &id, 50);
    assert_eq!(explanation(&result)["reason"], "source_byte_budget");
    assert_eq!(result["coverage"]["source_files_attempted"], 1);
    assert_eq!(result["coverage"]["source_bytes_charged"], 0);

    for (file_bytes, expected_bytes, reason) in [
        (MAX_FILE_BYTES, MAX_SOURCE_BYTES, "source_byte_budget"), (1, 16, "source_file_attempt_budget")
    ] {
        let (mut capture, id) = fixture();
        let template = method(&mut capture).clone();
        let template_entry = entry(&mut capture).clone();
        capture["facts"].as_array_mut().unwrap().retain(|f| f["kind"] == "rails_save_callbacks");
        let mut entries = Vec::new(); let mut files = Vec::new();
        for i in 0..18 {
            let name = format!("deliver{i}"); let path = format!("{i}.rb");
            let mut fact = template.clone(); fact["id"] = json!(format!("{i:064x}"));
            fact["name"] = json!(format!("Example::Record#{name}")); fact["attributes"]["method_name"] = json!(name);
            fact["path"] = json!(path); fact["links"] = json!([]);
            fact["location"] = json!({"start_byte":0,"end_byte":1,"start_line":1,"end_line":1});
            capture["facts"].as_array_mut().unwrap().push(fact);
            let mut row = template_entry.clone(); row["position"] = json!(i); row["filter"]["name"] = json!(name);
            row["filter"]["source"] = json!({"path":path,"line":1}); entries.push(row);
            // Valid public artifacts with actual saved source; remove blobs only
            // after publication so missing attempts charge declared bytes.
            let content = format!("x{}", " ".repeat(file_bytes.saturating_sub(1)));
            files.push(json!({"path":path,"sha256":schema::digest(content.as_bytes()),"bytes":content.len(),"encoding":"UTF-8","content":content}));
        }
        let registry = capture["facts"].as_array_mut().unwrap().iter_mut().find(|f| f["kind"] == "rails_save_callbacks").unwrap();
        registry["attributes"]["callbacks"]["save"]["entries"] = json!(entries);
        capture["files"] = json!(files);
        let store = tempfile::tempdir().unwrap();
        let manifest = crate::store::publish(store.path(), &capture).unwrap();
        for file in manifest["files"].as_array().unwrap() {
            let _ = std::fs::remove_file(store.path().join("blobs").join(file["sha256"].as_str().unwrap()));
        }
        let reader = Reader::open(store.path(), None).unwrap();
        let request = json!({"id":id}); let result = select(&reader, &Query::parse(&request).unwrap()).unwrap();
        assert_eq!(result["coverage"]["source_files_attempted"], 16);
        assert_eq!(result["coverage"]["source_bytes_charged"], expected_bytes);
        assert!(result["callbacks"].as_array().unwrap().iter().any(|r| r["explanation"]["reason"] == reason));
    }
}

#[test]
fn only_recognized_non_omitted_constant_receiver_calls_are_effects() {
    let (capture,id)=fixture(); let store=tempfile::tempdir().unwrap();
    crate::store::publish(store.path(),&capture).unwrap();
    for kind in ["local","expression","omitted","legacy"] {
        let mut reader=Reader::open(store.path(),None).unwrap();
        let version=reader.schema_version();
        let target=reader.facts.iter_mut().find(|f|f["name"]=="Example::Record#deliver").unwrap();
        // Use semantic links to test schema-aware decoding across formats.
        *target=crate::link_encoding::materialize_fact(target,version).unwrap();
        let call=target["links"].as_array_mut().unwrap().iter_mut().find(|l|l["target"]=="perform_later").unwrap();
        let data=&mut call["attributes"]["thistle_call"]["data"];
        match kind {
            "local"=>data[0]=json!("local"),
            "expression"=>{data[0]=json!("expression");data[1]=Value::Null;},
            "omitted"=>{data[1]=Value::Null;data[2]=json!(true);},
            _=>{ call["attributes"]["thistle_call"]=json!({"version":99}); }
        }
        let request=json!({"id":id}); let result=select(&reader,&Query::parse(&request).unwrap()).unwrap();
        assert_eq!(explanation(&result)["status"],"no_supported_match","{kind}");
    }
}

#[test]
fn verified_heredoc_call_outside_lexical_method_span_is_unknown_not_corrupt() {
    let (mut capture, id) = fixture();
    entry(&mut capture)["filter"]["name"] = json!("heredoc");
    let method = capture["facts"].as_array().unwrap().iter()
        .find(|f| f["name"] == "Example::Record#heredoc").unwrap();
    let method_line = method["location"]["start_line"].clone();
    let call = method["links"].as_array().unwrap().iter().filter_map(|wire| {
        let view = SemanticLinkView::from_semantic(wire, schema::VERSION, "static").unwrap();
        (view.target() == "perform_later").then(|| view.call_metadata().unwrap().location)
    }).next().expect("actual Prism heredoc interpolation call");
    assert!(call.start_byte > method["location"]["end_byte"].as_u64().unwrap(),
        "regression must exercise valid discontiguous heredoc coordinates");
    entry(&mut capture)["filter"]["source"]["line"] = method_line;
    let store = tempfile::tempdir().unwrap();
    let manifest = crate::store::publish(store.path(), &capture).unwrap();
    let reader = Reader::open(store.path(), manifest["generation"].as_str()).unwrap();
    assert_eq!(reader.check().unwrap()["integrity"], "verified");
    let request = json!({"id":id});
    let result = select(&reader, &Query::parse(&request).unwrap()).unwrap();
    assert_eq!(result["generation"], manifest["generation"]);
    assert_eq!(result["registry_status"], "observed");
    assert_eq!(result["callbacks"].as_array().unwrap().len(), 2);
    assert_eq!(explanation(&result)["status"], "unknown");
    assert_eq!(explanation(&result)["reason"], "recorded_call_outside_lexical_method_span");
    assert_eq!(explanation(&result)["links_search_complete"], false);
    assert!(explanation(&result)["effects"].as_array().unwrap().is_empty());
    assert_eq!(result["callbacks"][1]["explanation"]["reason"], "opaque_or_incomplete_observed_method_descriptor");
}

#[test]
fn published_call_labels_must_be_corroborated_by_saved_source_not_just_coordinates() {
    let (original, id) = fixture();
    for (method_name, mutation) in [("other_call", "selector"), ("deliver", "receiver"),
        ("deliver", "safe_navigation"), ("similarly_named", "selector"), ("setter", "selector")] {
        let mut capture = original.clone();
        let target = capture["facts"].as_array_mut().unwrap().iter_mut()
            .find(|f| f["name"] == format!("Example::Record#{method_name}")).unwrap();
        let line = target["location"]["start_line"].clone();
        let link = target["links"].as_array_mut().unwrap().iter_mut()
            .find(|l| l["target"] == if method_name == "other_call" { "delete_all" }
                else if method_name == "similarly_named" { "perform_later!" }
                else if method_name == "setter" { "perform_later=" } else { "perform_later" }).unwrap();
        match mutation {
            "selector" => link["target"] = json!("perform_later"),
            "receiver" => link["attributes"]["thistle_call"]["data"][1] = json!("DifferentJob"),
            _ => link["attributes"]["thistle_call"]["data"][3] = json!(true),
        }
        entry(&mut capture)["filter"]["name"] = json!(method_name);
        entry(&mut capture)["filter"]["source"]["line"] = line;
        // These are public publication-boundary mutations, not in-memory Reader
        // changes: shape/coordinates/Check all pass while the labels disagree.
        let store = tempfile::tempdir().unwrap();
        crate::store::publish(store.path(), &capture).unwrap();
        let reader = Reader::open(store.path(), None).unwrap();
        assert_eq!(reader.check().unwrap()["integrity"], "verified");
        let request = json!({"id":id});
        let result = select(&reader, &Query::parse(&request).unwrap()).unwrap();
        assert_eq!(explanation(&result)["status"], "unknown", "{method_name}/{mutation}");
        assert_eq!(explanation(&result)["reason"], "recorded_call_spelling_not_corroborated");
        assert_eq!(explanation(&result)["links_search_complete"], false);
        assert!(explanation(&result)["effects"].as_array().unwrap().is_empty());
    }
    let mut safe = original;
    let line = safe["facts"].as_array().unwrap().iter()
        .find(|f| f["name"] == "Example::Record#safe").unwrap()["location"]["start_line"].clone();
    entry(&mut safe)["filter"]["name"] = json!("safe");
    entry(&mut safe)["filter"]["source"]["line"] = line;
    let result = run(&safe, &id, 50);
    assert_eq!(explanation(&result)["status"], "supported_potential");
    assert_eq!(explanation(&result)["effects"][0]["operation"], "DeliveryJob.perform_later");
    assert_eq!(explanation(&result)["effects"][0]["safe_navigation"], true);
}
