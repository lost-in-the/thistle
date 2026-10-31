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

// Focused projection adapter; production selection supplies these same borrowed
// rows/positions after immutable Reader admission. No separate semantics here.
fn project(generation: &str, model: &Value, ownership: &[&Value], owner: &str,
    candidates: &[&Value], matches_seen: usize, offset: usize, complete: bool) -> Result<Value> {
    let observed = (ownership.len()==1).then(|| &ownership[0]["attributes"]["source_comprehension"]["observation"]);
    let fallback = json!([{"index":0,"name":model["name"],"kind":"class","methods":[]}]);
    let owners = observed.map_or(&fallback,|data| &data["ancestors"]).as_array().unwrap();
    let mut work = Work::default();
    let inventory = Inventory::new(owners,observed,&mut work)?;
    let selected_owner = owners.iter().find(|row| row["name"]==owner)
        .ok_or_else(|| CoreError::input("No observed owner candidate"))?;
    let facts = candidates.iter().map(|fact| (*fact).clone()).collect::<Vec<_>>();
    let selected = Selected { owner:selected_owner,method:None,row:0,offset,
        positions:(0..facts.len()).collect(),matches_seen,complete,partial:false,status:"saved_candidates",next:None };
    project_page(generation,model,ownership,&inventory,&[selected],&facts,&mut work)
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
    let mut bad = observation(); bad["effective_methods"][0]["owner_index"]=Value::Null;
    assert!(validate_observation(&bad).is_err(),"unknown owner must not retain a hint");
    let mut bad = observation(); bad["effective_methods"][0]["owner_index"]=json!(2);
    assert!(validate_observation(&bad).is_err(),"known owner must have the direct row");
    let mut outside = observation();
    outside["ancestors"][0]["methods"][0]["source"]["path"] = json!("/application/secret.rb");
    outside["effective_methods"][0]["source"]["path"] = json!("/application/secret.rb");
    let result = batch(&context(),&json!({"version":1,"models":[outside]}),"/app").unwrap();
    assert!(result["facts"][0]["attributes"]["source_comprehension"]["observation"]["effective_methods"][0]["source"].is_null());
    // Neither pseudo-locations nor relative paths establish physical provenance.
    for path in ["(eval at /outside/gem/x.rb:12)","<internal:kernel>","order.rb","/app/../outside.rb","/app//order.rb"] {
        let mut unsafe_hint = observation();
        unsafe_hint["ancestors"][0]["methods"][0]["source"]["path"] = json!(path);
        unsafe_hint["effective_methods"][0]["source"]["path"] = json!(path);
        let result = batch(&context(),&json!({"version":1,"models":[unsafe_hint]}),"/app").unwrap();
        let saved = &result["facts"][0];
        validate_fact(saved).unwrap();
        assert!(saved["attributes"]["source_comprehension"]["observation"]["ancestors"][0]["methods"][0]["source"].is_null(),"{path}");
        assert!(saved["attributes"]["source_comprehension"]["observation"]["effective_methods"][0]["source"].is_null(),"{path}");
    }
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

#[test]
fn wired_batch_dispatch_and_both_fact_validation_paths_are_strict() {
    let request = json!({"op":"source_comprehension_batch","context":context(),
        "observation":{"version":1,"models":[observation()]},"root":"/app"});
    let result = crate::dispatch(&request).unwrap();
    assert_eq!(result["source_comprehension_observer"]["version"],1);
    assert_eq!(result["appended"]["entries"],8);
    let facts = result["facts"].as_array().unwrap();
    schema::facts(facts,&[],3).unwrap();
    schema::stored_facts(facts.iter(),&[],3).unwrap();
    let mut forged = facts.clone();
    forged[0]["attributes"]["source_comprehension"]["observation"]["effective_methods"][0]["owner_index"] = json!(1);
    assert!(schema::facts(&forged,&[],3).is_err());
    assert!(schema::stored_facts(forged.iter(),&[],3).is_err());
    for root in ["relative","/","/app/../elsewhere","/app/","/app//nested","/app/./nested"] {
        let mut bad = request.clone(); bad["root"] = json!(root);
        assert!(crate::dispatch(&bad).is_err(),"{root}");
    }
}

#[test]
fn saved_reader_dispatch_is_pinned_and_refuses_invalid_continuation_without_source_io() {
    let temporary = tempfile::tempdir().unwrap();
    let root = json!({"id":"a".repeat(64),"kind":"class","name":"Order","evidence":"static",
        "path":null,"location":null,"attributes":{},"links":[]});
    let capture = json!({"schema_version":3,"root_id":"d".repeat(64),"files":[],"facts":[root,ownership()],
        "producer":{},"diagnostics":[],"coverage":[{"family":"source","status":"partial","scope":"synthetic saved primitives","reason":"No framework or captured source"}]});
    let manifest = crate::store::publish(temporary.path(),&capture).unwrap();
    let generation = manifest["generation"].as_str().unwrap();
    let opened = crate::dispatch(&json!({"op":"open","path":temporary.path().to_str().unwrap(),"generation":generation})).unwrap();
    let handle = &opened["handle"];
    let request = json!({"op":"source_comprehension","handle":handle,"id":"a".repeat(64),"limit":1});
    let answer = crate::dispatch(&request).unwrap();
    assert_eq!(answer["generation"],generation);
    assert_eq!(answer["owner"],"Order");
    assert_eq!(answer["usage"]["source_reads"],0);
    assert_eq!(answer["contributions"][0]["fact"]["id"],"a".repeat(64));
    let mut invalid = request.clone(); invalid["family"] = json!("unknown");
    assert!(crate::dispatch(&invalid).is_err());
    let mut invalid = request.clone(); invalid["cursor"] = recorded_domain::cursor(&"e".repeat(64),
        &json!(["source_comprehension","a".repeat(64),"contributions"]),(1,0)).unwrap();
    assert!(crate::dispatch(&invalid).is_err());
    crate::dispatch(&json!({"op":"close","handle":handle})).unwrap();
    assert_eq!(crate::dispatch(&request).unwrap_err().code,"closed_reader");
}

fn saved(facts: Vec<Value>, check: impl FnOnce(&Reader)) {
    let temporary = tempfile::tempdir().unwrap();
    let capture = json!({"schema_version":3,"root_id":"d".repeat(64),"files":[],"facts":facts,
        "producer":{},"diagnostics":[],"coverage":[{"family":"source_ownership","status":"partial",
            "scope":"Synthetic saved primitives only","reason":"No framework, source reads or runtime execution"}]});
    crate::store::publish(temporary.path(),&capture).unwrap();
    let reader = Reader::open(temporary.path(),None).unwrap();
    check(&reader);
}
fn declaration(id: char, name: &str, kind: &str) -> Value {
    json!({"id":id.to_string().repeat(64),"kind":kind,"name":name,"evidence":"static",
        "path":null,"location":null,"attributes":{},"links":[]})
}
fn source_less_method(id: char, owner: &str, name: &str) -> Value {
    let mut fact = method(id,owner,name,1);
    fact["path"]=Value::Null; fact["location"]=Value::Null; fact["links"]=json!([]);
    fact
}

#[test]
fn both_families_page_unknown_owner_rows_and_reach_the_named_suffix() {
    let mut data = observation();
    data["ancestors"] = json!([
        {"index":0,"name":"Order","kind":"class","methods":[{"name":"direct","visibility":"public","source":null}]},
        {"index":1,"name":null,"kind":"module","methods":[{"name":"anonymous","visibility":"public","source":null}]},
        {"index":2,"name":"Same","kind":"module","methods":[{"name":"first","visibility":"public","source":null}]},
        {"index":3,"name":"Same","kind":"module","methods":[{"name":"second","visibility":"public","source":null}]},
        {"index":4,"name":"Parent","kind":"class","methods":[{"name":"tail","visibility":"public","source":null}]}
    ]);
    data["effective_methods"] = json!(["direct","anonymous","first","second","tail"].iter().enumerate()
        .map(|(index,name)| json!({"name":name,"owner_index":index,"source":null})).collect::<Vec<_>>());
    let ownership = batch(&context(),&json!({"version":1,"models":[data]}),"/app").unwrap()["facts"][0].clone();
    saved(vec![declaration('a',"Order","class"),ownership,declaration('b',"Same","module"),
        declaration('c',"Parent","class"),source_less_method('e',"Same","first"),source_less_method('f',"Parent","tail")],|reader| {
        for family in ["contributions","methods"] {
            let mut cursor = Value::Null;
            let mut statuses = Vec::new(); let mut suffix = false; let mut suffix_candidate = false;
            for _ in 0..8 {
                let request = json!({"id":"a".repeat(64),"family":family,"limit":2,"cursor":cursor});
                let page = select(reader,&Query::parse(&request).unwrap()).unwrap();
                assert!(page["rows"].as_array().unwrap().len()<=2);
                assert!(page["contributions"].as_array().unwrap().len()<=2);
                for row in page["rows"].as_array().unwrap() {
                    statuses.push(row["status"].as_str().unwrap().to_owned());
                    if row["owner"]=="Parent" { suffix=true; }
                    if matches!(row["status"].as_str(),Some("anonymous_owner_no_label_candidate" | "duplicate_owner_label_unknown")) {
                        assert_eq!(row["returned"],0); assert!(!row["range_complete"].as_bool().unwrap());
                    }
                }
                assert!(!page["contributions"].as_array().unwrap().iter().any(|row| row["owner"]=="Same"));
                suffix_candidate |= page["contributions"].as_array().unwrap().iter().any(|row| row["owner"]=="Parent");
                if page["continuation"].is_null() { break; }
                let next = page["continuation"]["cursor"].clone();
                assert_ne!(next,cursor); cursor=next;
            }
            assert!(suffix,"{family} lost its named suffix");
            assert!(suffix_candidate,"{family} lost its suffix Source candidate");
            assert!(statuses.iter().any(|status| status=="anonymous_owner_no_label_candidate"));
            assert_eq!(statuses.iter().filter(|status| *status=="duplicate_owner_label_unknown").count(),2);
        }
    });
}

#[test]
fn generated_methods_batch_rows_and_byte_cut_keeps_the_exact_candidate_suffix() {
    let mut data = observation();
    let methods = (0..40).map(|index| json!({"name":format!("generated_{index:02}"),"visibility":"public","source":null})).collect::<Vec<_>>();
    data["ancestors"] = json!([{"index":0,"name":"Order","kind":"class","methods":methods}]);
    data["effective_methods"] = json!((0..40).map(|index| json!({"name":format!("generated_{index:02}"),"owner_index":0,"source":null})).collect::<Vec<_>>());
    let mut allowance = context(); allowance["limits"]["max_entries"]=json!(1000);
    let observed = batch(&allowance,&json!({"version":1,"models":[data]}),"/app").unwrap()["facts"][0].clone();
    saved(vec![declaration('a',"Order","class"),observed],|reader| {
        let mut cursor = Value::Null; let mut names = Vec::new();
        for _ in 0..5 {
            let request = json!({"id":"a".repeat(64),"family":"methods","limit":8,"cursor":cursor});
            let page = select(reader,&Query::parse(&request).unwrap()).unwrap();
            assert_eq!(page["rows"].as_array().unwrap().len(),8);
            names.extend(page["observed_only"].as_array().unwrap().iter().map(|row| row["name"].as_str().unwrap().to_owned()));
            cursor=page["continuation"]["cursor"].clone();
        }
        assert_eq!(names.len(),40); assert_eq!(names.iter().collect::<HashSet<_>>().len(),40); assert!(cursor.is_null());
    });
    let mut data = observation();
    data["ancestors"] = json!([{"index":0,"name":"Order","kind":"class","methods":[{"name":"label","visibility":"public","source":null}]}]);
    data["effective_methods"] = json!([{"name":"label","owner_index":0,"source":null}]);
    let observed = batch(&context(),&json!({"version":1,"models":[data]}),"/app").unwrap()["facts"][0].clone();
    saved(vec![declaration('a',"Order","class"),observed,source_less_method('b',"Order","label"),source_less_method('c',"Order","label")],|reader| {
        let request = json!({"id":"a".repeat(64),"family":"methods","limit":8});
        let full = select(reader,&Query::parse(&request).unwrap()).unwrap();
        let max = serde_json::to_vec(&full).unwrap().len();
        let small = json!({"id":"a".repeat(64),"family":"methods","limit":8,"max_bytes":max-1});
        let first = select(reader,&Query::parse(&small).unwrap()).unwrap();
        assert_eq!(first["contributions"].as_array().unwrap().len(),1);
        assert_eq!(first["contributions"][0]["status"],"unknown_incomplete_candidates");
        let scope = json!(["source_comprehension","a".repeat(64),"methods"]);
        assert_eq!(recorded_domain::position(Some(&first["continuation"]["cursor"]),&reader.generation,&scope).unwrap(),(0,1));
        let suffix = json!({"id":"a".repeat(64),"family":"methods","cursor":first["continuation"]["cursor"]});
        let last = select(reader,&Query::parse(&suffix).unwrap()).unwrap();
        assert_ne!(first["contributions"][0]["fact"]["id"],last["contributions"][0]["fact"]["id"]);
        assert!(last["continuation"].is_null());
    });
}

#[test]
fn admitted_large_ambiguous_ownership_is_queryable_without_group_revalidation() {
    let mut data = observation();
    // Two valid observations together exceed the former asymmetric 2 MiB query
    // group cap. No source body is needed for an honest ambiguous answer.
    let path = format!("/app/{}.rb","x".repeat(650));
    let direct = (0..900).map(|index| json!({"name":format!("method_{index}"),"visibility":"public","source":{"path":path,"line":1}})).collect::<Vec<_>>();
    data["ancestors"] = json!([{"index":0,"name":"Order","kind":"class","methods":direct}]);
    data["effective_methods"] = json!((0..900).map(|index| json!({"name":format!("method_{index}"),"owner_index":0,"source":{"path":path,"line":1}})).collect::<Vec<_>>());
    let mut allowance = context(); allowance["limits"]["max_entries"]=json!(10000); allowance["limits"]["max_facts"]=json!(10);
    let result = batch(&allowance,&json!({"version":1,"models":[data.clone(),data]}),"/app").unwrap();
    let ownership = result["facts"].as_array().unwrap();
    assert!(serde_json::to_vec(ownership).unwrap().len()>MAX_INPUT);
    saved(vec![declaration('a',"Order","class"),ownership[0].clone()],|reader| {
        let request = json!({"id":"a".repeat(64),"family":"methods"});
        let page = select(reader,&Query::parse(&request).unwrap()).unwrap();
        assert_eq!(page["rows"].as_array().unwrap().len(),8);
        let visits = page["usage"]["candidate_fact_visits"].as_u64().unwrap();
        assert!(visits>=900 && visits<2000,"required descriptor scan must be metered");
    });
    let mut facts = vec![declaration('a',"Order","class")]; facts.extend(ownership.iter().cloned());
    saved(facts,|reader| {
        let request = json!({"id":"a".repeat(64)});
        let page = select(reader,&Query::parse(&request).unwrap()).unwrap();
        assert_eq!(page["ownership_status"],"ambiguous");
        assert_eq!(page["contributions"].as_array().unwrap().len(),1);
        assert!(page["usage"]["candidate_fact_visits"].as_u64().unwrap()<100);
    });
    let mut work = Work { visits:20_000,..Work::default() };
    assert!(Inventory::new(&[json!({"name":"Order","methods":[]})],None,&mut work).is_err());
}
