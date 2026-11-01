// Authored native regressions. UNRUN under the LOS-144 source-only grant.
use super::*;

fn route(id: char, controller: Value, action: Value) -> Value {
    json!({"id":id.to_string().repeat(64),"kind":"route","name":"orders","evidence":"runtime","path":null,"location":null,
        "attributes":{"controller":controller,"action":action,"order":0,"verb":"GET","route_path":"/orders(.:format)",
            "source_runtime_coherence":"unknown","route_constraints":{"request":{"status":"unknown"}}},
        "links":[{"relation":"routes_to","target":"orders#index","resolution":"unresolved"}]})
}
fn method(id: &str, owner: &str, singleton: bool) -> Value {
    json!({"id":id,"kind":"method","name":format!("{owner}#index"),"evidence":"static","path":null,"location":null,
        "attributes":{"owner":owner,"method_name":"index","singleton":singleton},"links":[]})
}
fn saved(facts: Vec<Value>, partial: bool, check: impl FnOnce(&Reader)) {
    let directory = tempfile::tempdir().unwrap();
    let coverage = ["source_inventory","ruby_declarations","rails_routes"].iter().map(|family| {
        json!({"family":family,"status":if partial {"partial"} else {"complete"},"scope":"Known-answer saved fixture"})
    }).collect::<Vec<_>>();
    crate::store::publish(directory.path(),&json!({"schema_version":3,"root_id":"f".repeat(64),"producer":{},"files":[],
        "facts":facts,"coverage":coverage,"diagnostics":[]})).unwrap();
    check(&Reader::open(directory.path(),None).unwrap());
}
fn request(id: char, limit: usize, cursor: Value) -> Value {
    json!({"id":id.to_string().repeat(64),"limit":limit,"cursor":cursor})
}

#[test]
fn literal_namespaces_root_markers_and_custom_forms() {
    for (label,expected) in [("orders","OrdersController"),("admin/purchase_orders","Admin::PurchaseOrdersController"),
        ("/admin/orders","Admin::OrdersController"),("::admin/orders","Admin::OrdersController")] {
        let fact = route('a',json!(label),json!("index"));
        assert_eq!(naming(&fact).unwrap(),(expected.to_owned(),"index"));
        assert_eq!(fact["attributes"]["controller"],label);
    }
    for label in ["API/orders","Admin::Orders","orders_controller","//orders","::/orders","café","","orders__archive"] {
        let fact = route('a',json!(label),json!("index"));
        if label=="orders_controller" {
            assert_eq!(naming(&fact).unwrap().0,"OrdersControllerController"); // never strip a suffix/customize
        } else { assert!(naming(&fact).is_none(),"{label}"); }
    }
    for (controller,action) in [(Value::Null,json!("index")),(json!("orders"),Value::Null),(json!("orders"),json!(":dynamic"))] {
        assert!(naming(&route('a',controller,action)).is_none());
    }
}

#[test]
fn unique_missing_multiple_routes_and_source_absence_remain_distinct() {
    let original = route('a',json!("orders"),json!("index"));
    let mut second = original.clone(); second["id"]=json!("b".repeat(64)); second["attributes"]["route_path"]=json!("/other");
    saved(vec![original.clone(),second,method(&"c".repeat(64),"OrdersController",false),method(&"d".repeat(64),"OrdersController",true)],false,|reader| {
        for id in ['a','b'] {
            let page = select(reader,&Query::parse(&request(id,8,Value::Null)).unwrap()).unwrap();
            assert_eq!(page["status"],"unique_static_candidate_binding_unknown");
            assert_eq!(page["candidate_count"],json!({"lower_bound":1,"exact":true}));
            assert_eq!(page["candidates"][0]["fact"]["id"],"c".repeat(64));
            assert_eq!(page["candidates"][0]["source_status"],"saved_source_absent");
            assert!(page["candidates"][0]["source"].is_null());
            assert_eq!(page["unknowns"]["dispatch"],"unknown");
        }
        let page = select(reader,&Query::parse(&request('a',8,Value::Null)).unwrap()).unwrap();
        assert_eq!(page["route"]["attributes"],original["attributes"]);
        assert_eq!(page["route"]["links"],original["links"]);
        assert!(page["root"]["span"].is_null());
        assert_eq!(page["usage"]["source_reads"],0);
    });
    saved(vec![original.clone()],false,|reader| {
        assert_eq!(select(reader,&Query::parse(&request('a',8,Value::Null)).unwrap()).unwrap()["status"],"no_eligible_recorded_candidate");
    });
    saved(vec![original],true,|reader| {
        let page=select(reader,&Query::parse(&request('a',8,Value::Null)).unwrap()).unwrap();
        assert_eq!(page["status"],"discovery_incomplete");
        assert_eq!(page["coverage"]["capture_partial_or_unknown"],true);
    });
}

#[test]
fn late_duplicate_cannot_make_a_prefix_unique_and_cursors_keep_scope() {
    let mut facts = vec![route('a',json!("orders"),json!("index")),method(&"b".repeat(64),"OrdersController",false)];
    for n in 0..64 { facts.push(method(&format!("{n:064x}"),&format!("Other{n}"),false)); }
    facts.push(method(&"e".repeat(64),"OrdersController",false));
    saved(facts,false,|reader| {
        let page=select(reader,&Query::parse(&request('a',1,Value::Null)).unwrap()).unwrap();
        assert_eq!(page["status"],"ambiguous_static_candidates");
        assert_eq!(page["candidate_count"]["lower_bound"],2);
        assert_eq!(page["candidates"].as_array().unwrap().len(),1);
        let next=page["next_cursor"].clone(); assert!(next.is_string());
        let suffix=select(reader,&Query::parse(&request('a',1,next.clone())).unwrap()).unwrap();
        assert_eq!(suffix["status"],"ambiguous_static_candidates");
        assert_ne!(suffix["candidates"][0]["fact"]["id"],page["candidates"][0]["fact"]["id"]);
        assert_eq!(suffix["coverage"]["page_complete"],true);
        assert_eq!(suffix["candidate_count"],json!({"lower_bound":2,"exact":true}));
        let wrong=recorded_domain::cursor(&reader.generation,&json!(["route_actions","b".repeat(64)]),(1,0)).unwrap();
        assert_eq!(select(reader,&Query::parse(&request('a',1,wrong)).unwrap()).unwrap_err().code,"invalid_input");
        let wrong_generation=recorded_domain::cursor(&"f".repeat(64),&json!(["route_actions","a".repeat(64)]),(1,0)).unwrap();
        assert!(select(reader,&Query::parse(&request('a',1,wrong_generation)).unwrap()).is_err());
        assert_eq!(select_with_work(reader,&Query::parse(&request('a',1,Value::Null)).unwrap(),Work { visits:MAX_VISITS,..Work::default() }).unwrap_err().code,"limit_exceeded");
        let tiny=json!({"id":"a".repeat(64),"max_bytes":32});
        assert_eq!(select(reader,&Query::parse(&tiny).unwrap()).unwrap_err().code,"limit_exceeded");
    });
}

#[test]
fn unsupported_endpoints_do_not_build_directory_and_limits_refuse() {
    saved(vec![route('a',Value::Null,Value::Null)],false,|reader| {
        let page=select(reader,&Query::parse(&request('a',8,Value::Null)).unwrap()).unwrap();
        assert_eq!(page["status"],"unsupported_route_or_naming");
        assert!(page["usage"]["method_directory"].is_null());
        assert_eq!(page["coverage"]["discovery_complete"],false);
    });
    for extra in [json!({"limit":0}),json!({"limit":17}),json!({"max_bytes":65537}),json!({"max_bytes":null})] {
        let mut value=request('a',8,Value::Null);
        for (key,value_extra) in extra.as_object().unwrap() { value[key]=value_extra.clone(); }
        assert!(Query::parse(&value).is_err());
    }
}

#[test]
fn byte_cut_keeps_the_dropped_candidate_at_the_exact_suffix() {
    let mut first = method(&"b".repeat(64),"OrdersController",false);
    let mut second = method(&"c".repeat(64),"OrdersController",false);
    first["name"] = json!(format!("OrdersController#index{}", "a".repeat(1200)));
    second["name"] = json!(format!("OrdersController#index{}", "b".repeat(1200)));
    saved(vec![route('a',json!("orders"),json!("index")),first,second],false,|reader| {
        let all = select(reader,&Query::parse(&request('a',2,Value::Null)).unwrap()).unwrap();
        let one = select(reader,&Query::parse(&request('a',1,Value::Null)).unwrap()).unwrap();
        let budget = schema::encoded_bytes(&SuccessEnvelope { ok:true,result:&one },65536).unwrap()+17;
        assert!(schema::encoded_bytes(&SuccessEnvelope { ok:true,result:&all },65536).unwrap()>budget);
        // The borrowed count is wire-identical to the old owned JSON envelope.
        assert_eq!(serde_json::to_vec(&SuccessEnvelope { ok:true,result:&all }).unwrap(),
            serde_json::to_vec(&json!({"ok":true,"result":&all})).unwrap());
        let mut query = request('a',2,Value::Null); query["max_bytes"] = json!(budget);
        let cut = select(reader,&Query::parse(&query).unwrap()).unwrap();
        assert_eq!(cut["candidates"].as_array().unwrap().len(),1);
        assert_eq!(cut["candidates"][0]["fact"]["id"],all["candidates"][0]["fact"]["id"]);
        assert_eq!(cut["coverage"]["page_complete"],false);
        let scope = json!(["route_actions","a".repeat(64)]);
        assert_eq!(recorded_domain::position(Some(&cut["next_cursor"]),&reader.generation,&scope).unwrap(),(1,0));
        query["cursor"] = cut["next_cursor"].clone();
        let suffix = select(reader,&Query::parse(&query).unwrap()).unwrap();
        assert_eq!(suffix["candidates"].as_array().unwrap().len(),1);
        assert_eq!(suffix["candidates"][0]["fact"]["id"],all["candidates"][1]["fact"]["id"]);
        assert_eq!(suffix["coverage"]["page_complete"],true);
    });
}
