// AUTHORED UNRUN under the source-only lease. No parser or application boot.
use super::*;
use std::{fs, os::unix::fs::symlink};

struct Fixture { _temp: tempfile::TempDir, root: std::path::PathBuf, store: std::path::PathBuf, reader: Reader }
impl Fixture {
    fn new(content: &str) -> Self {
        let temp = tempfile::tempdir().unwrap();
        let base = temp.path().canonicalize().unwrap();
        let root = base.join("workspace"); let store = base.join("store");
        fs::create_dir_all(root.join("sub")).unwrap();
        fs::write(root.join("sub/source.rb"), content).unwrap();
        crate::store::publish(&store, &capture(content)).unwrap();
        let reader = Reader::open(&store, None).unwrap();
        Self { _temp: temp, root, store, reader }
    }
    fn request(&self) -> Value { json!({"file_path":"sub/source.rb","workspace_root":self.root.to_str().unwrap()}) }
    fn run(&self) -> Value { select(&self.reader, &Query::parse(&self.request()).unwrap()).unwrap() }
    fn hooked(&self, hook: &mut dyn FnMut(Event) -> io::Result<()>) -> Value {
        let request = self.request(); let query = Query::parse(&request).unwrap();
        select_observed(&self.reader, &query, &mut Observer { hook:Some(hook), lifetime:std::marker::PhantomData }).unwrap()
    }
}
fn capture(content: &str) -> Value {
    json!({"root_id":"a".repeat(64),"producer":{"name":"public-freshness-fixture"},
        "files":[{"path":"sub/source.rb","sha256":schema::digest(content.as_bytes()),"bytes":content.len(),"encoding":"UTF-8","content":content}],
        "facts":[],"coverage":[{"family":"ruby","status":"partial","scope":"fixture","reason":"No runtime evidence"}],"diagnostics":[]})
}
fn reason(value: &Value, expected: &str) {
    assert_eq!(value["status"], "unverifiable"); assert_eq!(value["reason"], expected);
    assert!(value["usage"]["bytes_read"].as_u64().unwrap() <= value["limits"]["max_read_bytes"].as_u64().unwrap());
}

#[test]
fn matching_changed_and_empty_are_complete_bounded_comparisons() {
    let f = Fixture::new("saved A\n"); let result = f.run();
    assert_eq!(result["status"], "matching");
    assert_eq!(result["usage"]["bytes_read"], 8);
    assert_eq!(result["usage"]["bytes_hashed"], 8);
    assert_eq!(result["usage"]["read_attempts"], 2);
    assert!(result.get("content").is_none());
    let encoded = serde_json::to_string(&result).unwrap();
    assert!(!encoded.contains(f.root.to_str().unwrap())); assert!(!encoded.contains("saved A"));
    fs::write(f.root.join("sub/source.rb"), "changed\n").unwrap();
    assert_eq!(f.run()["status"], "changed");
    let empty = Fixture::new(""); let mut request = empty.request(); request["max_bytes"] = json!(0);
    let result = select(&empty.reader, &Query::parse(&request).unwrap()).unwrap();
    assert_eq!(result["status"], "matching"); assert_eq!(result["usage"]["read_attempts"], 1);
    let mut request = f.request(); request["max_bytes"] = json!(8);
    assert_eq!(select(&f.reader, &Query::parse(&request).unwrap()).unwrap()["status"], "changed");
}

#[test]
fn selected_metadata_and_nil_root_precede_live_access() {
    let f = Fixture::new("A"); let mut request = f.request(); request["workspace_root"] = Value::Null;
    let result = select(&f.reader, &Query::parse(&request).unwrap()).unwrap();
    assert_eq!(result["status"], "not_checked"); assert_eq!(result["usage"]["io_attempts"], 0);
    request["workspace_root"] = json!("/unavailable/root"); request["file_path"] = json!("uncaptured.rb");
    let mut touched = false;
    let mut hook = |_| { touched = true; Ok(()) };
    let error = select_observed(&f.reader, &Query::parse(&request).unwrap(),
        &mut Observer { hook:Some(&mut hook), lifetime:std::marker::PhantomData }).unwrap_err();
    assert_eq!(error.code, "not_found"); assert!(!touched);
    assert!(f.reader.source_index.lock().unwrap().is_none());
    for path in ["../escape.rb", "/absolute.rb", "sub/../source.rb", "sub//source.rb"] {
        request["file_path"] = json!(path); assert!(Query::parse(&request).is_err());
    }
}

#[test]
fn missing_unreadable_and_injected_read_failure_never_match() {
    let f = Fixture::new("A");
    let unreadable = f.hooked(&mut |event| {
        if matches!(event, Event::BeforeOpen) { Err(io::Error::from(io::ErrorKind::PermissionDenied)) } else { Ok(()) }
    });
    reason(&unreadable, "unreadable"); assert_eq!(unreadable["usage"]["io_attempts"], 0);
    let failed = f.hooked(&mut |event| {
        if matches!(event, Event::BeforeRead) { Err(io::Error::other("private injected detail")) } else { Ok(()) }
    });
    reason(&failed, "read_failed"); assert!(!failed.to_string().contains("private injected"));
    fs::remove_file(f.root.join("sub/source.rb")).unwrap(); reason(&f.run(), "missing");
}

#[test]
fn root_escape_symlink_ancestors_parents_leaves_and_nonregular_are_refused() {
    let f = Fixture::new("A"); let mut request = f.request();
    for root in ["/", "relative", "/tmp/../escape", "/tmp/./root", "/tmp//root", "/tmp/root/", "/tmp/\0root"] {
        request["workspace_root"] = json!(root);
        let result = select(&f.reader, &Query::parse(&request).unwrap()).unwrap();
        reason(&result, "unsafe_root"); assert_eq!(result["usage"]["io_attempts"], 0);
    }
    let alias = f.root.with_file_name("alias"); symlink(&f.root, &alias).unwrap();
    for root in [alias.clone(), alias.join("sub")] {
        request["workspace_root"] = json!(root.to_str().unwrap());
        reason(&select(&f.reader, &Query::parse(&request).unwrap()).unwrap(), "unsafe_path_or_nonregular");
    }
    fs::rename(f.root.join("sub"), f.root.join("real")).unwrap();
    symlink("real", f.root.join("sub")).unwrap(); reason(&f.run(), "unsafe_path_or_nonregular");
    fs::remove_file(f.root.join("sub")).unwrap(); fs::rename(f.root.join("real"), f.root.join("sub")).unwrap();
    fs::rename(f.root.join("sub/source.rb"), f.root.join("sub/original")).unwrap();
    symlink("original", f.root.join("sub/source.rb")).unwrap(); reason(&f.run(), "unsafe_path_or_nonregular");
    fs::remove_file(f.root.join("sub/source.rb")).unwrap();
    let fifo = std::ffi::CString::new(f.root.join("sub/source.rb").to_str().unwrap()).unwrap();
    assert_eq!(unsafe { libc::mkfifo(fifo.as_ptr(), 0o600) }, 0);
    reason(&f.run(), "unsafe_path_or_nonregular");
    fs::remove_file(f.root.join("sub/source.rb")).unwrap(); fs::create_dir(f.root.join("sub/source.rb")).unwrap();
    reason(&f.run(), "unsafe_path_or_nonregular");
}

#[test]
fn finite_byte_root_depth_and_work_admission_preserve_actual_charges() {
    let f = Fixture::new("A"); let mut request = f.request(); request["max_bytes"] = json!(0);
    let result = select(&f.reader, &Query::parse(&request).unwrap()).unwrap();
    reason(&result, "byte_limit"); assert_eq!(result["usage"]["read_attempts"], 0);
    request["workspace_root"] = json!(format!("/{}", "a".repeat(PATH_BYTES)));
    reason(&select(&f.reader, &Query::parse(&request).unwrap()).unwrap(), "root_limit");
    request["workspace_root"] = json!(format!("/{}", vec!["a"; DEPTH+1].join("/")));
    reason(&select(&f.reader, &Query::parse(&request).unwrap()).unwrap(), "root_limit");
    let mut deep = capture("A");
    let deep_path = vec!["a"; DEPTH+1].join("/"); deep["files"][0]["path"] = json!(deep_path);
    let deep_generation = crate::store::publish(&f.store, &deep).unwrap();
    let deep_reader = Reader::open(&f.store, deep_generation["generation"].as_str()).unwrap();
    let deep_request = json!({"file_path":deep_path,"workspace_root":f.root.to_str().unwrap()});
    let refused = select(&deep_reader, &Query::parse(&deep_request).unwrap()).unwrap();
    reason(&refused, "path_limit"); assert_eq!(refused["usage"]["io_attempts"], 0);
    let mut usage = Usage::default();
    for _ in 0..IO_ATTEMPTS { usage.attempt(Attempt::Stat).unwrap(); }
    assert_eq!(usage.attempt(Attempt::Read), Err("work_limit")); assert_eq!(usage.reads, 0);
    request["max_bytes"] = json!(schema::MAX_SOURCE+1); assert!(Query::parse(&request).is_err());
    assert!(crate::query::Budget::new(SCRATCH-1).reserve(SCRATCH).is_err());
}

#[test]
fn interruption_and_incomplete_reads_retain_partial_work() {
    let f = Fixture::new(&"x".repeat(CHUNK+1)); let mut calls = 0;
    let result = f.hooked(&mut |event| {
        if matches!(event, Event::BeforeRead) { calls+=1; if calls==2 { return Err(io::Error::from(io::ErrorKind::Interrupted)); } }
        Ok(())
    });
    reason(&result, "interrupted"); assert_eq!(result["usage"]["bytes_read"], CHUNK);
    assert_eq!(result["usage"]["bytes_hashed"], CHUNK); assert_eq!(result["usage"]["read_attempts"], 1);
    let result = f.hooked(&mut |event| {
        if matches!(event, Event::Opened) { fs::write(f.root.join("sub/source.rb"), "").unwrap(); } Ok(())
    });
    reason(&result, "incomplete_read");
}

#[test]
fn eof_probe_requires_complete_extent_and_charges_its_actual_byte() {
    let f = Fixture::new("A"); let mut calls = 0;
    let result = f.hooked(&mut |event| {
        if matches!(event, Event::BeforeRead) {
            calls += 1;
            if calls == 2 { fs::write(f.root.join("sub/source.rb"), "AB").unwrap(); }
        } Ok(())
    });
    reason(&result, "incomplete_read"); assert_eq!(result["usage"]["bytes_read"], 2);
    assert_eq!(result["usage"]["bytes_hashed"], 2); assert_eq!(result["usage"]["read_attempts"], 2);
    let empty = Fixture::new("");
    let result = empty.hooked(&mut |event| {
        if matches!(event, Event::BeforeRead) { fs::write(empty.root.join("sub/source.rb"), "x").unwrap(); } Ok(())
    });
    reason(&result, "incomplete_read"); assert_eq!(result["usage"]["bytes_read"], 1);
}

#[test]
fn descriptor_mutation_leaf_and_absolute_ancestor_replacement_are_detected() {
    for stage in [Event::ReadComplete, Event::BeforeRevalidate] {
        let f = Fixture::new("A");
        let result = f.hooked(&mut |event| {
            if std::mem::discriminant(&event)==std::mem::discriminant(&stage) {
                let next=f.root.join("sub/next"); fs::write(&next,"A").unwrap(); fs::rename(&next,f.root.join("sub/source.rb")).unwrap();
            } Ok(())
        }); reason(&result, "concurrent_change");
    }
    let f = Fixture::new("A");
    let result = f.hooked(&mut |event| {
        if matches!(event, Event::ReadComplete) { fs::write(f.root.join("sub/source.rb"), "longer").unwrap(); } Ok(())
    }); reason(&result, "concurrent_change");
    let f = Fixture::new("A");
    let result = f.hooked(&mut |event| {
        if matches!(event, Event::BeforeRevalidate) {
            fs::rename(&f.root,f.root.with_file_name("moved")).unwrap();
            fs::create_dir_all(f.root.join("sub")).unwrap(); fs::write(f.root.join("sub/source.rb"), "A").unwrap();
        } Ok(())
    }); reason(&result, "concurrent_change");
}

#[test]
fn saved_a_after_current_b_source_edits_and_check_are_independent() {
    let f = Fixture::new("A"); let generation=f.reader.generation.clone();
    let b=crate::store::publish(&f.store, &capture("B")).unwrap(); assert_ne!(b["generation"], generation);
    let current_before=fs::read(f.store.join("CURRENT")).unwrap();
    fs::write(f.root.join("sub/source.rb"), "disk changed").unwrap();
    let result=f.run(); assert_eq!(result["generation"], generation); assert_eq!(result["status"], "changed");
    assert_eq!(f.reader.source_file("sub/source.rb").unwrap()["content"], "A");
    assert_eq!(f.reader.check().unwrap()["freshness"], "not_checked");
    assert_eq!(current_before,fs::read(f.store.join("CURRENT")).unwrap());
    let blob=f.store.join("blobs").join(schema::digest(b"A"));
    fs::write(blob,"corrupt").unwrap();
    fs::write(f.root.join("sub/source.rb"), "A").unwrap();
    // A matching recorded digest makes no saved-blob-integrity claim.
    assert_eq!(f.run()["status"], "matching"); assert!(f.reader.check().is_err());
}
