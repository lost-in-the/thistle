//! AUTHORED UNRUN. These tests become registered only when Root admits the
//! parent module. No compiler/native/store execution occurred in source phase.
use super::*;

fn file(path: &str, content: &str) -> Value {
    json!({"path":path,"content":content,"bytes":content.len(),"sha256":schema::digest(content.as_bytes()),"encoding":"UTF-8"})
}
fn fact(seed:&str,name:&str,path:&str,content:&str)->Value {
    json!({"id":schema::digest(seed.as_bytes()),"kind":"class","name":name,"path":path,
        "location":{"start_byte":0,"end_byte":content.len(),"start_line":1,"end_line":1},
        "evidence":"static","attributes":{"name_resolution":"lexical","declaration_name":name,"lexical_scope":[]},"links":[]})
}
fn capture(seed:&str,content:&str)->Value {
    json!({"root_id":schema::digest(seed.as_bytes()),"producer":{"name":"public-los151-known-answer","private_canary":"MUST_NOT_LEAK"},
        "files":[file("app/models/order.rb",content)],"facts":[fact(seed,"Order","app/models/order.rb",content)],
        "coverage":[{"family":"source_inventory","status":"complete","scope":"public los151 regular source files","reason":null},
            {"family":"ruby_declarations","status":"complete","scope":"explicit Ruby declarations in public source","reason":null}],"diagnostics":[]})
}
fn readers(a:&Value,b:&Value)->(tempfile::TempDir,Reader,Reader){
    let dir=tempfile::tempdir().unwrap();
    let ga=crate::store::publish(dir.path(),a).unwrap()["generation"].as_str().unwrap().to_owned();
    let gb=crate::store::publish(dir.path(),b).unwrap()["generation"].as_str().unwrap().to_owned();
    let left=Reader::open(dir.path(),Some(&ga)).unwrap();
    let right=Reader::open(dir.path(),Some(&gb)).unwrap();
    (dir,left,right)
}
fn request(name:&str)->Value {json!({"selection":{"kind":"class","name":name}})}
fn run(a:&Reader,b:&Reader,input:Value)->Value{select(a,b,&Query::parse(&input).unwrap()).unwrap()}
fn link(target:&str)->Value{json!({"relation":"inherits","target":target,"resolution":"unresolved"})}

#[test]
fn changed_and_unchanged_are_semantic_and_both_physical_identities_survive(){
    let a=capture("A","class Order < Base; end");
    let mut b=capture("B","class Order < NewBase; end");
    let mut a=a;a["facts"][0]["links"]=json!([link("Base")]);
    b["facts"][0]["links"]=json!([link("NewBase")]);
    b["facts"][0]["attributes"]["declaration_name"]=json!("::Order");
    let (_dir,left,right)=readers(&a,&b);
    let out=run(&left,&right,request("Order"));
    for component in ["source","metadata","relationships"] {assert_eq!(out["comparison"][component]["status"],"changed", "{component}");}
    assert_eq!(out["comparison"]["status"],"changed");
    assert_eq!(out["comparison"]["line_diff"]["status"],"unavailable");
    assert_eq!(out["pair"]["left"]["generation"],left.generation);
    assert_eq!(out["matching"]["right"]["identities"][0]["id"],b["facts"][0]["id"]);
    assert_eq!(out["matching"]["left"]["identities"][0]["location"]["start_line"],1);
    assert_eq!(out["pair"]["left"]["commit_provenance"],"unavailable");
    assert!(!out.to_string().contains("MUST_NOT_LEAK"));

    // Saved IDs and physical paths are explicitly not cross-generation keys.
    let mut b=capture("different-id","class Order < Base; end");
    b["facts"][0]["links"]=a["facts"][0]["links"].clone();
    b["files"][0]["path"]=json!("moved/order.rb");b["facts"][0]["path"]=json!("moved/order.rb");
    let (_dir,left,right)=readers(&a,&b);
    let out=run(&left,&right,request("Order"));
    assert_eq!(out["comparison"]["status"],"unchanged");
    assert_eq!(out["matching"]["right"]["identities"][0]["path"],"moved/order.rb");
}

#[test]
fn absence_requires_complete_matching_scope_and_not_a_loaded_registry(){
    let a=capture("A","class Order; end");let mut b=capture("B","class Order; end");
    b["facts"]=json!([]);b["files"]=json!([]);
    for (mutation,expected) in [("none","removed"),("partial","uncomparable"),("scope","uncomparable"),("missing","uncomparable"),("duplicate","uncomparable"),("unknown_policy","uncomparable")] {
        let mut b=b.clone();
        match mutation {
            "partial"=>b["coverage"][0]["status"]=json!("partial"),
            "scope"=>b["coverage"][0]["scope"]=json!("a different admitted file scope"),
            "missing"=>{b["coverage"].as_array_mut().unwrap().pop();},
            "duplicate"=>{let row=b["coverage"][0].clone();b["coverage"].as_array_mut().unwrap().push(row);},_=>{},
        }
        if mutation=="unknown_policy"{b["coverage"][0]["new_policy"]=json!("not interpreted");}
        let (_dir,left,right)=readers(&a,&b);
        assert_eq!(run(&left,&right,request("Order"))["comparison"]["status"],expected,"{mutation}");
        let reverse=run(&right,&left,request("Order"));
        assert_eq!(reverse["comparison"]["status"],if expected=="removed"{"added"}else{expected});
        assert!(reverse["comparison"]["source"].get("previous_lines").is_none_or(Value::is_null));
    }
    let (_dir,left,right)=readers(&a,&b);
    assert_eq!(run(&left,&right,json!({"selection":{"kind":"rails_model","name":"Order"}}))["comparison"]["status"],"uncomparable");
}

#[test]
fn runtime_model_table_change_and_ordinal_shift_never_become_removed_plus_added(){
    let mut observation:Value=serde_json::from_str(include_str!("../tests/fixtures/models.json")).unwrap();
    let context=json!({"limits":{"max_facts":100,"max_links":100,"max_entries":100,"max_diagnostics":10},
        "facts":0,"links":0,"diagnostics":0,"fact_bytes":2});
    let batch=crate::model::batch(&context,&observation).unwrap();
    let mut a=capture("A","class Order; end");a["facts"]=batch["facts"].clone();
    let mut other=observation["models"][0].clone();other["name"]=json!("Unrelated");other["base_class"]=json!("Unrelated");
    observation["models"].as_array_mut().unwrap().insert(0,other);
    observation["models"][1]["table"]=json!("archived_orders");
    let mut b=capture("B","class Order; end");b["facts"]=crate::model::batch(&context,&observation).unwrap()["facts"].clone();
    let (_dir,left,right)=readers(&a,&b);
    let out=run(&left,&right,json!({"selection":{"kind":"rails_model","name":"Order"}}));
    assert_eq!(out["matching"]["left"]["count"],1);assert_eq!(out["matching"]["right"]["count"],1);
    assert_eq!(out["comparison"]["status"],"changed");
    assert_eq!(out["comparison"]["change_kind"],"metadata_changed_source_unknown");
    assert_eq!(out["comparison"]["source"]["status"],"uncomparable");
    assert_ne!(out["matching"]["left"]["identities"][0]["id"],out["matching"]["right"]["identities"][0]["id"]);
}

#[test]
fn recognized_link_encoding_and_physical_offset_changes_preserve_semantic_relationships(){
    let mut a=capture("A","class Order; User.find; end");let mut b=capture("B","class Order; User.find; end");
    a["facts"][0]["links"]=json!([{"relation":"calls","target":"find","resolution":"unresolved","attributes":{"thistle_call":{
        "version":1,"receiver":{"kind":"constant","name":"User","omitted_limit":false},"safe_navigation":false,
        "call_location":{"start_byte":13,"end_byte":22,"start_line":1,"end_line":1},
        "receiver_location":{"start_byte":13,"end_byte":17,"start_line":1,"end_line":1}}}}]);
    b["facts"][0]["links"]=json!([{"relation":"calls","target":"find","resolution":"unresolved","attributes":{"thistle_call":{
        "version":2,"data":["constant","User",false,false,[13,22,1,1],[13,17,1,1]]}}}]);
    // Missing schema_version is legacy schema 1: compact v2 is opaque there,
    // so it must not compare equal to recognized v1 metadata.
    let (_dir,left,right)=readers(&a,&b);
    assert_eq!(run(&left,&right,request("Order"))["comparison"]["relationships"]["status"],"changed");
    for version in [2,3] {
        a["schema_version"]=json!(version);b["schema_version"]=json!(version);
        let (_dir,left,right)=readers(&a,&b);
        assert_eq!(run(&left,&right,request("Order"))["comparison"]["relationships"]["status"],"unchanged");
    }
    // Schema-3 v2 extension extras must survive, including a key also used by
    // the older v1 contract. They are not heuristically discarded as offsets.
    b["facts"][0]["links"][0]["attributes"]["thistle_call"]["receiver"]=json!("new opaque evidence");
    let (_dir,left,right)=readers(&a,&b);
    assert_eq!(run(&left,&right,request("Order"))["comparison"]["relationships"]["status"],"changed");
}

#[test]
fn full_typed_name_domain_not_prefix_or_first_candidate(){
    let mut a=capture("A","class Order; end");let b=capture("B","class Order; end");
    let mut other=a["facts"][0].clone();other["id"]=json!(schema::digest(b"prefix"));other["name"]=json!("OrderLine");
    a["facts"].as_array_mut().unwrap().push(other);
    let (_dir,left,right)=readers(&a,&b);
    assert_eq!(run(&left,&right,request("Order"))["matching"]["left"]["count"],1);
    assert_eq!(run(&left,&right,request("order"))["matching"]["left"]["count"],0);
    let mut duplicate=a["facts"][0].clone();duplicate["id"]=json!(schema::digest(b"duplicate"));
    a["facts"].as_array_mut().unwrap().push(duplicate);
    let (_dir,left,right)=readers(&a,&b);
    let out=run(&left,&right,request("Order"));assert_eq!(out["comparison"]["status"],"ambiguous");
    assert_eq!(out["matching"]["left"]["count"],2);
    let input=json!({"selection":{"kind":"class","name":"Order"},"family":"references"});
    assert_eq!(select(&left,&right,&Query::parse(&input).unwrap()).unwrap_err().code,"ambiguous_comparison");
    a["facts"].as_array_mut().unwrap().pop();a["facts"][0]["attributes"]["name_resolution"]=json!("unresolved_relative_path");
    let (_dir,left,right)=readers(&a,&b);
    assert_eq!(run(&left,&right,request("Order"))["comparison"]["status"],"uncomparable");
}

#[test]
fn only_local_registry_ordinal_is_dropped_and_default_presence_and_order_survive(){
    let data=json!({"kind":"rails_model","attributes":{"model":{"name":"Order","ordinal":0,
        "columns":{"entries":[{"name":"a","null":false,"default":null},{"name":"b","default_present":false}]}}}});
    let mut changed=data.clone();changed["attributes"]["model"]["ordinal"]=json!(59);
    let digest=|fact:&Value|metadata_digest(fact,Kind::RailsModel,&mut RequestWork::default()).unwrap();
    assert_eq!(digest(&data),digest(&changed));
    changed["attributes"]["model"]["columns"]["entries"][0].as_object_mut().unwrap().remove("default");
    assert_ne!(digest(&data),digest(&changed));
    changed=data.clone();changed["attributes"]["model"]["columns"]["entries"].as_array_mut().unwrap().reverse();
    assert_ne!(digest(&data),digest(&changed));
    changed=data.clone();changed["attributes"]["model"]["columns"]["entries"][0]["null"]=Value::Null;
    assert_ne!(digest(&data),digest(&changed));
    let callbacks=json!({"attributes":{"callbacks":{"ordinal":0,"save":{"entries":[{"ordinal":0,"filter":"one"},{"ordinal":1,"filter":"two"}]}}}});
    let mut reversed=callbacks.clone();reversed["attributes"]["callbacks"]["save"]["entries"].as_array_mut().unwrap().reverse();
    assert_ne!(metadata_digest(&callbacks,Kind::RailsSaveCallbacks,&mut RequestWork::default()).unwrap(),
        metadata_digest(&reversed,Kind::RailsSaveCallbacks,&mut RequestWork::default()).unwrap());
}

#[test]
fn metadata_only_is_independent_and_selected_source_is_actually_verified(){
    let a=capture("A","class Order; end");let mut b=capture("B","class Order; end");
    b["facts"][0]["attributes"]["declaration_name"]=json!("::Order");
    let (dir,left,right)=readers(&a,&b);
    let out=run(&left,&right,request("Order"));assert_eq!(out["comparison"]["change_kind"],"metadata_only");
    assert_eq!(out["comparison"]["source"]["status"],"unchanged");
    // Both manifests still claim the same digest. A corrupt blob must refuse,
    // rather than treating equal manifest metadata as integrity evidence.
    std::fs::write(dir.path().join("blobs").join(a["files"][0]["sha256"].as_str().unwrap()),"corrupt").unwrap();
    assert_eq!(select(&left,&right,&Query::parse(&request("Order")).unwrap()).unwrap_err().code,"invalid_snapshot");
}

#[test]
fn span_equality_ignores_unrelated_file_bytes_and_validates_physical_coordinates(){
    let a=capture("A","class Order; end");let mut b=capture("B","class Order; end; unrelated");
    b["facts"][0]["location"]["end_byte"]=a["facts"][0]["location"]["end_byte"].clone();
    let (_dir,left,right)=readers(&a,&b);
    assert_eq!(run(&left,&right,request("Order"))["comparison"]["source"]["status"],"unchanged");
    // Publish requires valid capture coordinates; mutate an already opened
    // Reader only in this private unit test to test the selected-source defense.
    let (_dir,mut left,right)=readers(&a,&b);left.facts[0]["location"]["end_line"]=json!(2);
    assert_eq!(select(&left,&right,&Query::parse(&request("Order")).unwrap()).unwrap_err().code,"invalid_snapshot");
}

fn reference_pair()->(tempfile::TempDir,Reader,Reader){
    let mut a=capture("A","class Order; end");let mut b=capture("B","class Order; end");
    for (capture,seed) in [(&mut a,"left"),(&mut b,"right")] {
        let content="class ReceiptJob; end";
        let mut job=fact(seed,"ReceiptJob","app/jobs/receipt_job.rb",content);
        job["links"]=json!([link("Order"),link("OrderLine"),link("Order")]);
        capture["facts"].as_array_mut().unwrap().push(job);
        capture["files"].as_array_mut().unwrap().push(file("app/jobs/receipt_job.rb",content));
    }
    readers(&a,&b)
}
fn ref_request(limit:usize,cursor:Value)->Value {json!({"selection":{"kind":"class","name":"Order"},
    "family":"references","direction":"incoming","limit":limit,"cursor":cursor})}

#[test]
fn exact_work_positions_preserve_prefix_across_both_sides_and_current_changes(){
    let (dir,left,right)=reference_pair();
    crate::store::publish(dir.path(),&capture("C","class CURRENT; end")).unwrap();
    let first=run(&left,&right,ref_request(1,Value::Null));
    assert_eq!(first["items"][0]["link_index"],0);
    assert_eq!(first["cost"]["root_fact_visits"],4);
    let p=position(&left,&right,&Query::parse(&ref_request(1,first["next_cursor"].clone())).unwrap()).unwrap();
    let job=left.facts.iter().position(|f|f["name"]=="ReceiptJob").unwrap();
    assert_eq!(p,Position{side:0,fact:job,link:2});
    let mut cursor=Value::Null;let mut seen=Vec::new();
    for _ in 0..8 {
        let out=run(&left,&right,ref_request(1,cursor));
        assert_eq!(out["cost"]["root_fact_visits"],4);
        for row in out["items"].as_array().unwrap(){seen.push((row["side"].as_str().unwrap().to_owned(),row["link_index"].as_u64().unwrap()));}
        cursor=out["next_cursor"].clone();if cursor.is_null(){assert_eq!(out["scan"]["complete"],true);break;}
    }
    assert!(cursor.is_null());assert_eq!(seen,vec![("left".into(),0),("left".into(),2),("right".into(),0),("right".into(),2)]);
    assert_eq!(first["pair"]["right"]["generation"],right.generation);
    for modified in [ref_request(2,first["next_cursor"].clone()),json!({"selection":{"kind":"class","name":"ReceiptJob"},"family":"references","limit":1,"cursor":first["next_cursor"]})] {
        assert_eq!(select(&left,&right,&Query::parse(&modified).unwrap()).unwrap_err().code,"invalid_input");
    }
    assert_eq!(select(&right,&left,&Query::parse(&ref_request(1,first["next_cursor"].clone())).unwrap()).unwrap_err().code,"invalid_input");
}

#[test]
fn shared_allowance_refuses_incomplete_uniqueness_and_zero_progress_without_reset(){
    let (_dir,left,right)=reference_pair();let input=ref_request(1,Value::Null);let q=Query::parse(&input).unwrap();
    let mut work=RequestWork::default();assert!(work.facts(19_997));
    assert_eq!(select_with_work(&left,&right,&q,&mut work).unwrap_err().code,"limit_exceeded");
    // Four root visits consume the rest. References cannot start; no false
    // complete page or cursor pointing at the same position may be returned.
    let mut work=RequestWork::default();assert!(work.facts(19_996));
    assert_eq!(select_with_work(&left,&right,&q,&mut work).unwrap_err().code,"limit_exceeded");
    let mut work=RequestWork::default();assert!(work.links(49_999));
    let out=select_with_work(&left,&right,&q,&mut work).unwrap();
    assert_eq!(out["items"].as_array().unwrap().len(),1);
    assert_eq!(out["scan"]["complete"],false);
    let job=left.facts.iter().position(|f|f["name"]=="ReceiptJob").unwrap();
    assert_eq!(position(&left,&right,&Query::parse(&ref_request(1,out["next_cursor"].clone())).unwrap()).unwrap(),Position{side:0,fact:job,link:1});
    assert!(!work.links(1));
}

#[test]
fn actual_envelope_and_byte_cut_cannot_discard_the_first_witness(){
    let (_dir,left,right)=reference_pair();
    let all=run(&left,&right,ref_request(8,Value::Null));
    let bytes=serde_json::to_vec(&json!({"ok":true,"result":all})).unwrap().len();
    assert!(fits(&all,bytes).unwrap());assert!(!fits(&all,bytes-1).unwrap());
    let mut input=ref_request(8,Value::Null);input["max_bytes"]=json!(bytes-1);
    let out=run(&left,&right,input.clone());
    assert!(out["items"].as_array().unwrap().len()<4);assert!(!out["items"].as_array().unwrap().is_empty());
    assert_eq!(out["scan"]["reason"],"byte_limit");
    let consumed=out["items"].as_array().unwrap().len();
    input["cursor"]=out["next_cursor"].clone();
    let next=run(&left,&right,input);
    assert_eq!(next["items"][0],all["items"][consumed]);
    let tiny=json!({"selection":{"kind":"class","name":"Order"},"max_bytes":1});
    assert_eq!(select(&left,&right,&Query::parse(&tiny).unwrap()).unwrap_err().code,"limit_exceeded");
}

#[test]
fn typed_request_and_cursor_positions_refuse_malformed_inputs(){
    for input in [json!({}),json!({"selection":{"kind":"route","name":"Order"}}),
        json!({"selection":{"kind":"class","name":""}}),json!({"selection":{"kind":"rails_job_mail","name":"ReceiptJob"}}),
        json!({"selection":{"kind":"class","name":"Order"},"limit":17}),
        json!({"selection":{"kind":"class","name":"Order"},"max_bytes":65537})] {assert!(Query::parse(&input).is_err());}
    let (_dir,left,right)=reference_pair();let mut input=ref_request(1,Value::Null);
    let q=Query::parse(&input).unwrap();
    input["cursor"]=token(&left,&right,&q,Position{side:0,fact:99,link:0}).unwrap();
    assert_eq!(select(&left,&right,&Query::parse(&input).unwrap()).unwrap_err().code,"invalid_input");
}

fn changed_field<'a>(out:&'a Value,path:&str)->&'a Value{
    out["comparison"]["metadata"]["evidence"]["items"].as_array().unwrap().iter()
        .find(|row|row["path"]==path).unwrap_or_else(||panic!("Missing concrete changed field {path}: {out}"))
}

#[test]
fn changed_fields_explain_typed_presence_defaults_and_opaque_values_with_pinned_context(){
    let mut a=capture("A","class Order; end");let mut b=capture("B","class Order; end");
    a["facts"][0]["attributes"]["saved"]=json!({"default":false,"null_to_missing":null,
        "ordered":["first","second"],"opaque":{"version":99,"flag":false},"a/b~":0});
    b["facts"][0]["attributes"]["saved"]=json!({"default":true,"missing_to_null":null,
        "ordered":["second","first"],"opaque":{"version":99,"flag":null},"a/b~":1});
    let (_dir,left,right)=readers(&a,&b);let mut input=request("Order");input["limit"]=json!(16);
    let out=run(&left,&right,input);
    let row=changed_field(&out,"/saved/default");
    assert_eq!(row["before"],json!({"present":true,"value_status":"shown","value":false}));
    assert_eq!(row["after"]["value"],true);
    let row=changed_field(&out,"/saved/missing_to_null");
    assert_eq!(row["before"],json!({"present":false,"value_status":"missing"}));
    assert_eq!(row["after"],json!({"present":true,"value_status":"shown","value":null}));
    assert_eq!(changed_field(&out,"/saved/null_to_missing")["after"]["present"],false);
    assert_eq!(changed_field(&out,"/saved/ordered/0")["before"]["value"],"first");
    assert_eq!(changed_field(&out,"/saved/ordered/0")["after"]["value"],"second");
    assert_eq!(changed_field(&out,"/saved/opaque/flag")["after"]["value"],Value::Null);
    assert_eq!(changed_field(&out,"/saved/a~1b~0")["after"]["value"],1);
    assert_eq!(out["comparison"]["metadata"]["evidence"]["scan_complete"],true);
    assert_eq!(out["comparison"]["metadata"]["evidence"]["context"]["left"]["generation"],left.generation);
    assert_eq!(out["comparison"]["metadata"]["evidence"]["followups"]["right"]["id"],b["facts"][0]["id"]);
    assert_eq!(out["pair"]["left"]["root_id_binding"],"unvalidated_repository_ref_commit_tree");
}

fn field_envelope()->Value{json!({"comparison":{"metadata":{"evidence":{"items":[]}}}})}

#[test]
fn field_walk_drops_only_outer_registry_ordinal_and_preserves_registration_positions(){
    let a=json!({"callbacks":{"ordinal":0,"save":{"entries":[{"ordinal":0,"filter":"first"},{"ordinal":1,"filter":"second"}]}}});
    let b=json!({"callbacks":{"ordinal":9,"save":{"entries":[{"ordinal":1,"filter":"second"},{"ordinal":0,"filter":"first"}]}}});
    let mut out=field_envelope();let mut work=RequestWork::default();
    let stopped=FieldWriter{out:&mut out,work:&mut work,kind:Kind::RailsSaveCallbacks,limit:16,max_bytes:65536}
        .walk(Some(&a),Some(&b),&mut String::new(),0).unwrap();
    assert!(stopped.is_none());assert_eq!(out["comparison"]["metadata"]["evidence"]["items"].as_array().unwrap().len(),4);
    assert_eq!(changed_field(&out,"/callbacks/save/entries/0/ordinal")["after"]["value"],1);
    assert_eq!(changed_field(&out,"/callbacks/save/entries/0/filter")["before"]["value"],"first");
    assert!(!out["comparison"]["metadata"]["evidence"]["items"].as_array().unwrap().iter().any(|v|v["path"]=="/callbacks/ordinal"));
}

#[test]
fn oversized_values_are_explicitly_omitted_and_later_small_fields_are_not_silently_lost(){
    let mut a=capture("A","class Order; end");let mut b=capture("B","class Order; end");
    a["facts"][0]["attributes"]["a_large"]=json!("x".repeat(4096));
    b["facts"][0]["attributes"]["a_large"]=json!("y".repeat(4096));
    a["facts"][0]["attributes"]["b_small"]=json!(false);b["facts"][0]["attributes"]["b_small"]=Value::Null;
    let (_dir,left,right)=readers(&a,&b);let out=run(&left,&right,request("Order"));
    let row=changed_field(&out,"/a_large");
    assert_eq!(row["before"]["value_status"],"omitted");assert!(row["before"].get("value").is_none());
    assert_eq!(changed_field(&out,"/b_small")["after"]["value"],Value::Null);
    assert_eq!(out["comparison"]["metadata"]["evidence"]["status"],"partial");
    assert_eq!(out["comparison"]["metadata"]["evidence"]["scan_complete"],true);
    assert_eq!(out["comparison"]["metadata"]["evidence"]["unsearched"],false);
    assert_eq!(out["comparison"]["metadata"]["evidence"]["followups"]["left"]["operation"],"fact");
}

#[test]
fn changed_field_row_and_work_cuts_preserve_admitted_prefix_with_explicit_unsearched_state(){
    let mut a=capture("A","class Order; end");let mut b=capture("B","class Order; end");
    a["facts"][0]["attributes"]["a"]=json!(false);a["facts"][0]["attributes"]["b"]=json!(0);
    b["facts"][0]["attributes"]["a"]=json!(true);b["facts"][0]["attributes"]["b"]=json!(1);
    let (_dir,left,right)=readers(&a,&b);let mut input=request("Order");input["limit"]=json!(1);
    let out=run(&left,&right,input);
    assert_eq!(changed_field(&out,"/a")["before"]["value"],false);
    assert_eq!(out["comparison"]["metadata"]["evidence"]["reason"],"row_limit");
    assert_eq!(out["comparison"]["metadata"]["evidence"]["unsearched"],true);
    // No independent field allowance is created after prior components spend it.
    let mut out=field_envelope();let mut work=RequestWork::default();assert!(work.facts(19_996));
    let left=json!({"a":false,"b":0});let right=json!({"a":true,"b":1});
    let stop=FieldWriter{out:&mut out,work:&mut work,kind:Kind::Class,limit:8,max_bytes:32768}
        .walk(Some(&left),Some(&right),&mut String::new(),0).unwrap();
    assert_eq!(stop,Some("shared_work"));assert_eq!(changed_field(&out,"/a")["after"]["value"],true);
    assert!(!work.facts(1));
}

#[test]
fn source_window_explains_real_content_and_exact_utf8_physical_coordinates_after_current_c(){
    let prefix=format!("class Order\n{}", "  # unchanged\n".repeat(100));
    let mut a=capture("A",&format!("{prefix}  é\nend"));let mut b=capture("B",&format!("{prefix}  ê\nend"));
    for data in [&mut a,&mut b]{data["facts"][0]["location"]["end_line"]=json!(data["files"][0]["content"].as_str().unwrap().bytes().filter(|b|*b==b'\n').count()+1);}
    let (dir,left,right)=readers(&a,&b);crate::store::publish(dir.path(),&capture("C","class CURRENT; end")).unwrap();
    let out=run(&left,&right,request("Order"));let witness=&out["comparison"]["source"]["witness"];
    assert_eq!(witness["status"],"shown");assert_eq!(witness["complete_hunks"],false);
    for (side,reader,letter) in [("left",&left,"é"),("right",&right,"ê")] {
        let row=&witness[side];let region=&row["region"];let text=region["text"].as_str().unwrap();
        assert!(text.contains(letter));assert!(text.len()<=512);
        assert_eq!(row["generation"],reader.generation);
        let original=reader.source(row["fact_id"].as_str().unwrap()).unwrap();
        let content=original["content"].as_str().unwrap();
        assert_eq!(text,&content[region["start_byte"].as_u64().unwrap() as usize..region["end_byte"].as_u64().unwrap() as usize]);
        assert_eq!(region["sha256"],schema::digest(text.as_bytes()));
        assert_eq!(row["payload_sha256"],original["sha256"]);
        assert!(row["selected_span_bytes_omitted_before"].as_u64().unwrap()>0);
        assert!(region["start_line"].as_u64().unwrap()>90);
        assert_eq!(region["start_line"].as_u64().unwrap() as usize,
            content.as_bytes()[..region["start_byte"].as_u64().unwrap() as usize].iter().filter(|b|**b==b'\n').count()+1);
    }
    assert_eq!(out["comparison"]["line_diff"]["status"],"unavailable");
}

#[test]
fn changed_field_byte_cut_keeps_missingness_and_prefix_and_refuses_first_row_overflow(){
    let mut out=field_envelope();let mut work=RequestWork::default();let long=json!("x".repeat(1024));
    let mut writer=FieldWriter{out:&mut out,work:&mut work,kind:Kind::Class,limit:8,max_bytes:1024};
    assert_eq!(writer.emit(None,Some(&long),"/big").unwrap(),None);
    assert_eq!(writer.emit(None,Some(&json!(1)),&format!("/{}","p".repeat(600))).unwrap(),Some("output_or_shared_work_budget"));
    let row=changed_field(&out,"/big");assert_eq!(row["before"]["present"],false);
    assert_eq!(row["after"]["value_status"],"omitted");assert!(fits(&out,1024).unwrap());
    let mut out=field_envelope();let mut work=RequestWork::default();
    assert_eq!(FieldWriter{out:&mut out,work:&mut work,kind:Kind::Class,limit:8,max_bytes:1}
        .emit(None,Some(&json!(1)),"/x").unwrap_err().code,"limit_exceeded");
}
