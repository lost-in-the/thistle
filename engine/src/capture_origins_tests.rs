//! Lexical file-origin regressions. Authored source checkpoint; execution is deferred.
use super::*;

fn empty() -> Capture {
    Capture {
        limits: effective_limits(&json!({})).unwrap(),
        files: vec![], facts: vec![], kinds: vec![], diagnostics: vec![],
        diagnostic_bytes: 2, diagnostic_occurrences: 0,
        entries: 0, total_bytes: 0, nodes: 0, links: 0, evidence_bytes: 2,
        link_keys: HashSet::new(), call_keys: HashMap::new(),
        inventory_partial: false, declarations_partial: false,
    }
}

#[test]
fn file_origin_reuses_one_fact_one_walk_and_existing_group_accounting() {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("body.rb"), "Kit::Button.new; Kit::Button.new").unwrap();
    // Program + statements + two (call + constant path + constant read) subtrees.
    let limits = json!({"max_facts":1, "max_links":1, "max_nodes":8});
    let captured = capture_inner(root.path(), effective_limits(&limits).unwrap()).unwrap();
    assert_eq!(captured["producer"]["visited_nodes"], 8);
    let facts = captured["facts"].as_array().unwrap();
    assert_eq!(facts.len(), 1);
    assert_eq!(facts[0]["kind"], "file");
    let links = facts[0]["links"].as_array().unwrap();
    assert_eq!(links.len(), 1);
    let call = schema::call_metadata(&links[0]["attributes"]["thistle_call"], schema::VERSION).unwrap().unwrap();
    assert_eq!(call.name, Some("Kit::Button"));
    assert_eq!(call.location.start_byte, 0); // LIFO still selects earliest representative.
    let refs: Vec<_> = facts.iter().collect();
    let encoded = serde_json::to_vec(&crate::link_encoding::WireFacts::new(&refs, schema::VERSION)).unwrap();
    assert_eq!(captured["evidence_accounting"]["fact_bytes_upper_bound"], encoded.len() + 2);
    assert_eq!(capture_inner(root.path(), effective_limits(&json!({"max_nodes":7})).unwrap()).unwrap_err().code, "limit_exceeded");
}

#[test]
fn hash_value_receivers_keep_real_method_ownership_and_dynamic_refusals() {
    let root = tempfile::tempdir().unwrap();
    let source = "{ primary: Kit::Button.new }; def render; { primary: Kit::Button.new }; end; wrapper { def hidden; Kit::Button.new; end }";
    std::fs::write(root.path().join("body.rb"), source).unwrap();
    let captured = capture_inner(root.path(), effective_limits(&json!({"max_diagnostics":1})).unwrap()).unwrap();
    let mut origins = Vec::new();
    for fact in captured["facts"].as_array().unwrap() {
        for link in fact["links"].as_array().unwrap() {
            let Some(call) = schema::call_metadata(&link["attributes"]["thistle_call"], schema::VERSION).unwrap() else { continue; };
            if call.name == Some("Kit::Button") {
                assert_eq!(call.kind, "constant");
                assert_eq!(&source[call.location.start_byte as usize..call.location.end_byte as usize], "Kit::Button.new");
                origins.push((fact["kind"].as_str().unwrap(), fact["name"].as_str().unwrap(), call.location.start_byte as usize));
            }
        }
    }
    origins.sort_unstable();
    let sites: Vec<_> = source.match_indices("Kit::Button.new").map(|(offset, _)| offset).collect();
    assert_eq!(origins, vec![("file", "body.rb", sites[0]), ("method", "Object#render", sites[1])]);
    assert_eq!(captured["diagnostics"], json!([
        {"code":"dynamic_scope", "message":DECLARATION_SCOPE_MESSAGE, "path":"body.rb", "occurrences":1}
    ]));
    assert!(captured["coverage"].as_array().unwrap().iter().any(|row| row["family"] == "ruby_declarations" && row["status"] == "partial"));
}

#[test]
fn file_call_bytes_and_links_are_admitted_before_mutation() {
    let source = b"Kit::Button.new";
    let parsed = ruby_prism::parse(source);
    let program = parsed.node();
    let statements = program.as_program_node().unwrap().statements();
    let node = statements.body().iter().next().unwrap();
    let call = node.as_call_node().unwrap();
    let lines = LineIndex::new(source);
    let mut captured = empty();
    let index = captured.add_fact(FactKind::File, "body.rb", "body.rb", Value::Null, json!({})).unwrap();
    let scope = Scope { owner:"Object".into(), namespace:None, singleton:false, current:Some(index), dynamic:false };
    captured.collect_call(&call, &scope, "body.rb", &lines).unwrap();
    let link = captured.facts[index]["links"][0].clone();
    let charge = Capture::link_bytes(&link).unwrap() + 1;
    captured.facts[index]["links"] = json!([]);
    captured.call_keys.clear(); captured.links = 0;
    captured.evidence_bytes = schema::MAX_FACTS_BYTES - charge + 1;
    let before = captured.evidence_bytes;
    assert_eq!(captured.collect_call(&call, &scope, "body.rb", &lines).unwrap_err().code, "limit_exceeded");
    assert_eq!(captured.evidence_bytes, before);
    assert_eq!(captured.links, 0);
    assert!(captured.call_keys.is_empty());
    assert!(captured.facts[index]["links"].as_array().unwrap().is_empty());
    captured.evidence_bytes -= 1;
    captured.collect_call(&call, &scope, "body.rb", &lines).unwrap();
    assert_eq!(captured.evidence_bytes, schema::MAX_FACTS_BYTES);
    // A distinct site/group cannot bypass the link ceiling either.
    captured.evidence_bytes = 2; // Isolate link admission from the byte refusal.
    captured.limits.insert("max_links".into(), 1);
    let other = ruby_prism::parse(b"Other.call");
    let error = captured.extract(other.node(), "body.rb", &LineIndex::new(b"Other.call"), index).unwrap_err();
    assert_eq!(error.code, "limit_exceeded");
    assert_eq!(error.message, "Capture exceeds max_links");
    assert_eq!(captured.links, 1);
    assert_eq!(captured.facts[index]["links"][0], link);
}
