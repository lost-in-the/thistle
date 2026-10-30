//! Small source-only known answers. Execution belongs to the later native gate.
use super::*;

fn captured(source: &str, limits: Value) -> Result<Value> {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("body.rb"), source).unwrap();
    capture_inner(root.path(), effective_limits(&limits)?)
}

fn occurrences(data: &Value) -> Vec<&Value> {
    data["facts"].as_array().unwrap().iter()
        .flat_map(|f| f["links"].as_array().unwrap())
        .filter(|link| link["relation"] == "references_constant").collect()
}

#[test]
fn maximal_paths_distinct_sites_roles_and_receivers_are_not_conflated() {
    let source = "CoreModel; CoreModel; Loader.for(CoreModel, :assoc); value.is_a?(CoreModel); {primary: CoreModel}; if CoreModel; end; begin; danger; rescue ErrorType; end; Kit::Button; ::Kit::Button; Kit::Button.new; Kit::Button.new";
    let data = captured(source, json!({})).unwrap();
    let links = occurrences(&data);
    let mut actual = links.iter().map(|link| {
        let meta = &link["attributes"]["thistle_constant"];
        let location = &meta["location"];
        let start = location[0].as_u64().unwrap() as usize;
        let end = location[1].as_u64().unwrap() as usize;
        assert_eq!(&source[start..end], meta["syntax"].as_str().unwrap());
        assert_eq!(meta["rooted"], meta["syntax"].as_str().unwrap().starts_with("::"));
        assert_eq!(&location.as_array().unwrap()[2..], &[json!(1), json!(1)]);
        assert!(meta["lexical_scope"].is_null());
        (link["target"].as_str().unwrap(), meta["role"].as_str().unwrap(), start)
    }).collect::<Vec<_>>();
    actual.sort_unstable();
    let mut expected = vec![
        ("CoreModel", "value", 0), ("CoreModel", "value", source.find("; CoreModel").unwrap() + 2),
        ("CoreModel", "argument", source.find("for(CoreModel").unwrap() + 4),
        ("CoreModel", "argument", source.find("is_a?(CoreModel").unwrap() + 6),
        ("CoreModel", "value", source.find("primary: CoreModel").unwrap() + 9),
        ("CoreModel", "predicate", source.find("if CoreModel").unwrap() + 3),
        ("ErrorType", "rescue_class", source.find("rescue ErrorType").unwrap() + 7),
        ("Kit::Button", "value", source.find("Kit::Button;").unwrap()),
        ("::Kit::Button", "value", source.find("::Kit::Button;").unwrap()),
    ];
    expected.sort_unstable();
    assert_eq!(actual, expected);
    let fact = &data["facts"][0];
    let calls = fact["links"].as_array().unwrap().iter().filter_map(|link|
        schema::call_metadata(&link["attributes"]["thistle_call"], schema::VERSION).unwrap())
        .filter(|call| call.name == Some("Kit::Button")).collect::<Vec<_>>();
    assert_eq!(calls.len(), 1); // the old two-receiver call group is unchanged
    assert_eq!(calls[0].location.start_byte as usize, source.find("Kit::Button.new").unwrap());
}

#[test]
fn declarations_assignments_mixins_and_literal_text_are_not_caller_reads() {
    let source = "class Declared < Parent; include Tagged; X = ValueType; end; Outer::Target = OtherValue; \"CoreModel\"; # CoreModel\n";
    let data = captured(source, json!({})).unwrap();
    let mut labels = occurrences(&data).iter().map(|l| l["target"].as_str().unwrap()).collect::<Vec<_>>();
    labels.sort_unstable();
    assert_eq!(labels, ["OtherValue", "ValueType"]);
    let class = data["facts"].as_array().unwrap().iter().find(|f| f["name"] == "Declared").unwrap();
    assert!(class["links"].as_array().unwrap().iter().any(|l| l["relation"] == "inherits" && l["target"] == "Parent"));
    assert!(class["links"].as_array().unwrap().iter().any(|l| l["relation"] == "includes" && l["target"] == "Tagged"));
}

#[test]
fn dynamic_receiver_inner_reads_survive_without_fabricating_a_terminal_path() {
    let source = "factory(CoreModel)::Child; (factory(CoreModel)).call; ::Kit :: Button";
    let data = captured(source, json!({})).unwrap();
    let links = occurrences(&data);
    assert_eq!(links.iter().filter(|l| l["target"] == "CoreModel").count(), 2);
    assert!(!links.iter().any(|l| l["target"] == "Child"));
    let path = links.iter().find(|l| l["target"] == "::Kit::Button").unwrap();
    assert_eq!(path["attributes"]["thistle_constant"]["syntax"], "::Kit :: Button");
    assert_eq!(data["diagnostics"][0]["code"], "constant_path_unavailable");
    assert_eq!(data["diagnostics"][0]["occurrences"], 1);
    assert_eq!(captured("factory::A; factory::B", json!({"max_diagnostics":1})).unwrap_err().code, "limit_exceeded");
    assert_eq!(captured(&format!("C{}", "x".repeat(256)), json!({})).unwrap_err().code, "limit_exceeded");
}

#[test]
fn lexical_origins_compose_with_blocks_and_keep_dynamic_refusals() {
    let source = "CoreModel; task { CoreModel }; class Screen; CoreModel; def render; CoreModel; end; wrapper { include Tagged; def hidden; CoreModel; end }; end";
    let data = captured(source, json!({})).unwrap();
    let mut owners = data["facts"].as_array().unwrap().iter().flat_map(|fact|
        fact["links"].as_array().unwrap().iter().filter(|l| l["relation"] == "references_constant")
            .map(move |_| fact["name"].as_str().unwrap())).collect::<Vec<_>>();
    owners.sort_unstable();
    assert_eq!(owners, ["Screen", "Screen#render", "body.rb", "body.rb"]);
    assert_eq!(data["diagnostics"], json!([
        {"code":"dynamic_scope", "message":DECLARATION_SCOPE_MESSAGE, "path":"body.rb", "occurrences":1},
        {"code":"dynamic_scope", "message":MIXIN_SCOPE_MESSAGE, "path":"body.rb", "occurrences":1}
    ]));
    assert_eq!(captured(source, json!({"max_diagnostics":1})).unwrap_err().code, "limit_exceeded");
}

#[test]
fn new_occurrences_use_existing_traversal_link_and_encoded_byte_limits() {
    let data = captured("CoreModel; CoreModel", json!({"max_facts":1,"max_links":2,"max_nodes":4})).unwrap();
    assert_eq!(data["producer"]["visited_nodes"], 4); // program, statements, two reads
    assert_eq!(occurrences(&data).len(), 2);
    let facts = data["facts"].as_array().unwrap();
    let refs: Vec<_> = facts.iter().collect();
    let encoded = serde_json::to_vec(&crate::link_encoding::WireFacts::new(&refs, schema::VERSION)).unwrap();
    assert_eq!(data["evidence_accounting"]["fact_bytes_upper_bound"], encoded.len() + 2);
    assert_eq!(captured("CoreModel; CoreModel", json!({"max_links":1})).unwrap_err().code, "limit_exceeded");
    assert_eq!(captured("CoreModel; CoreModel", json!({"max_nodes":3})).unwrap_err().code, "limit_exceeded");
    // Lowest admission boundary: no retained link/map/counter mutation on failure.
    let mut capture = Capture {
        limits: effective_limits(&json!({})).unwrap(),
        files: vec![], facts: vec![], kinds: vec![], diagnostics: vec![],
        diagnostic_bytes: 2, diagnostic_occurrences: 0,
        entries: 0, total_bytes: 0, nodes: 0, links: 0, evidence_bytes: 2,
        link_keys: HashSet::new(), call_keys: HashMap::new(),
        inventory_partial: false, declarations_partial: false,
    };
    let index = capture.add_fact(FactKind::File, "body.rb", "body.rb", Value::Null, json!({})).unwrap();
    let scope = Scope { owner:"Object".into(), namespace:None, singleton:false, current:Some(index), dynamic:false };
    let source = b"CoreModel";
    let parsed = ruby_prism::parse(source);
    let program = parsed.node();
    let statements = program.as_program_node().unwrap().statements();
    let node = statements.body().iter().next().unwrap();
    let lines = LineIndex::new(source);
    capture.collect_constant(&node, &scope, ConstantRole::Value, "body.rb", &lines).unwrap();
    let link = capture.facts[index]["links"][0].clone();
    let charge = schema::encoded_bytes(&crate::link_encoding::WireLink::new(&link, schema::VERSION, "static").unwrap(), schema::MAX_FACTS_BYTES).unwrap() + 1;
    capture.facts[index]["links"] = json!([]); capture.links = 0;
    capture.evidence_bytes = schema::MAX_FACTS_BYTES - charge + 1;
    let before = capture.evidence_bytes;
    assert_eq!(capture.collect_constant(&node, &scope, ConstantRole::Value, "body.rb", &lines).unwrap_err().code, "limit_exceeded");
    assert_eq!(capture.evidence_bytes, before);
    assert_eq!(capture.links, 0);
    assert!(capture.facts[index]["links"].as_array().unwrap().is_empty());
    assert!(capture.call_keys.is_empty() && capture.link_keys.is_empty());
    capture.evidence_bytes -= 1;
    capture.collect_constant(&node, &scope, ConstantRole::Value, "body.rb", &lines).unwrap();
    assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES);
}
