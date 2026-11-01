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
    let conditional=save["rows"].as_array().unwrap().iter().find(|r|r["kind"]=="save_operation").unwrap();
    assert_eq!(conditional["condition"],"inside_branch_syntax");assert_eq!(conditional["branch"]["kind"],"if");
    assert!(conditional["branch"]["span"]["end_byte"].as_u64().unwrap()>conditional["span"]["end_byte"].as_u64().unwrap());
    let direct=parsed("::Order.create!");
    assert_eq!(direct["rows"][0]["condition"],"no_enclosing_branch_syntax");assert!(direct["rows"][0].get("branch").is_none());
    for code in ["::Order.all", "helper.prepare.save!", "Order.create!", "aliased.create!", "factory.call { ::Order.create! }", "def nested; ::Order.create!; end"] {
        let answer=parsed(code);
        assert!(!answer["rows"].as_array().unwrap().iter().any(|r|r["kind"]=="save_operation"),"{code}");
        assert_eq!(answer["scan_complete"],true);
        assert!(answer.get("unsearched").is_none());
    }
    let block=parsed("transaction do; ::Order.create!; end");
    assert!(block["rows"].as_array().unwrap().iter().any(|r|r["operation"]=="nested_scope" && r["reason"].as_str().unwrap().contains("whether, when and how often")));
}

#[test]
fn bounded_syntax_keeps_a_physical_prefix_and_names_the_first_unvisited_region() {
    let _lock=crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    let body=(0..220).map(|n|format!("::Order.create!(tag: {n})\n")).collect::<String>();
    let result=parsed(&body);let rows=result["rows"].as_array().unwrap();
    assert_eq!(rows.len(),200);assert_eq!(rows[0]["span"]["start_line"],2);assert_eq!(rows[199]["span"]["start_line"],201);
    assert_eq!(result["status"],"bounded_partial");assert_eq!(result["unsearched_from_byte"],result["stop_region"]["start_byte"]);
    assert!(result["unsearched_from_byte"].as_u64().unwrap()>=rows[199]["span"]["start_byte"].as_u64().unwrap());
    for (code,kind) in [("unless ready?; ::Order.create!; end","unless"),("while ready?; ::Order.create!; end","while"),("ready? && ::Order.create!","and")] {
        let answer=parsed(code);let row=answer["rows"].as_array().unwrap().iter().find(|r|r["kind"]=="save_operation").unwrap();assert_eq!(row["branch"]["kind"],kind);
    }
    let wide=(0..200).map(|n|format!("{}{n}()\n","a".repeat(1000))).collect::<String>();
    let limited=parsed(&wide);assert_eq!(limited["reason"],"analysis_result_exceeds_allowance");assert_eq!(limited["scan_complete"],false);
}

fn admission()->Value {json!({"schema_version":3,"facts":0,"links":0,"diagnostics":0,"fact_bytes":2,
    "limits":{"max_facts":100000,"max_links":500000,"max_entries":100000,"max_diagnostics":1000}})}
fn joined_fixture(models:usize,registries:usize,filter_line_delta:u64,check:impl FnOnce(&Reader,&str,&Value)) {
    let root=tempfile::tempdir().unwrap();let store=tempfile::tempdir().unwrap();
    let effects=(0..8).map(|_|format!("::ReceiptJob.perform_later('{}')\n","x".repeat(480))).collect::<String>();
    let text=format!("class OrdersController\n def create; ::Order.create!; ::ReceiptJob.perform_later(1); ::PaymentService.call; end\n def authenticate; :check; end\nend\nclass Order\n def queue_receipt\n{effects} end\nend\nclass ReceiptJob\n def perform; :job; end\nend\nclass PaymentService\n def call; :service; end\nend\n");
    std::fs::write(root.path().join("fixture.rb"),text).unwrap();
    let mut capture=crate::capture::capture(root.path(),&json!({})).unwrap();
    let method=|name:&str|capture["facts"].as_array().unwrap().iter().find(|f|f["name"]==name).unwrap().clone();
    let action=method("OrdersController#create");let filter=method("OrdersController#authenticate");let callback=method("Order#queue_receipt");
    let model=json!({"name":"Order","base_class":"Order","superclass":"ActiveRecord::Base","abstract":false,"table":"orders","primary_key":["id"],"inheritance_column":"type",
        "columns":{"status":"unavailable","entries":[]},"associations":{"status":"unavailable","entries":[]}});
    let batch=crate::model::batch(&admission(),&json!({"version":1,"active_record_version":"8.1.4","status":"observed","models":vec![model;models]})).unwrap();
    capture["facts"].as_array_mut().unwrap().extend(batch["facts"].as_array().unwrap().iter().cloned());
    let hint=|fact:&Value,delta:u64|json!({"kind":"method","name":fact["attributes"]["method_name"],"owner":fact["attributes"]["owner"],
        "source":{"path":root.path().join("fixture.rb").to_str().unwrap(),"line":fact["location"]["start_line"].as_u64().unwrap()+delta}});
    let entry=json!({"kind":"after","filter":hint(&callback,0),"if":[{"kind":"opaque"}],"unless":[],"inherited":false});
    let observed=json!({"name":"Order","superclass":"ActiveRecord::Base","save":{"status":"observed","entries":vec![entry;8]}});
    let batch=crate::callbacks::batch(&admission(),&json!({"version":1,"active_record_version":"8.1.4","root":root.path().to_str().unwrap(),"status":"observed","models":vec![observed;registries]})).unwrap();
    capture["facts"].as_array_mut().unwrap().extend(batch["facts"].as_array().unwrap().iter().cloned());
    let mut filter_hint=hint(&filter,if filter_line_delta==1 {1}else{0});
    if filter_line_delta==2 {filter_hint["source"]["path"]=json!(root.path().join("other.rb").to_str().unwrap());}
    let row=json!({"kind":"before","filter":filter_hint,"if":[],"unless":[],"inherited":true});
    let batch=crate::controller_filters::batch(&admission(),&json!({"version":1,"framework_version":"8.1.4","root":root.path().to_str().unwrap(),"status":"observed",
        "controllers":[{"name":"OrdersController","superclass":"ApplicationController","status":"observed","entries":[row]}]})).unwrap();
    capture["facts"].as_array_mut().unwrap().extend(batch["facts"].as_array().unwrap().iter().cloned());
    capture["facts"].as_array_mut().unwrap().push(route('a',"create"));
    capture["coverage"].as_array_mut().unwrap().retain(|row|row["family"]!="rails_routes");
    capture["coverage"].as_array_mut().unwrap().push(json!({"family":"rails_routes","status":"complete","scope":"Synthetic route witness"}));
    crate::store::publish(store.path(),&capture).unwrap();let reader=Reader::open(store.path(),None).unwrap();
    check(&reader,action["id"].as_str().unwrap(),&capture);
}

#[test]
fn compact_save_filter_witness_joins_related_boundaries_and_export_byte_edges() {
    let _lock=crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    joined_fixture(1,1,0,|reader,id,_| {
        let req=json!({"id":"a".repeat(64),"action":id,"limit":16});let answer=select(reader,&Query::parse(&req).unwrap()).unwrap();
        assert_eq!(answer["items"][0]["witness"]["name"],"OrdersController#authenticate");
        assert_eq!(answer["filters"]["status"],"captured");
        let contribution=&answer["items"][1]["save_contribution"];
        assert_eq!(contribution["status"],"potential_save_callback_contribution");assert_eq!(contribution["callbacks"].as_array().unwrap().len(),4);
        assert_eq!(contribution["summaries_omitted"],4);assert_eq!(contribution["callbacks"][0]["effects"]["returned_count"],8);
        assert_eq!(contribution["callbacks"][0]["witness"]["name"],"Order#queue_receipt");
        assert_eq!(contribution["callbacks"][0]["conditions"]["if"]["kinds"]["opaque"],1);
        let encoded=serde_json::to_string(contribution).unwrap();assert!(!encoded.contains("source_excerpt"));assert!(!encoded.contains(&"x".repeat(480)));
        let related=answer["items"].as_array().unwrap().iter().find(|r|r["related_candidate"]["name"]=="PaymentService#call").unwrap();
        assert_eq!(related["receiver_framework_role"],"unknown");assert_eq!(related["followup"]["family"],"handoff");
        let export=json!({"id":"a".repeat(64),"action":id,"family":"export","limit":1,"cursor":recorded_domain::cursor(&reader.generation,&json!(["passage","a".repeat(64),id,"export"]),(1,0)).unwrap(),"max_bytes":32768});
        let result=select(reader,&Query::parse(&export).unwrap()).unwrap();
        let text=result["report"].as_str().unwrap();let rows:Value=serde_json::from_str(text.lines().skip(3).collect::<Vec<_>>().join("\n").as_str()).unwrap();assert_eq!(rows,result["items"]);
        assert!(schema::encoded_bytes(&Envelope{ok:true,result:&result},32767).is_ok());
        let mut original_route=result["route"].clone();original_route["root"]=result["root"].clone();
        let route_wire=schema::encoded_bytes(&Envelope{ok:true,result:&original_route},32768).unwrap();
        let budget=route_wire+4096+128;
        assert!(schema::encoded_bytes(&Envelope{ok:true,result:&result},32768).unwrap()>budget);
        let mut refuses=export.clone();refuses["max_bytes"]=json!(budget);
        assert_eq!(select(reader,&Query::parse(&refuses).unwrap()).unwrap_err().code,"limit_exceeded");
        let small=json!({"id":"a".repeat(64),"action":id,"max_bytes":1024});assert_eq!(select(reader,&Query::parse(&small).unwrap()).unwrap_err().code,"limit_exceeded");
        let mut work=Work::new();for _ in 0..100000 {assert!(work.shared.labels(0));}
        assert_eq!(source_analysis(reader,reader.stored_fact(id).unwrap(),&mut work).unwrap_err().code,"limit_exceeded");
        let mut work=Work::new();for _ in 0..16 {assert!(work.shared.source_attempt());}
        assert_eq!(source_analysis(reader,reader.stored_fact(id).unwrap(),&mut work).unwrap_err().code,"limit_exceeded");
        let mut work=Work::new();assert!(work.shared.source_bytes(1024*1024));
        assert_eq!(source_analysis(reader,reader.stored_fact(id).unwrap(),&mut work).unwrap_err().code,"limit_exceeded");
        let mut work=Work::new();assert!(work.shared.metadata(&json!("m".repeat(1800000)),3).is_err());
        assert_eq!(select_with_work(reader,&Query::parse(&req).unwrap(),work).unwrap_err().code,"limit_exceeded");
    });
    for (models,registries,delta) in [(2,1,0),(1,2,0),(1,1,1),(1,1,2)] {
        joined_fixture(models,registries,delta,|reader,id,_| {
            let result=select(reader,&Query::parse(&json!({"id":"a".repeat(64),"action":id,"limit":16})).unwrap()).unwrap();
            if delta>0 {assert!(result["items"][0]["witness"].is_null());}
            else {assert_eq!(result["items"][1]["save_contribution"]["status"],"qualified_target_unavailable");}
        });
    }
}

#[test]
fn local_source_size_unknown_keeps_filters_but_invalid_source_does_not_pass() {
    let _lock=crate::CAPTURE_FIXTURE_LOCK.lock().unwrap();
    joined_fixture(1,1,0,|reader,id,capture| {
        let mut large=capture.clone();let file=&mut large["files"][0];let content=format!("{}\n#{}",file["content"].as_str().unwrap(),"x".repeat(262144));
        file["bytes"]=json!(content.len());file["sha256"]=json!(schema::digest(content.as_bytes()));file["content"]=json!(content);
        let store=tempfile::tempdir().unwrap();crate::store::publish(store.path(),&large).unwrap();let saved=Reader::open(store.path(),None).unwrap();
        let answer=select(&saved,&Query::parse(&json!({"id":"a".repeat(64),"action":id})).unwrap()).unwrap();
        assert_eq!(answer["coverage"]["analysis_status"],"unknown");assert_eq!(answer["coverage"]["reason"],"saved_file_exceeds_source_allowance");
        assert_eq!(answer["items"][0]["kind"],"controller_filter");assert_eq!(answer["coverage"]["source_scan_complete"],false);
        let invalid=json!({"kind":"method","location":{"start_byte":0,"end_byte":9999999}});
        assert_eq!(source::analyze(&invalid,"def x; end").unwrap_err().code,"invalid_snapshot");
        let oversized=format!("def x\n#{}\nend","x".repeat(262144));let fact=json!({"location":{"start_byte":0,"end_byte":oversized.len()}});
        assert_eq!(source::analyze(&fact,&oversized).unwrap()["reason"],"selected_declaration_exceeds_source_allowance");
        // A valid Reader plus missing canonical source metadata must refuse, not
        // turn a snapshot error into a local empty/complete source result.
        let mut missing=reader.stored_fact(id).unwrap().clone();missing["path"]=json!("missing.rb");
        assert_eq!(source_analysis(reader,&missing,&mut Work::new()).unwrap_err().code,"invalid_snapshot");
        let mut late=capture.clone();
        for n in 0..8 {late["files"].as_array_mut().unwrap().insert(0,json!({"path":format!("a{n}.rb"),"encoding":"UTF-8","content":"","bytes":0,"sha256":schema::digest(b"")}));}
        let store=tempfile::tempdir().unwrap();crate::store::publish(store.path(),&late).unwrap();let late=Reader::open(store.path(),None).unwrap();
        let mut work=Work::new();assert!(work.shared.facts(19999));
        let analysis=source_analysis(&late,late.stored_fact(id).unwrap(),&mut work).unwrap();
        assert_eq!(analysis["scan_complete"],true);assert!(work.comparisons>=9);
    });
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
    assert_eq!(first["filters"]["status"],"not_captured");
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
