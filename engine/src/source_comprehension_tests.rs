// Authored source tests; native execution is UNRUN in the LOS-147 source phase.
use super::*;

fn context() -> Value {
    json!({"schema_version":3,"limits":{"max_facts":100,"max_links":100,"max_entries":100,"max_diagnostics":10},
        "facts":0,"links":0,"diagnostics":0,"fact_bytes":2})
}
fn observation() -> Value {
    json!({"name":"Order","status":"observed","superclass":"Parent","stop_before":"Boundary",
        "ancestors":[
            {"index":0,"name":"Decorated","kind":"module","methods":[{"name":"label","visibility":"public","source":{"path":"/app/concerns.rb","line":2}}]},
            {"index":1,"name":"Order","kind":"class","methods":[{"name":"label","visibility":"public","source":{"path":"/app/order.rb","line":8}},{"name":"native_hash","visibility":"public","source":null}]},
            {"index":2,"name":"Parent","kind":"class","methods":[]}],
        "effective_methods":[{"name":"label","owner_index":0,"source":{"path":"/app/concerns.rb","line":2}},
            {"name":"native_hash","owner_index":1,"source":null}]})
}
fn ownership() -> Value {
    batch(&context(),&json!({"version":1,"models":[observation()]}),"/app").unwrap()["facts"][0].clone()
}
fn model() -> Value { json!({"id":"a".repeat(64),"kind":"rails_model","name":"Order","evidence":"runtime","path":null,"location":null,"attributes":{"model":{"name":"Order"}}}) }
fn method(id: char, owner: &str, name: &str, line: u64) -> Value {
    json!({"id":id.to_string().repeat(64),"kind":"method","name":format!("{owner}#{name}"),"evidence":"static","path":"order.rb",
        "location":{"start_line":line,"end_line":line+2,"start_byte":0,"end_byte":8},
        "attributes":{"owner":owner,"method_name":name,"singleton":false,"name_resolution":"lexical"}})
}

#[test]
fn guarded_observation_admission_retains_identity_and_rejects_forgery() {
    let fact = ownership();
    validate_fact(&fact).unwrap();
    assert_eq!(fact["attributes"]["source_comprehension"]["observation"]["ancestors"][0]["methods"][0]["source"]["path"],"concerns.rb");
    for key in ["id","evidence","path"] {
        let mut bad = fact.clone(); bad[key] = json!("forged");
        assert!(validate_fact(&bad).is_err());
    }
    let mut bad = observation(); bad["effective_methods"][0]["owner_index"] = json!(1);
    assert!(validate_observation(&bad).is_err());
    let mut bad = observation(); bad["effective_methods"].as_array_mut().unwrap().pop();
    assert!(validate_observation(&bad).is_err());
    let mut outside = observation();
    outside["ancestors"][0]["methods"][0]["source"]["path"] = json!("/application/secret.rb");
    outside["effective_methods"][0]["source"]["path"] = json!("/application/secret.rb");
    let result = batch(&context(),&json!({"version":1,"models":[outside]}),"/app").unwrap();
    assert!(result["facts"][0]["attributes"]["source_comprehension"]["observation"]["effective_methods"][0]["source"].is_null());
}

#[test]
fn observed_prepend_is_distinct_from_saved_binding_and_duplicate_definitions() {
    let generation = "f".repeat(64);
    let fact = ownership();
    let direct = method('b',"Order","label",8);
    let page = project(&generation,&model(),&[&fact],"Order",&[&direct],1,0,true).unwrap();
    assert_eq!(page["contributions"][0]["status"],"alternative_to_observed_loaded_owner");
    assert_eq!(page["contributions"][0]["observed_owner"],"Decorated");
    assert!(page["observed_only"].as_array().unwrap().is_empty());
    assert_eq!(page["source_runtime_coherence"],"unknown");
    let prepend = method('c',"Decorated","label",2);
    let page = project(&generation,&model(),&[&fact],"Decorated",&[&prepend],1,0,true).unwrap();
    assert_eq!(page["contributions"][0]["status"],"observed_loaded_owner_source_binding_unknown");
    let duplicate = method('d',"Decorated","label",9);
    let page = project(&generation,&model(),&[&fact],"Decorated",&[&prepend,&duplicate],2,0,true).unwrap();
    assert_eq!(page["contributions"][0]["status"],"ambiguous_definitions");
    assert_eq!(page["contributions"][1]["fact"]["location"]["start_line"],9);
}

#[test]
fn unavailable_ambiguous_and_incomplete_never_supply_precedence() {
    let generation = "f".repeat(64);
    let fact = ownership();
    let direct = method('b',"Order","label",8);
    let unknown = project(&generation,&model(),&[],"Order",&[&direct],1,0,true).unwrap();
    assert_eq!(unknown["contributions"][0]["status"],"unknown_precedence");
    let ambiguous = project(&generation,&model(),&[&fact,&fact],"Order",&[&direct],1,0,true).unwrap();
    assert_eq!(ambiguous["ownership_status"],"ambiguous");
    assert_eq!(ambiguous["contributions"][0]["status"],"unknown_precedence");
    let partial = project(&generation,&model(),&[&fact],"Order",&[&direct],2,0,true).unwrap();
    assert_eq!(partial["contributions"][0]["status"],"unknown_incomplete_candidates");
    let cursor = recorded_domain::cursor(&generation,&json!(["source_comprehension","a".repeat(64),"methods"]),(3,1)).unwrap();
    let request = json!({"id":"a".repeat(64),"family":"methods","cursor":cursor});
    let continuation = Query::parse(&request).unwrap();
    assert_eq!(continuation.position(&generation).unwrap(),(3,1));
    assert!(continuation.position(&"e".repeat(64)).is_err());
    let bad_family = json!({"id":"a".repeat(64),"family":"anything"});
    assert!(Query::parse(&bad_family).is_err());
    assert!(project(&generation,&model(),&[&fact],"Optional",&[],0,0,true).is_err());
}

struct Meter { visits: usize, bytes: usize }
impl method_lookup::Work for Meter {
    fn visit(&mut self) -> bool { if self.visits==0 { return false; } self.visits-=1; true }
    fn bytes(&mut self, n: usize) -> bool { if n>self.bytes { return false; } self.bytes-=n; true }
    fn compare(&mut self,a:&str,b:&str)->Option<Ordering> { self.bytes(a.len()+b.len()).then(||a.cmp(b)) }
    fn compare_digest(&mut self,a:&[u8;32],b:&[u8;32])->Option<Ordering> { self.bytes(64).then(||a.cmp(b)) }
}
fn meter() -> Meter { Meter { visits:100,bytes:65536 } }
#[test]
fn existing_method_directory_pages_keep_all_duplicates_and_explicit_partiality() {
    let facts = vec![method('b',"Order","label",8),method('c',"Order","label",14),method('d',"Other","label",1)];
    let mut counts = method_lookup::Counts::default();
    for fact in &facts { counts.record(fact).unwrap(); }
    let directory = method_lookup::Directory::build(&facts,counts,&query::Budget::new(4096)).unwrap();
    let first = directory.page(&facts,"Order","label",0,1,&mut meter()).unwrap();
    assert_eq!(first.positions.len(),1); assert_eq!(first.matches_seen,2);
    assert_eq!(first.next_offset,Some(1)); assert!(!first.range_complete); assert!(!first.partial);
    let second = directory.page(&facts,"Order","label",1,1,&mut meter()).unwrap();
    assert_eq!(second.positions.len(),1); assert_ne!(first.positions,second.positions);
    assert_eq!(second.matches_seen,2); assert!(second.range_complete); assert!(!second.partial);
    let repeat = directory.page(&facts,"Order","label",0,1,&mut meter()).unwrap();
    assert_eq!(repeat.positions,first.positions);
    let partial = directory.page(&facts,"Order","label",0,2,&mut Meter { visits:1,bytes:65536 }).unwrap();
    assert!(partial.partial); assert!(!partial.range_complete); assert_eq!(partial.positions.len(),1);
    assert_eq!(partial.next_offset,Some(1));
    let refused = directory.page(&facts,"Order","label",0,2,&mut Meter { visits:100,bytes:0 }).unwrap();
    assert!(refused.partial); assert!(refused.positions.is_empty()); assert_eq!(refused.next_offset,None);
    assert!(directory.page(&facts,"Order","label",3,1,&mut meter()).is_err());
    assert!(directory.page(&facts,"Order","label",0,17,&mut meter()).is_err());
    let absent = directory.page(&facts,"Order","missing",0,1,&mut meter()).unwrap();
    assert!(absent.range_complete); assert!(!absent.partial); assert!(absent.positions.is_empty());
}
