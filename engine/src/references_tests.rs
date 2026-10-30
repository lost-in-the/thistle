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
    assert_eq!(limited["coverage"]["not_searched"],false);
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
    assert_eq!(outgoing["coverage"]["candidate_search_complete"],false);
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
    assert_eq!(output["coverage"]["not_searched"],false);
    assert!(schema::encoded_bytes(&output,MAX_OUTPUT+64*1024).is_ok());
    reader.facts[3]["links"]=json!(vec![json!({"relation":"references","target":"User","resolution":"unresolved"});MAX_LINKS+1]);
    let limited=run(&reader,4,"outgoing",1).unwrap();
    assert_eq!(limited["coverage"]["links_scanned"],MAX_LINKS);
    assert_eq!(limited["coverage"]["not_searched"],true);
    let coverage=json!({"family":"known","status":"complete","scope":"fixture","reason":null});
    reader.manifest["coverage"]=json!(vec![coverage;MAX_COVERAGE+1]);
    let result=run(&reader,1,"outgoing",1).unwrap();
    assert_eq!(result["coverage"]["capture_scan_complete"],false);
    assert_eq!(result["coverage"]["capture_partial"],true);
}
