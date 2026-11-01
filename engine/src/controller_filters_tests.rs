// Authored UNRUN under the source-only grant.
use super::*;
fn observation()->Value {
    json!({"version":1,"framework_version":"8.1.4","root":"/fixture","status":"observed","controllers":[
        {"name":"OrdersController","superclass":"ApplicationController","status":"observed","entries":[
            {"kind":"before","filter":{"kind":"method","name":"authenticate","owner":"ApplicationController","source":{"path":"/fixture/app/controllers/application_controller.rb","line":3}},
                "if":[{"kind":"actions","mode":"only","actions":["create"]}],"unless":[],"inherited":true},
            {"kind":null,"filter":{"kind":"unavailable"},"if":null,"unless":null,"inherited":null},
            {"kind":"after","filter":{"kind":"proc","source":{"path":"/outside/eval.rb","line":8}},"if":[],"unless":[],"inherited":false}]}]})
}
fn context()->Value {
    json!({"schema_version":3,"facts":10,"links":7,"diagnostics":3,"fact_bytes":300,
        "limits":{"max_facts":20,"max_links":20,"max_entries":20,"max_diagnostics":10}})
}
#[test]
fn strict_runtime_family_normalizes_only_root_hints_and_retains_unknown_forward_rows() {
    let out=batch(&context(),&observation()).unwrap();
    let fact=&out["facts"][0];validate_fact(fact).unwrap();
    let rows=&fact["attributes"]["controller_filters"]["controller"]["entries"];
    assert_eq!(rows[0]["filter"]["source"]["path"],"app/controllers/application_controller.rb");
    assert!(rows[2]["filter"]["source"].is_null());
    assert_eq!(out["appended"]["facts"],1);
    assert_eq!(out["appended"]["links"],0);
    assert_eq!(applicability(&rows[0],"create"),"action_applicable_conditions_not_executed");
    assert_eq!(applicability(&rows[0],"index"),"excluded_by_recorded_action_condition");
    assert_eq!(applicability(&rows[1],"create"),"opaque_conditions_unknown");
    let except=json!({"if":[],"unless":[{"kind":"actions","mode":"except","actions":["index"]}]});
    assert_eq!(applicability(&except,"index"),"excluded_by_recorded_action_condition");
    assert_eq!(applicability(&except,"create"),"action_applicable_conditions_not_executed");
    let mut bad=fact.clone();bad["attributes"]["controller_filters"]["controller"]["entries"][0]["executed"]=json!(true);
    assert!(validate_fact(&bad).is_err());
    let mut bad=fact.clone();bad["path"]=json!("invented.rb");assert!(validate_fact(&bad).is_err());
    let mut used=context();used["limits"]["max_entries"]=json!(1);assert_eq!(batch(&used,&observation()).unwrap_err().code,"limit_exceeded");
}
