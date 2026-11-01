// Authored UNRUN. Actual capture/parser/store execution belongs to Root.
use super::*;
fn parsed(body:&str)->Value {
    let content=format!("def action\n{body}\nend\n");
    let declaration=json!({"kind":"method","location":{"start_byte":0,"end_byte":content.len()}});
    crate::capture::parser_worker("passage-source-test",move||source::analyze(&declaration,&content)).unwrap()
}
#[test]
fn selected_save_read_helper_and_nested_scopes_never_share_a_generic_save_branch() {
    let _lock=crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let save=parsed("::Order.create!(name: 'x') if allowed?\n::ReceiptJob.perform_later(1)");
    assert_eq!(save["rows"].as_array().unwrap().iter().filter(|r|r["kind"]=="save_operation").count(),1);
    assert!(save["rows"].as_array().unwrap().iter().any(|r|r["kind"]=="async_boundary"));
    for code in ["::Order.all", "helper.prepare.save!", "Order.create!", "aliased.create!", "factory.call { ::Order.create! }", "def nested; ::Order.create!; end"] {
        let answer=parsed(code);
        assert!(!answer["rows"].as_array().unwrap().iter().any(|r|r["kind"]=="save_operation"),"{code}");
        assert_eq!(answer["scan_complete"],true);
        assert!(answer.get("unsearched").is_none());
    }
}
fn route(id:char,action:&str)->Value {
    json!({"id":id.to_string().repeat(64),"kind":"route","name":format!("orders#{action}"),"path":null,"location":null,"evidence":"runtime",
        "attributes":{"controller":"orders","action":action,"route_path":"/orders","verb":"GET","route_constraints":{"status":"unknown"}},"links":[]})
}
#[test]
fn public_selection_pagination_export_and_saved_source_remain_action_specific() {
    let _lock=crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let root=tempfile::tempdir().unwrap();let store=tempfile::tempdir().unwrap();
    let path=root.path().join("orders_controller.rb");
    std::fs::write(&path,"class OrdersController\n def create; ::Order.create!; ::ReceiptJob.perform_later(1); end\n def index; ::Order.all; end\n def show; :one; end\n def show; :two; end\nend\n").unwrap();
    let mut captured=crate::capture::capture(root.path(),&json!({})).unwrap();
    let methods=captured["facts"].as_array().unwrap().iter().filter(|f|f["kind"]=="method").cloned().collect::<Vec<_>>();
    let create=methods.iter().find(|f|f["attributes"]["method_name"]=="create").unwrap()["id"].as_str().unwrap().to_owned();
    let index=methods.iter().find(|f|f["attributes"]["method_name"]=="index").unwrap()["id"].as_str().unwrap().to_owned();
    captured["facts"].as_array_mut().unwrap().extend([route('a',"create"),route('b',"index"),route('c',"show")]);
    captured["coverage"].as_array_mut().unwrap().retain(|row|row["family"]!="rails_routes");
    captured["coverage"].as_array_mut().unwrap().push(json!({"family":"rails_routes","status":"complete","scope":"Synthetic explicit route fixture"}));
    crate::store::publish(store.path(),&captured).unwrap();
    let reader=Reader::open(store.path(),None).unwrap();
    let request=json!({"id":"a".repeat(64),"action":create,"limit":1});
    let first=select(&reader,&Query::parse(&request).unwrap()).unwrap();
    assert_eq!(first["items"][0]["evidence"]["kind"],"save_operation");
    assert_eq!(first["items"][0]["save_contribution"]["status"],"qualified_target_unavailable");
    assert!(first["next_cursor"].is_string());
    let mut next=request.clone();next["cursor"]=first["next_cursor"].clone();
    let second=select(&reader,&Query::parse(&next).unwrap()).unwrap();
    assert_eq!(second["items"][0]["evidence"]["kind"],"async_boundary");
    assert!(second["next_cursor"].is_null());
    let read=json!({"id":"b".repeat(64),"action":index,"family":"export"});
    let page=select(&reader,&Query::parse(&read).unwrap()).unwrap();
    assert!(!page["report"].as_str().unwrap().contains("save_contribution"));
    next["action"]=json!(index);assert!(select(&reader,&Query::parse(&next).unwrap()).is_err());
    let choose=select(&reader,&Query::parse(&json!({"id":"c".repeat(64),"limit":1})).unwrap()).unwrap();
    assert_eq!(choose["route"]["status"],"ambiguous_static_candidates");
    assert!(choose["selected_action"].is_null());assert_eq!(choose["items"],json!([]));
    assert!(choose["next_cursor"].is_string());
    let choices=select(&reader,&Query::parse(&json!({"id":"c".repeat(64),"limit":1,"cursor":choose["next_cursor"]})).unwrap()).unwrap();
    assert!(choices["next_cursor"].is_null());
    assert_ne!(choose["route"]["candidates"][0]["fact"]["id"],choices["route"]["candidates"][0]["fact"]["id"]);
    std::fs::write(&path,"class ChangedCurrent; end\n").unwrap();
    let changed=crate::capture::capture(root.path(),&json!({})).unwrap();crate::store::publish(store.path(),&changed).unwrap();
    assert!(reader.source(&create).unwrap()["content"].as_str().unwrap().contains("::Order.create!"));
    assert_eq!(select(&reader,&Query::parse(&request).unwrap()).unwrap()["generation"],reader.generation);
    let tiny=json!({"id":"a".repeat(64),"action":create,"max_bytes":32});
    assert_eq!(select(&reader,&Query::parse(&tiny).unwrap()).unwrap_err().code,"limit_exceeded");
}
