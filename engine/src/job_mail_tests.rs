use super::*;

// Authored UNRUN in the source-only phase; shares the public capture test lock.
#[test]
fn shared_parser_worker_refuses_nested_admission_and_releases_after_errors_and_panics() {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let result = crate::capture::parser_worker("thistle-parser-test", || {
        let nested = crate::capture::parser_worker("thistle-parser-nested", || Ok(()));
        assert_eq!(nested.unwrap_err().code,"busy");
        Ok(17)
    }).unwrap();
    assert_eq!(result,17);
    let error = crate::capture::parser_worker::<()>("thistle-parser-error", || Err(CoreError::input("fixture error"))).unwrap_err();
    assert_eq!(error.code,"invalid_input");
    assert_eq!(crate::capture::parser_worker("thistle-parser-after-error", || Ok(23)).unwrap(),23);
    let error = crate::capture::parser_worker::<()>("thistle-parser-panic", || panic!("fixture worker panic")).unwrap_err();
    assert_eq!(error.code,"internal_error");
    assert_eq!(crate::capture::parser_worker("thistle-parser-after-panic", || Ok(29)).unwrap(),29);
}

fn context() -> Value {
    json!({"schema_version":3,"facts":0,"links":0,"diagnostics":0,"fact_bytes":2,
        "limits":{"max_facts":100,"max_links":100,"max_entries":100,"max_diagnostics":100}})
}
fn observation() -> Value {
    json!({"version":1,"framework_version":"8.1.4","root":"/public/fixture","boundary":"explicit_loaded_app","status":"observed",
        "classes":[{"kind":"job","name":"ReceiptJob","superclass":"ApplicationJob","rescue_handlers":{"status":"observed","entries":[
        {"exception":"DeliveryTimeout","handler":{"kind":"proc","source":{"path":"/framework/exceptions.rb","line":63}},"shared_with_superclass":true},
        {"exception":"MissingRecipient","handler":{"kind":"proc","source":{"path":"/framework/exceptions.rb","line":63}},"shared_with_superclass":false},
        {"exception":"UnloadedDeliveryError","handler":{"kind":"method","name":"record_failure","owner":"ReceiptJob",
            "source":{"path":"/public/fixture/app/jobs/receipt_job.rb","line":19}},"shared_with_superclass":false}]}}]})
}

#[test]
fn registry_is_strict_and_never_invents_retry_parameters_or_registration_sites() {
    let result = batch(&context(),&observation()).unwrap();
    let fact = &result["facts"][0];
    validate_fact(fact).unwrap();
    let entries = &fact["attributes"]["job_mail"]["class"]["rescue_handlers"]["entries"];
    assert!(entries[0]["handler"]["source"].is_null());
    assert_eq!(entries[2]["handler"]["source"]["path"],"app/jobs/receipt_job.rb");
    assert!(fact["path"].is_null());
    assert!(entries[0].get("attempts").is_none());
    let mut bad = fact.clone(); bad["attributes"]["job_mail"]["coherence"] = json!("verified");
    assert!(validate_fact(&bad).is_err());
    let mut bad = observation(); bad["classes"][0]["rescue_handlers"]["entries"][0]["attempts"] = json!(4);
    assert!(batch(&context(),&bad).is_err());
}

#[test]
fn query_family_limit_budget_and_continuation_scope_are_validated() {
    let id = "a".repeat(64);
    assert!(Query::parse(&json!({"id":id})).is_ok());
    for change in [json!({"id":id,"family":"execute"}),json!({"id":id,"limit":17}),json!({"id":id,"max_bytes":65537})] {
        assert!(Query::parse(&change).is_err());
    }
    let scope = json!(["job_mail",id,"policy"]);
    let cursor = recorded_domain::cursor(&"b".repeat(64),&scope,(3,2)).unwrap();
    assert!(recorded_domain::position(Some(&cursor),&"c".repeat(64),&scope).is_err());
    assert!(recorded_domain::position(Some(&cursor),&"b".repeat(64),&json!(["job_mail",id,"handoff"])).is_err());
}

#[test]
fn source_policy_options_and_dynamic_template_selection_are_separate_from_registry() {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let source = "class ApplicationJob; retry_on DeliveryTimeout, wait: :polynomially_longer, attempts: 4; end";
    let fact = json!({"id":"a".repeat(64),"kind":"class","location":{"start_byte":0,"end_byte":source.len()}});
    let result = parse_source(&fact,"app/jobs/application_job.rb",source).unwrap();
    let policy = &result["rows"][0];
    assert_eq!(policy["operation"],"retry_on");
    assert_eq!(policy["registration_match"],"unknown");
    assert_eq!(policy["exceptions"][0]["source"],"DeliveryTimeout");
    assert!(policy.get("arguments").is_none());
    assert_eq!(policy["options"]["attempts"]["source"],"4");
    assert_eq!(policy["options"]["wait"]["source"],":polynomially_longer");
    let source = "def dynamic_receipt; mail(template_path: 'receipt_mailer', template_name: @selected); end";
    let fact = json!({"id":"b".repeat(64),"kind":"method","location":{"start_byte":0,"end_byte":source.len()}});
    let result = parse_source(&fact,"app/mailers/receipt_mailer.rb",source).unwrap();
    assert_eq!(result["rows"][0]["status"],"dynamic_unknown");
    assert!(candidate_key(&result["rows"][0]).is_none());
    let source = r#"def receipt; mail(template_path: 'receipt_mailer', template_name: "\xFF"); end"#;
    let fact = json!({"id":"c".repeat(64),"kind":"method","location":{"start_byte":0,"end_byte":source.len()}});
    let result = parse_source(&fact,"app/mailers/receipt_mailer.rb",source).unwrap();
    assert_eq!(result["rows"][0]["status"],"dynamic_unknown");
    assert!(candidate_key(&result["rows"][0]).is_none());
}

// Genuine native capture/publication/Reader regressions, authored UNRUN. Root
// must execute these under its later native/filesystem resource admission.
#[test]
fn explicit_inert_templates_deduplicate_and_survive_saved_reader_admission() {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("job.rb"),"class ReceiptJob; def perform(id); ReceiptMailer.receipt(id).deliver_later; end; end").unwrap();
    let content = "<%= receipt_heading(@recipient) %>\n<% raise 'never evaluate' %>\n";
    std::fs::write(root.path().join("receipt.erb"),content).unwrap();
    let ordinary = crate::capture::capture(root.path(),&json!({})).unwrap();
    assert!(!ordinary["files"].as_array().unwrap().iter().any(|f| f["path"] == "receipt.erb"));
    let mut captured = crate::capture::capture_with_templates(root.path(),&json!({}),&json!(["receipt.erb","receipt.erb"])).unwrap();
    assert_eq!(captured["files"].as_array().unwrap().iter().filter(|f| f["path"] == "receipt.erb").count(),1);
    let file_fact = captured["facts"].as_array().unwrap().iter().find(|f| f["name"] == "receipt.erb").unwrap().clone();
    assert_eq!(file_fact["attributes"]["parse_status"],"inert");
    let mut context = context();
    context["facts"] = json!(captured["facts"].as_array().unwrap().len());
    context["links"] = json!(captured["facts"].as_array().unwrap().iter().map(|f| f["links"].as_array().unwrap().len()).sum::<usize>());
    context["fact_bytes"] = captured["evidence_accounting"]["fact_bytes_upper_bound"].clone();
    let added = batch(&context,&observation()).unwrap();
    let registry = added["facts"][0].clone();
    let mut mailer = observation();
    mailer["classes"][0]["kind"] = json!("mailer");
    mailer["classes"][0]["name"] = json!("ReceiptMailer");
    let mailer = batch(&context,&mailer).unwrap();
    let mailer_registry = mailer["facts"][0].clone();
    captured["facts"].as_array_mut().unwrap().extend(mailer["facts"].as_array().unwrap().iter().cloned());
    captured["facts"].as_array_mut().unwrap().extend(added["facts"].as_array().unwrap().iter().cloned());
    captured["coverage"].as_array_mut().unwrap().extend(added["coverage"].as_array().unwrap().iter().cloned());
    let store = tempfile::tempdir().unwrap();
    let manifest = crate::store::publish(store.path(),&captured).unwrap();
    let reader = Reader::open(store.path(),manifest["generation"].as_str()).unwrap();
    assert_eq!(reader.source_file("receipt.erb").unwrap()["content"],content);
    let query = json!({"id":mailer_registry["id"],"family":"declarations","limit":16});
    let answer = select(&reader,&Query::parse(&query).unwrap()).unwrap();
    assert!(answer["items"].as_array().unwrap().iter().all(|row| row["role"] != "perform"));
    let query = json!({"id":registry["id"],"family":"declarations","limit":16});
    let answer = select(&reader,&Query::parse(&query).unwrap()).unwrap();
    assert!(answer["items"].as_array().unwrap().iter().any(|row| row["role"] == "perform"));
    let query = json!({"id":file_fact["id"],"family":"template_references","limit":1});
    let answer = select(&reader,&Query::parse(&query).unwrap()).unwrap();
    assert_eq!(answer["generation"],manifest["generation"]);
    assert_eq!(answer["root"]["kind"],"file");
    assert!(!answer["next_cursor"].is_null());
    let query = json!({"id":registry["id"],"family":"registrations","limit":1});
    assert!(!select(&reader,&Query::parse(&query).unwrap()).unwrap()["page_complete"].as_bool().unwrap());
    let mut bad = captured.clone();
    bad["facts"].as_array_mut().unwrap().last_mut().unwrap()["attributes"]["job_mail"]["coherence"] = json!("verified");
    assert!(crate::store::publish(store.path(),&bad).is_err());
    assert_eq!(Reader::open(store.path(),None).unwrap().generation,manifest["generation"].as_str().unwrap());
}

#[test]
fn explicit_template_paths_cannot_escape_or_bypass_existing_inventory_limits() {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let root = tempfile::tempdir().unwrap();
    let outside = tempfile::tempdir().unwrap();
    std::fs::write(outside.path().join("outside.erb"),"outside").unwrap();
    std::os::unix::fs::symlink(outside.path(),root.path().join("linked")).unwrap();
    std::os::unix::fs::symlink(outside.path().join("outside.erb"),root.path().join("linked.erb")).unwrap();
    for (path,code) in [("../outside.erb","unsafe_path"),("linked/outside.erb","unsafe_path"),("linked.erb","unsafe_path"),
        ("vendor/hidden.erb","invalid_input"),("unsupported.haml","invalid_input")] {
        let error = crate::capture::capture_with_templates(root.path(),&json!({}),&json!([path])).unwrap_err();
        assert_eq!(error.code,code,"{path}");
        assert!(!error.message.contains(root.path().to_str().unwrap()));
        assert!(!error.message.contains(outside.path().to_str().unwrap()));
    }
    let error = crate::capture::capture_with_templates(root.path(),&json!({}),&json!(["missing.erb"])).unwrap_err();
    assert_eq!(error.code,"not_found");
    assert!(error.message.contains("missing.erb"));
    assert!(!error.message.contains(root.path().to_str().unwrap()));
    // A separate one-entry root makes ordinary walk succeed BEFORE explicit
    // component traversal exhausts the SAME counter; no whole large inventory.
    let small = tempfile::tempdir().unwrap();
    std::fs::write(small.path().join("regular.erb"),"<%= inert %>").unwrap();
    crate::capture::capture(small.path(),&json!({"max_entries":1})).unwrap();
    let error = crate::capture::capture_with_templates(small.path(),&json!({"max_entries":1}),&json!(["regular.erb"])).unwrap_err();
    assert_eq!(error.code,"limit_exceeded");
    assert_eq!(error.message,"Explicit template inventory exceeds max_entries");
    let accepted = crate::capture::capture_with_templates(small.path(),&json!({"max_entries":2}),&json!(["regular.erb","regular.erb"])).unwrap();
    assert_eq!(accepted["producer"]["inventory_entries"],2);
    assert_eq!(accepted["producer"]["explicit_template_entries"],1);
    let error = crate::capture::capture_with_templates(small.path(),&json!({"max_file_bytes":1}),&json!(["regular.erb"])).unwrap_err();
    assert_eq!(error.code,"limit_exceeded");
    let anonymous = json!({"kind":"rails_job_mail","name":"Anonymous job 0","attributes":{"job_mail":{"class":{"name":null}}}});
    assert!(recorded_domain::candidate_name(&anonymous).is_none());
}


#[test]
fn oversized_handler_display_is_bounded_without_losing_options_or_source_witness() {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let body = "雪".repeat(4_000);
    let source = format!("class ReceiptJob; rescue_from DeliveryTimeout, with: ->(e) {{ '{body}' }}; end");
    let fact = json!({"id":"a".repeat(64),"kind":"class","location":{"start_byte":0,"end_byte":source.len()}});
    let answer = parse_source(&fact,"app/jobs/receipt_job.rb",&source).unwrap();
    let row = &answer["rows"][0];
    assert_eq!(row["exceptions"].as_array().unwrap().len(),1); // positional exception only
    assert!(row.get("arguments").is_none());
    assert_eq!(row["options"]["with"]["truncated"],true);
    assert!(row["options"]["with"]["source"].as_str().unwrap().len() <= 256);
    assert!(row["options"]["with"]["source_bytes"].as_u64().unwrap() > 8_000);
    assert_eq!(row["span"]["start_byte"],source.find("rescue_from").unwrap());
    assert!(schema::encoded_bytes(row,4_096).is_ok());
    for source in ["def receipt; mail(template_name: 'receipt'); end", "def receipt; mail(to: @recipient); end", "def receipt; render 'receipt_mailer/receipt'; end"] {
        let fact = json!({"id":"b".repeat(64),"kind":"method","location":{"start_byte":0,"end_byte":source.len()}});
        let answer = parse_source(&fact,"app/mailers/receipt_mailer.rb",source).unwrap();
        assert_eq!(answer["rows"][0]["status"],"unsupported_selection_unknown");
        assert!(candidate_key(&answer["rows"][0]).is_none());
    }
}


#[test]
fn original_template_target_is_not_a_truncated_display_value() {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let name = "r".repeat(300);
    let source = format!("def receipt; mail(template_path: 'receipt_mailer', template_name: '{name}'); end");
    let fact = json!({"id":"d".repeat(64),"kind":"method","location":{"start_byte":0,"end_byte":source.len()}});
    let answer = parse_source(&fact,"app/mailers/receipt_mailer.rb",&source).unwrap();
    let row = &answer["rows"][0];
    assert_eq!(row["template"],name);
    assert_eq!(candidate_key(row).unwrap().0,format!("app/views/receipt_mailer/{name}.html.erb"));
}

#[test]
fn saved_source_pages_omit_unsearched_only_when_no_work_is_marked_unsearched() {
    let _guard = crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("job.rb"),
        "class ReceiptJob; retry_on DeliveryTimeout, wait: 5; def perform; ReceiptMailer.receipt.deliver_later; end; end").unwrap();
    std::fs::write(root.path().join("bounded.rb"),
        format!("class BoundedPolicy\n{}end\n","retry_on\n".repeat(201))).unwrap();
    std::fs::write(root.path().join("complete.erb"),"<%= @recipient %>").unwrap();
    std::fs::write(root.path().join("partial.erb"),"<%= @recipient %>\n".repeat(240)).unwrap();
    let captured = crate::capture::capture_with_templates(root.path(),&json!({}),
        &json!(["complete.erb","partial.erb"])).unwrap();
    let facts = captured["facts"].as_array().unwrap();
    let policy = facts.iter().find(|fact| fact["kind"] == "class" && fact["name"] == "ReceiptJob").unwrap();
    let bounded_policy = facts.iter().find(|fact| fact["kind"] == "class" && fact["name"] == "BoundedPolicy").unwrap();
    let handoff = facts.iter().find(|fact| fact["kind"] == "method").unwrap();
    let complete = facts.iter().find(|fact| fact["kind"] == "file" && fact["name"] == "complete.erb").unwrap();
    let partial = facts.iter().find(|fact| fact["kind"] == "file" && fact["name"] == "partial.erb").unwrap();
    let store = tempfile::tempdir().unwrap();
    let manifest = crate::store::publish(store.path(),&captured).unwrap();
    let reader = Reader::open(store.path(),manifest["generation"].as_str()).unwrap();
    for (fact,family) in [(policy,"policy"),(handoff,"handoff"),(complete,"template_references")] {
        let query = json!({"id":fact["id"],"family":family,"limit":1});
        let answer = select(&reader,&Query::parse(&query).unwrap()).unwrap();
        assert_eq!(answer["coverage"]["source_scan_complete"],true);
        assert!(answer["coverage"].get("unsearched").is_none());
        assert!(answer["coverage"]["reason"].as_str().is_some_and(|reason| !reason.is_empty()));
    }
    let query = json!({"id":partial["id"],"family":"template_references","limit":1});
    let answer = select(&reader,&Query::parse(&query).unwrap()).unwrap();
    assert_eq!(answer["coverage"]["source_scan_complete"],false);
    assert_eq!(answer["coverage"]["unsearched"],"remaining_reference_or_node_work");
    let query = json!({"id":bounded_policy["id"],"family":"policy","limit":1});
    let answer = select(&reader,&Query::parse(&query).unwrap()).unwrap();
    assert_eq!(answer["coverage"]["analysis_status"],"bounded_partial");
    assert_eq!(answer["coverage"]["source_scan_complete"],false);
    assert_eq!(answer["coverage"]["unsearched"],"remaining_row_or_node_work");
    assert!(answer["coverage"]["reason"].as_str().unwrap().contains("allowance exhausted"));
}
