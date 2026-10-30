//! Focused diagnostic admission regressions, including the publication boundary.
use super::*;
use crate::store::{self, Reader};

fn empty(limits: Value) -> Capture {
    Capture {
        limits: effective_limits(&limits).unwrap(),
        files: vec![], facts: vec![], kinds: vec![], diagnostics: vec![],
        diagnostic_bytes: 2, diagnostic_occurrences: 0,
        entries: 0, total_bytes: 0, nodes: 0, links: 0, evidence_bytes: 2,
        link_keys: HashSet::new(), call_keys: HashMap::new(),
        inventory_partial: false, declarations_partial: false,
    }
}

fn capture(root: &Path, limits: Value) -> Result<Value> {
    // Existing native unit tests use the inner boundary, avoiding the public
    // single-capture permit while keeping real Prism extraction/publication.
    capture_inner(root, effective_limits(&limits)?)
}

fn warning() -> Value {
    json!({"code":"dynamic_scope", "message":DECLARATION_SCOPE_MESSAGE, "path":"a.rb"})
}

fn assert_accounting(capture: &Capture) {
    assert_eq!(capture.diagnostic_bytes, serde_json::to_vec(&capture.diagnostics).unwrap().len());
    assert_eq!(schema::diagnostic_counts(&capture.diagnostics).unwrap(),
        json!({"groups":capture.diagnostics.len(), "occurrences":capture.diagnostic_occurrences}));
}

#[test]
fn repeated_warnings_keep_exact_counts_and_partial_coverage() {
    let root = tempfile::tempdir().unwrap();
    let source = format!("class Stable; def kept; end; end\n{}", "wrapper { def unknown; end }\n".repeat(12));
    std::fs::write(root.path().join("a.rb"), &source).unwrap();
    let captured = capture(root.path(), json!({"max_diagnostics":1})).unwrap();
    assert_eq!(captured["diagnostics"].as_array().unwrap().len(), 1);
    assert_eq!(captured["diagnostics"][0]["occurrences"], 12);
    assert_eq!(captured["diagnostics"][0]["message"], DECLARATION_SCOPE_MESSAGE);
    assert_eq!(captured["files"][0]["content"], source);
    assert!(captured["facts"].as_array().unwrap().iter().any(|f| f["name"] == "Stable#kept"));
    assert!(!captured["facts"].as_array().unwrap().iter().any(|f| f["name"].as_str().unwrap().contains("unknown")));
    let coverage = captured["coverage"].as_array().unwrap().iter().find(|c| c["family"] == "ruby_declarations").unwrap();
    assert_eq!(coverage["status"], "partial");
    assert_eq!(coverage["reason"], "Some declarations or relationships were unavailable; see diagnostics");
    let store = root.path().join("store");
    let published = store::publish(&store, &captured).unwrap();
    assert_eq!(published["diagnostics"], captured["diagnostics"]);
    Reader::open(&store, None).unwrap().check().unwrap();
}

#[test]
fn real_declaration_mixin_and_path_groups_remain_distinct() {
    let root = tempfile::tempdir().unwrap();
    let source = "class Stable\n wrapper { def unknown; end; include Tagged; include Tagged }\nend\n";
    for path in ["a.rb", "b.rb"] { std::fs::write(root.path().join(path), source).unwrap(); }
    let result = capture(root.path(), json!({"max_diagnostics":4})).unwrap();
    let records = result["diagnostics"].as_array().unwrap();
    assert_eq!(schema::diagnostic_counts(records).unwrap(), json!({"groups":4,"occurrences":6}));
    for path in ["a.rb", "b.rb"] {
        for (message, count) in [(DECLARATION_SCOPE_MESSAGE, 1), (MIXIN_SCOPE_MESSAGE, 2)] {
            let record = records.iter().find(|d| d["path"] == path && d["message"] == message).unwrap();
            assert_eq!(record["occurrences"], count);
        }
    }
    assert_eq!(capture(root.path(), json!({"max_diagnostics":3})).unwrap_err().code, "limit_exceeded");
}

#[test]
fn full_provenance_reason_and_unknown_fields_are_identity() {
    let mut capture = empty(json!({}));
    let base = warning();
    let mut variants = vec![base.clone()];
    for (key, value) in [("reason", json!("different")), ("path", json!("b.rb")),
        ("provenance", json!({"producer":"other"})), ("location", json!({"line":4})),
        ("message", json!(MIXIN_SCOPE_MESSAGE)), ("future", json!([1,2]))] {
        let mut record = base.clone(); record[key] = value; variants.push(record);
    }
    for record in &variants {
        capture.admit_diagnostic(record.clone()).unwrap();
        capture.admit_diagnostic(record.clone()).unwrap();
    }
    assert_eq!(capture.diagnostics.len(), variants.len());
    for (record, original) in capture.diagnostics.iter().zip(variants) {
        let mut expected = original; expected["occurrences"] = json!(2);
        assert_eq!(*record, expected);
    }
    assert_accounting(&capture);
}

#[test]
fn only_known_recoverable_classes_coalesce() {
    for record in [json!({"code":"syntax_error", "message":"same", "path":"a.rb"}),
        json!({"code":"fatal", "message":DECLARATION_SCOPE_MESSAGE, "path":"a.rb"}),
        json!({"code":"dynamic_scope", "message":"future reason", "path":"a.rb"}),
        json!({"code":"symlink_skipped", "message":"same", "path":"a.rb"})] {
        let mut capture = empty(json!({"max_diagnostics":2}));
        capture.admit_diagnostic(record.clone()).unwrap();
        capture.admit_diagnostic(record.clone()).unwrap();
        assert_eq!(capture.diagnostics.len(), 2);
        assert_eq!(capture.admit_diagnostic(record).unwrap_err().code, "limit_exceeded");
        assert_accounting(&capture);
    }
}

#[test]
fn encoded_growth_is_charged_before_mutation() {
    let mut capture = empty(json!({}));
    let mut record = warning();
    record["provenance"] = json!({"escaped":"\"\\\n\u{0000}é"});
    for _ in 0..9 { capture.admit_diagnostic(record.clone()).unwrap(); }
    assert_accounting(&capture);
    let old_size = capture.diagnostic_bytes;
    let limit = schema::MAX_DIAGNOSTIC_BYTES - schema::DIAGNOSTIC_SUMMARY_BYTES;
    capture.diagnostic_bytes = limit; // Inject the precise byte boundary, no huge parser fixture.
    assert_eq!(capture.admit_diagnostic(record.clone()).unwrap_err().code, "limit_exceeded");
    assert_eq!(capture.diagnostics[0]["occurrences"], 9);
    assert_eq!(capture.diagnostic_occurrences, 9);
    assert_eq!(capture.diagnostic_bytes, limit);
    capture.diagnostic_bytes = old_size;
    capture.admit_diagnostic(record).unwrap();
    assert_eq!(capture.diagnostic_bytes, old_size + 1); // 9 -> 10 encoded digits.
    assert_accounting(&capture);
    assert!(schema::diagnostic_budget(usize::MAX).is_err());
    schema::diagnostic_budget(limit).unwrap();
    assert!(schema::diagnostic_budget(limit + 1).is_err());
    capture.diagnostic_bytes = usize::MAX;
    let mut distinct = warning(); distinct["path"] = json!("b.rb");
    assert_eq!(capture.admit_diagnostic(distinct).unwrap_err().code, "limit_exceeded");
    assert_eq!(capture.diagnostics.len(), 1);
}

#[test]
fn group_and_total_count_overflow_refuse_without_mutation() {
    let mut capture = empty(json!({}));
    let mut max = warning(); max["occurrences"] = json!(u64::MAX);
    capture.admit_diagnostic(max).unwrap();
    assert_eq!(capture.admit_diagnostic(warning()).unwrap_err().code, "limit_exceeded");
    let mut distinct = warning(); distinct["path"] = json!("b.rb");
    assert_eq!(capture.admit_diagnostic(distinct).unwrap_err().code, "limit_exceeded");
    assert_eq!(capture.diagnostics.len(), 1);
    assert_eq!(capture.diagnostics[0]["occurrences"], u64::MAX);
    assert_accounting(&capture);
}

#[test]
fn parser_limits_and_fatal_input_resource_refusals_still_apply() {
    let root = tempfile::tempdir().unwrap();
    std::fs::write(root.path().join("broken.rb"), "class Broken\n def missing(").unwrap();
    let result = capture(root.path(), json!({})).unwrap();
    for record in result["diagnostics"].as_array().unwrap() {
        assert_eq!(record["code"], "syntax_error");
        assert_eq!(record["occurrences"], 1);
        assert_eq!(record["parser_policy"], PARSER_POLICY);
        assert_eq!(record["prism_version"], PRISM_VERSION);
        assert_eq!(record["ruby_syntax_version"], RUBY_SYNTAX_VERSION);
    }
    assert_eq!(capture(root.path(), json!({"max_diagnostics":1})).unwrap_err().code, "limit_exceeded");
    assert_eq!(capture(root.path(), json!({"max_file_bytes":1})).unwrap_err().code, "limit_exceeded");
    assert_eq!(capture(root.path(), json!({"unknown":1})).unwrap_err().code, "invalid_input");
    assert_eq!(capture(&root.path().join("missing"), json!({})).unwrap_err().code, "not_found");
}

#[test]
fn schema_legacy_counts_and_invalid_explicit_counts() {
    let old = warning();
    let mut explicit = old.clone(); explicit["occurrences"] = json!(3);
    assert_eq!(schema::diagnostic_counts(&[old.clone(), explicit]).unwrap(), json!({"groups":2,"occurrences":4}));
    for count in [json!(0), json!(-1), json!(1.0), json!("1"), json!(true), Value::Null] {
        let mut bad = old.clone(); bad["occurrences"] = count;
        assert_eq!(schema::diagnostic_counts(&[bad]).unwrap_err().code, "invalid_input");
    }
    assert_eq!(schema::diagnostic_counts(&[]).unwrap(), json!({"groups":0,"occurrences":0}));
}

fn assert_refusal_preserves_store(candidate: &Value, baseline: &Value, error: &str) {
    let root = tempfile::tempdir().unwrap();
    let missing = root.path().join("missing");
    assert_eq!(store::publish(&missing, candidate).unwrap_err().code, error);
    assert!(!missing.exists());
    let existing = root.path().join("existing");
    let published = store::publish(&existing, baseline).unwrap();
    let reader = Reader::open(&existing, None).unwrap();
    let pointer = std::fs::read(existing.join("CURRENT")).unwrap();
    assert_eq!(store::publish(&existing, candidate).unwrap_err().code, error);
    assert_eq!(std::fs::read(existing.join("CURRENT")).unwrap(), pointer);
    assert_eq!(Reader::open(&existing, None).unwrap().generation, published["generation"].as_str().unwrap());
    assert_eq!(reader.generation, published["generation"].as_str().unwrap());
    reader.check().unwrap();
    let fact = reader.facts.iter().find(|f| f["kind"] == "class").unwrap();
    assert!(reader.source(fact["id"].as_str().unwrap()).unwrap()["content"].as_str().unwrap().contains("Stable"));
}

#[test]
fn publication_rechecks_group_byte_and_count_admission_before_mutation() {
    let source = tempfile::tempdir().unwrap();
    std::fs::write(source.path().join("a.rb"), "class Stable; end\n").unwrap();
    let baseline = capture(source.path(), json!({})).unwrap();
    let mut candidate = baseline.clone();
    candidate["diagnostics"] = json!(vec![warning(); schema::MAX_DIAGNOSTIC_GROUPS + 1]);
    assert_refusal_preserves_store(&candidate, &baseline, "limit_exceeded");
    // Small raw payload, real JSON escaping exceeds the encoded byte cap.
    let mut oversized = warning(); oversized["provenance"] = json!("\u{0000}".repeat(schema::MAX_DIAGNOSTIC_BYTES / 6));
    candidate["diagnostics"] = json!([oversized]);
    assert_refusal_preserves_store(&candidate, &baseline, "limit_exceeded");
    let mut max = warning(); max["occurrences"] = json!(u64::MAX);
    candidate["diagnostics"] = json!([max, warning()]);
    assert_refusal_preserves_store(&candidate, &baseline, "limit_exceeded");
    let mut invalid = warning(); invalid["occurrences"] = json!(0);
    candidate["diagnostics"] = json!([invalid]);
    assert_refusal_preserves_store(&candidate, &baseline, "invalid_input");
}

#[test]
fn capture_saturation_never_reaches_publication() {
    let root = tempfile::tempdir().unwrap();
    let app = root.path().join("app"); std::fs::create_dir(&app).unwrap();
    std::fs::write(app.join("a.rb"), "class Stable; end\n").unwrap();
    let baseline = capture(&app, json!({})).unwrap();
    let existing = root.path().join("store");
    store::publish(&existing, &baseline).unwrap();
    let reader = Reader::open(&existing, None).unwrap();
    let pointer = std::fs::read(existing.join("CURRENT")).unwrap();
    for path in ["a.rb", "b.rb"] { std::fs::write(app.join(path), "wrapper { def unknown; end }\n").unwrap(); }
    for output in [root.path().join("missing"), existing.clone()] {
        let result = capture(&app, json!({"max_diagnostics":1})).and_then(|v| store::publish(&output, &v));
        assert_eq!(result.unwrap_err().code, "limit_exceeded");
    }
    assert!(!root.path().join("missing").exists());
    assert_eq!(std::fs::read(existing.join("CURRENT")).unwrap(), pointer);
    reader.check().unwrap();
}
