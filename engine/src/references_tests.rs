use super::*;
use crate::store;

fn fact(id: usize, name: &str, links: Value) -> Value {
    json!({"id":format!("{id:064x}"),"kind":"class","name":name,"path":null,"location":null,
        "evidence":"static","attributes":{},"links":links})
}
fn fixture(version: u64) -> Value {
    json!({"schema_version":version,"root_id":"a".repeat(64),"producer":{},"files":[],"diagnostics":[],
        "coverage":[{"family":"references","status":"partial","scope":"fixed fixture","reason":"runtime binding unavailable"}],
        "facts":[fact(1,"User",json!([])),fact(2,"User",json!([])),fact(3,"Admin::User",json!([])),
            fact(4,"Order",json!([{"relation":"association_target_label","target":"User","resolution":"unresolved"},
                {"relation":"references","target":"Missing","resolution":"resolved"}]))]})
}
fn run(reader: &Reader, id: usize, direction: &str, limit: usize) -> Result<Value> {
    let request=json!({"id":format!("{id:064x}"),"direction":direction,"limit":limit});
    select(reader, &Query::parse(&request)?)
}
#[test]
fn incoming_outgoing_duplicates_namespace_and_no_source() {
    let temp = tempfile::tempdir().unwrap();
    store::publish(temp.path(), &fixture(3)).unwrap();
    let reader = Reader::open(temp.path(), None).unwrap();
    let outgoing = run(&reader,4,"outgoing",50).unwrap();
    let rows = outgoing["relationships"].as_array().unwrap();
    assert_eq!(rows.len(),2);
    assert_eq!(rows[0]["candidate_matches"],2);
    assert_eq!(rows[0]["candidates"][0]["id"],format!("{:064x}",1));
    assert!(rows[0]["candidates"][0]["path"].is_null());
    assert_eq!(rows[1]["candidate_matches"],0); // resolution never invents identity
    let incoming = run(&reader,1,"incoming",50).unwrap();
    assert_eq!(incoming["relationships"].as_array().unwrap().len(),1);
    assert_eq!(incoming["relationships"][0]["origin"]["name"],"Order");
    assert_eq!(incoming["coverage"]["capture_partial"],true);
    assert!(run(&reader,3,"incoming",50).unwrap()["relationships"].as_array().unwrap().is_empty());
    let limited=run(&reader,4,"outgoing",1).unwrap();
    assert_eq!(limited["coverage"]["known_omitted"],1);
    assert_eq!(limited["coverage"]["not_searched"],true);
    assert!(limited["next_cursor"].is_string());
}
#[test]
fn explicit_schema_context_opaque_one_and_call_receivers_two_three() {
    for version in 1..=3 {
        let temp=tempfile::tempdir().unwrap();
        let mut data=fixture(version);
        // schema 1 treats this colliding extension as opaque, not a receiver.
        data["facts"][3]["links"]=json!([{"relation":"calls","target":"find","resolution":"unresolved",
            "attributes":{"thistle_call":{"version":2,"data":["constant","User",false,false,[0,4,1,1],[0,4,1,1]]}}}]);
        // Valid semantic call locations need a captured source file for 2/3.
        if version>1 {
            data["files"]=json!([{"path":"a.rb","bytes":4,"sha256":schema::digest(b"User"),"content":"User","encoding":"UTF-8"}]);
            data["facts"][3]["path"]=json!("a.rb");
        }
        store::publish(temp.path(),&data).unwrap();
        let reader=Reader::open(temp.path(),None).unwrap();
        let result=run(&reader,1,"incoming",50).unwrap();
        assert_eq!(result["relationships"].as_array().unwrap().len(),if version==1 {0} else {1});
        let outgoing=run(&reader,4,"outgoing",50).unwrap();
        assert_eq!(outgoing["relationships"][0]["link"]["attributes"],data["facts"][3]["links"][0]["attributes"]);
    }
}
#[test]
fn scan_saturation_and_candidate_limits_are_distinct_from_known_omissions() {
    let temp=tempfile::tempdir().unwrap();
    let mut data=fixture(3);
    let facts=data["facts"].as_array_mut().unwrap();
    for id in 5..=MAX_FACTS+1 { facts.push(fact(id,"User",json!([]))); }
    store::publish(temp.path(),&data).unwrap();
    let reader=Reader::open(temp.path(),None).unwrap();
    let incoming=run(&reader,1,"incoming",50).unwrap();
    assert_eq!(incoming["coverage"]["not_searched"],true);
    assert_eq!(incoming["coverage"]["known_omitted"],0);
    let outgoing=run(&reader,4,"outgoing",50).unwrap();
    assert_eq!(outgoing["coverage"]["candidate_search_complete"],true);
    assert_eq!(outgoing["relationships"][0]["candidate_matches"],MAX_FACTS-1);
    assert_eq!(outgoing["relationships"][0]["candidates"].as_array().unwrap().len(),4);
}
#[test]
fn generations_handles_and_invalid_parameters() {
    let temp=tempfile::tempdir().unwrap();
    let old=store::publish(temp.path(),&fixture(3)).unwrap();
    let opened=crate::dispatch(&json!({"op":"open","path":temp.path()})).unwrap();
    let handle=opened["handle"].clone();
    let mut data=fixture(3);data["facts"][0]["name"]=json!("Changed");
    store::publish(temp.path(),&data).unwrap();
    let mut request=json!({"op":"references","handle":handle,"id":format!("{:064x}",1),"direction":"incoming"});
    assert_eq!(crate::dispatch(&request).unwrap()["generation"],old["generation"]);
    for limit in [json!(0),json!(501),json!("1"),json!(null)] {
        request["limit"]=limit;assert!(crate::dispatch(&request).is_err());
    }
    request.as_object_mut().unwrap().remove("limit");
    request["direction"]=json!("sideways");assert!(crate::dispatch(&request).is_err());
    request["direction"]=json!("incoming");
    crate::dispatch(&json!({"op":"close","handle":handle})).unwrap();
    assert!(crate::dispatch(&request).is_err());
}

#[test]
fn anonymous_models_and_work_output_link_and_capture_bounds_stay_explicit() {
    assert!(candidate_name(&json!({"kind":"rails_model","name":"Anonymous model 0","attributes":{"model":{"name":null}}})).is_none());
    let mut work=Work { comparisons:MAX_COMPARISONS,bytes:0 };
    assert_eq!(work.compare("a","a"),None);
    work=Work { comparisons:0,bytes:MAX_LABEL_BYTES };
    assert_eq!(work.compare("a","a"),None);
    let temp=tempfile::tempdir().unwrap();
    store::publish(temp.path(),&fixture(1)).unwrap();
    let mut reader=Reader::open(temp.path(),None).unwrap();
    // Keep this resource test at the selector boundary, without a large publication.
    let long="x".repeat(4096);
    let link=json!({"relation":long,"target":long,"resolution":"unresolved"});
    reader.facts[3]["links"]=json!(vec![link;501]);
    let output=run(&reader,4,"outgoing",500).unwrap();
    assert!(output["relationships"].as_array().unwrap().len()<500);
    assert!(output["coverage"]["known_omitted"].as_u64().unwrap()>0);
    assert_eq!(output["coverage"]["not_searched"],true);
    assert!(output["next_cursor"].is_string());
    assert!(schema::encoded_bytes(&output,MAX_OUTPUT+64*1024).is_ok());
    reader.facts[3]["links"]=json!(vec![json!({"relation":"references","target":"User","resolution":"unresolved"});MAX_LINKS+1]);
    let limited=run(&reader,4,"outgoing",1).unwrap();
    assert_eq!(limited["coverage"]["links_scanned"],1); // display page stops before scanning the tail
    assert_eq!(limited["coverage"]["not_searched"],true);
    let coverage=json!({"family":"known","status":"complete","scope":"fixture","reason":null});
    reader.manifest["coverage"]=json!(vec![coverage;MAX_COVERAGE+1]);
    let result=run(&reader,1,"outgoing",1).unwrap();
    assert_eq!(result["coverage"]["capture_scan_complete"],false);
    assert_eq!(result["coverage"]["capture_partial"],true);
}

#[test]
fn registered_callback_evidence_keeps_named_ambiguity_without_synthetic_candidates() {
    let temp = tempfile::tempdir().unwrap();
    let mut data = fixture(3);
    let mut observation: Value = serde_json::from_str(include_str!("../tests/fixtures/callbacks.json")).unwrap();
    observation["models"][0]["name"] = Value::Null;
    observation["models"][0]["superclass"] = Value::Null;
    observation["models"][0]["save"]["entries"] = json!([]);
    let mut named = observation["models"][0].clone();
    named["name"] = json!("User");
    observation["models"].as_array_mut().unwrap().push(named);
    let context = json!({"schema_version":3,"limits":{"max_facts":100,"max_links":100,"max_entries":100,"max_diagnostics":10},
        "facts":4,"links":2,"diagnostics":0,"fact_bytes":schema::encoded_bytes(&data["facts"],schema::MAX_FACTS_BYTES).unwrap()});
    let batch = crate::callbacks::batch(&context, &observation).unwrap();
    let anonymous = &batch["facts"][0];
    let named = &batch["facts"][1];
    data["facts"][3]["links"] = json!([
        {"relation":"references","target":anonymous["name"],"resolution":"unresolved"},
        {"relation":"references","target":"User","resolution":"unresolved"}]);
    data["facts"].as_array_mut().unwrap().extend(batch["facts"].as_array().unwrap().iter().cloned());
    store::publish(temp.path(), &data).unwrap();
    let reader = Reader::open(temp.path(), None).unwrap();
    let outgoing = run(&reader, 4, "outgoing", 50).unwrap();
    assert_eq!(outgoing["relationships"][0]["candidate_matches"], 0);
    assert_eq!(outgoing["relationships"][1]["candidate_matches"], 3);
    assert!(outgoing["relationships"][1]["candidates"].as_array().unwrap().iter().any(|fact| fact["id"] == named["id"]));
    let request = json!({"id":anonymous["id"],"direction":"incoming"});
    assert!(select(&reader, &Query::parse(&request).unwrap()).unwrap()["relationships"].as_array().unwrap().is_empty());
}

#[test]
fn positional_pages_cover_links_and_candidates_without_replaying_prefixes() {
    let temp=tempfile::tempdir().unwrap();
    let mut data=fixture(3);
    for id in 5..12 { data["facts"].as_array_mut().unwrap().push(fact(id,"User",json!([]))); }
    store::publish(temp.path(),&data).unwrap();
    let reader=Reader::open(temp.path(),None).unwrap();
    let mut request=json!({"id":format!("{:064x}",4),"limit":1});
    let first=select(&reader,&Query::parse(&request).unwrap()).unwrap();
    assert_eq!(first["relationships"][0]["candidate_matches"],9);
    assert_eq!(first["relationships"][0]["candidate_search_complete"],true);
    request["cursor"]=first["next_cursor"].clone();
    let second=select(&reader,&Query::parse(&request).unwrap()).unwrap();
    assert_eq!(second["relationships"][0]["link_ordinal"],1);
    assert_eq!(second["coverage"]["links_scanned"],1);
    assert_eq!(second["next_cursor"],Value::Null);
    let mut request=json!({"id":format!("{:064x}",4),"candidate_link":0,"limit":2});
    let mut ids=std::collections::HashSet::new(); let mut cursors=std::collections::HashSet::new();
    for _ in 0..6 {
        let page=select(&reader,&Query::parse(&request).unwrap()).unwrap();
        assert_eq!(page["candidate_status"],"ambiguous");
        assert_eq!(page["candidate_matches"],9);
        for candidate in page["candidates"].as_array().unwrap() { assert!(ids.insert(candidate["id"].clone().to_string())); }
        if page["next_cursor"].is_null() { assert_eq!(ids.len(),9); break; }
        assert!(cursors.insert(page["next_cursor"].to_string()));
        request["cursor"]=page["next_cursor"].clone();
    }
    assert_eq!(ids.len(),9);
    // A saved position is never transferable to another generation/query domain.
    let wrong=json!({"id":format!("{:064x}",1),"direction":"incoming","cursor":first["next_cursor"]});
    assert_eq!(select(&reader,&Query::parse(&wrong).unwrap()).unwrap_err().code,"invalid_input");
}

#[test]
fn pinned_cursor_survives_current_change_and_inflight_reader_survives_close() {
    let temp=tempfile::tempdir().unwrap();
    let data=fixture(3); let old=store::publish(temp.path(),&data).unwrap();
    let opened=crate::dispatch(&json!({"op":"open","path":temp.path()})).unwrap();
    let handle=opened["handle"].clone();
    let mut request=json!({"op":"references","handle":handle,"id":format!("{:064x}",4),"limit":1});
    let first=crate::dispatch(&request).unwrap();
    let mut changed=data.clone(); changed["facts"][3]["name"]=json!("NewOrder"); store::publish(temp.path(),&changed).unwrap();
    request["cursor"]=first["next_cursor"].clone();
    assert_eq!(crate::dispatch(&request).unwrap()["generation"],old["generation"]);
    // This is the same Arc ownership used by an admitted in-flight native call.
    let admitted=crate::reader(&request).unwrap();
    crate::dispatch(&json!({"op":"close","handle":handle})).unwrap();
    let joined=std::thread::spawn(move || select(&admitted,&Query::parse(&request).unwrap())).join().unwrap().unwrap();
    assert_eq!(joined["generation"],old["generation"]);
    assert_eq!(crate::dispatch(&json!({"op":"references","handle":handle,"id":format!("{:064x}",4)})).unwrap_err().code,"closed_reader");
    let reopened=Reader::open(temp.path(),old["generation"].as_str()).unwrap();
    let result=run(&reopened,4,"outgoing",50).unwrap();
    assert_eq!(result["cost"]["recorded_directory"]["built_this_request"],true);
}

fn constant_call(name: &str, metadata_version: u64) -> Value {
    let location = json!({"start_byte":0,"end_byte":6,"start_line":1,"end_line":1});
    let extension = if metadata_version == 1 {
        json!({"version":1,"receiver":{"kind":"constant","name":name,"omitted_limit":false},
            "safe_navigation":false,"call_location":location,"receiver_location":location})
    } else {
        json!({"version":2,"data":["constant",name,false,false,[0,6,1,1],[0,6,1,1]]})
    };
    json!({"relation":"calls","target":"build","resolution":"unresolved",
        "attributes":{"thistle_call":extension}})
}
fn rooted_fixture(version: u64, metadata_version: u64) -> Value {
    let mut data = fixture(version);
    data["files"] = json!([{"path":"a.rb","bytes":6,"sha256":schema::digest(b"::User"),"content":"::User","encoding":"UTF-8"}]);
    data["facts"] = json!([fact(1,"User",json!([])), fact(2,"Admin::User",json!([])),
        fact(3,"Plain",json!([constant_call("User",metadata_version)])),
        fact(4,"Rooted",json!([constant_call("::User",metadata_version)])),
        fact(5,"Other::Nested",json!([constant_call("::User",metadata_version)])),
        fact(6,"Namespaced",json!([constant_call("::Admin::User",metadata_version)])),
        fact(7,"RelativeNamespaced",json!([constant_call("Admin::User",metadata_version)])),
        fact(8,"User",json!([]))]);
    for index in 2..7 { data["facts"][index]["path"] = json!("a.rb"); }
    data
}
#[test]
fn recognized_rooted_receivers_share_incoming_outgoing_and_candidate_pages() {
    for (version, metadata) in [(1,1),(2,1),(2,2),(3,2)] {
        let temp = tempfile::tempdir().unwrap();
        let data = rooted_fixture(version,metadata);
        let saved = store::publish(temp.path(),&data).unwrap();
        let reader = Reader::open(temp.path(),None).unwrap();
        let mut request = json!({"id":format!("{:064x}",1),"direction":"incoming","limit":1});
        let mut origins = Vec::new();
        for _ in 0..4 {
            let page = select(&reader,&Query::parse(&request).unwrap()).unwrap();
            for row in page["relationships"].as_array().unwrap() {
                origins.push(row["origin"]["name"].as_str().unwrap().to_owned());
                assert_eq!(row["match_basis"],"label_match_binding_unknown");
                assert_eq!(row["candidate_search_complete"],false);
            }
            if page["next_cursor"].is_null() { break; }
            request["cursor"] = page["next_cursor"].clone();
        }
        assert_eq!(origins,vec!["Plain","Rooted","Other::Nested"]);
        let rooted = run(&reader,4,"outgoing",1).unwrap();
        let row = &rooted["relationships"][0];
        assert_eq!(row["candidate_label"],"::User");
        assert_eq!(row["link"],data["facts"][3]["links"][0]);
        assert_eq!(row["candidate_matches"],2);
        assert_eq!(row["candidates"][0]["id"],format!("{:064x}",1));
        let mut candidates = json!({"id":format!("{:064x}",4),"candidate_link":0,"limit":1});
        let first = select(&reader,&Query::parse(&candidates).unwrap()).unwrap();
        assert_eq!(first["candidate_status"],"ambiguous");
        assert!(first["next_cursor"].is_string());
        let mut changed = data.clone(); changed["facts"][0]["name"] = json!("Changed");
        store::publish(temp.path(),&changed).unwrap();
        let reopened = Reader::open(temp.path(),saved["generation"].as_str()).unwrap();
        candidates["cursor"] = first["next_cursor"].clone();
        let last = select(&reopened,&Query::parse(&candidates).unwrap()).unwrap();
        assert_eq!(last["generation"],saved["generation"]);
        assert_eq!(last["candidate_matches"],2);
        assert_eq!(last["candidates"][0]["id"],format!("{:064x}",8));
        assert!(last["next_cursor"].is_null());
        let namespaced = run(&reopened,2,"incoming",50).unwrap();
        assert_eq!(namespaced["relationships"].as_array().unwrap().len(),2);
        assert_eq!(run(&reopened,6,"outgoing",1).unwrap()["relationships"][0]["candidates"][0]["name"],"Admin::User");
    }
}
#[test]
fn opaque_and_nonconstant_labels_never_gain_root_normalization() {
    for version in 1..=3 {
        let temp = tempfile::tempdir().unwrap();
        let mut data = rooted_fixture(version,2);
        let mut opaque = constant_call("::User",2);
        opaque["target"] = json!("::User");
        if version > 1 { opaque["attributes"]["thistle_call"]["version"] = json!(99); }
        let mut local = constant_call("::User",2);
        local["attributes"]["thistle_call"]["data"][0] = json!("local");
        data["facts"][3]["links"] = json!([opaque,local,
            {"relation":"references","target":"::User","resolution":"unresolved"}]);
        store::publish(temp.path(),&data).unwrap();
        let reader = Reader::open(temp.path(),None).unwrap();
        let output = run(&reader,4,"outgoing",50).unwrap();
        for row in output["relationships"].as_array().unwrap() { assert_eq!(row["candidate_matches"],0); }
        let incoming = run(&reader,1,"incoming",50).unwrap();
        assert!(!incoming["relationships"].as_array().unwrap().iter().any(|row| row["origin"]["name"] == "Rooted"));
        assert_eq!(output["relationships"][0]["link"],data["facts"][3]["links"][0]);
    }
}
#[test]
fn rooted_comparisons_charge_original_bytes_and_keep_refusals() {
    let target = Label { original:"::User",key:recorded_domain::constant_label("::User") };
    let mut work = Work { comparisons:0,bytes:0 };
    assert_eq!(work.compare_scoped(target,"User",None),Some(true));
    assert_eq!((work.comparisons,work.bytes),(1,10));
    let mut work = Work { comparisons:0,bytes:MAX_LABEL_BYTES-9 };
    assert_eq!(work.compare_scoped(target,"User",None),None);
    let mut work = Work { comparisons:0,bytes:0 };
    let mut labels = ScopedLabels { work:&mut work,shared:None,original:target.original };
    assert_eq!(recorded_domain::LabelWork::compare(&mut labels,"User",target.key).unwrap(),std::cmp::Ordering::Equal);
    assert_eq!((work.comparisons,work.bytes),(1,10));
    let mut work = Work { comparisons:MAX_COMPARISONS,bytes:0 };
    let mut labels = ScopedLabels { work:&mut work,shared:None,original:target.original };
    assert_eq!(recorded_domain::LabelWork::compare(&mut labels,"User",target.key).unwrap_err().code,"limit_exceeded");
}
