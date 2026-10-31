use super::*;

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
    assert_eq!(policy["arguments"][0]["source"],"DeliveryTimeout");
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
