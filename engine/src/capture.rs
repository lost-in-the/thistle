//! Bounded source inventory and Ruby syntax evidence in the native engine.
//!
//! Prism parses source without executing it. Facts carry lexical labels and
//! unresolved relationships; Ruby/Rails runtime behavior is a separate producer.

use crate::error::{CoreError, Result};
use crate::schema;
use ruby_prism::{Location, Node};
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::ffi::{CStr, CString};
use std::fs::{File, Metadata, OpenOptions};
use std::io::Read;
use std::os::fd::{AsRawFd, FromRawFd};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt};
use std::path::{Component, Path};
use std::rc::Rc;
use std::sync::atomic::{AtomicBool, Ordering};

#[path = "capture_children.rs"]
mod children;

const EXCLUDED: &[&str] = &[".git", ".thistle", "vendor", "node_modules", "tmp", "target"];
const PRISM_VERSION: &str = "1.9.0";
const PARSER_STACK_BYTES: usize = 64 * 1024 * 1024;
static CAPTURE_ACTIVE: AtomicBool = AtomicBool::new(false);
const DEFAULT_LIMITS: &[(&str, usize)] = &[
    ("max_files", 10_000),
    ("max_file_bytes", 2 * 1024 * 1024),
    ("max_total_bytes", 64 * 1024 * 1024),
    ("max_entries", 100_000),
    ("max_depth", 64),
    ("max_nodes", 1_000_000),
    ("max_facts", 100_000),
    ("max_links", 500_000),
    ("max_routes", 20_000),
    ("max_diagnostics", 1_000),
];

#[derive(Clone)]
struct Scope {
    owner: String,
    namespace: Option<String>,
    singleton: bool,
    current: Option<usize>,
    dynamic: bool,
}

struct Capture {
    limits: HashMap<String, usize>,
    files: Vec<Value>,
    facts: Vec<Value>,
    diagnostics: Vec<Value>,
    entries: usize,
    total_bytes: usize,
    nodes: usize,
    links: usize,
    evidence_bytes: usize,
    link_keys: HashSet<(usize, String, String)>,
    inventory_partial: bool,
    declarations_partial: bool,
}

struct CapturePermit;
impl Drop for CapturePermit {
    fn drop(&mut self) { CAPTURE_ACTIVE.store(false, Ordering::Release); }
}

pub fn capture(root: &Path, limits: &Value) -> Result<Value> {
    if CAPTURE_ACTIVE.compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire).is_err() {
        return Err(CoreError::new("busy", "A native capture is already active; retry after it completes"));
    }
    let _permit = CapturePermit;
    let root = root.to_path_buf();
    let limits = limits.clone();
    // Prism's C parser and AST destructor recurse. Ruby worker stacks are much
    // smaller than its depth guard assumes. Keep parsing and destruction on one
    // explicitly sized native stack, and bound concurrency to one capture.
    // This is not a sandbox or a CPU deadline; controller workers remain needed
    // for hostile-input qualification and enforced process resource limits.
    std::thread::Builder::new()
        .name("thistle-capture".to_owned())
        .stack_size(PARSER_STACK_BYTES)
        .spawn(move || capture_inner(&root, &limits))?
        .join()
        .map_err(|_| CoreError::new("internal_error", "Native capture worker panicked; no result was published"))?
}

fn capture_inner(root: &Path, limits: &Value) -> Result<Value> {
    let mut effective: HashMap<String, usize> = DEFAULT_LIMITS
        .iter()
        .map(|(key, value)| ((*key).to_owned(), *value))
        .collect();
    if !limits.is_null() {
        let values = limits.as_object().ok_or_else(|| CoreError::input("Capture limits must be an object"))?;
        for (key, value) in values {
            let ceiling = effective.get(key).ok_or_else(|| CoreError::input(format!("Unknown capture limit: {key}")))?;
            let supplied = value.as_u64().ok_or_else(|| CoreError::input(format!("Capture limit {key} must be a positive integer")))?;
            if supplied == 0 || supplied > *ceiling as u64 {
                return Err(CoreError::input(format!("Capture limit {key} must be between 1 and {ceiling}")));
            }
            effective.insert(key.to_owned(), supplied as usize);
        }
    }
    let canonical = std::fs::canonicalize(root)?;
    let canonical_text = canonical.to_str().ok_or_else(|| CoreError::input("Capture root must be valid UTF-8"))?;
    let directory = open_root(&canonical)?;
    let mut capture = Capture {
        limits: effective,
        files: Vec::new(), facts: Vec::new(), diagnostics: Vec::new(),
        entries: 0, total_bytes: 0, nodes: 0, links: 0, evidence_bytes: 2,
        link_keys: HashSet::new(), inventory_partial: false, declarations_partial: false,
    };
    capture.walk(&directory, "", 0)?;
    capture.files.sort_by(|a, b| a["path"].as_str().cmp(&b["path"].as_str()));
    capture.facts.sort_by(|a, b| {
        (a["path"].as_str(), a["location"]["start_byte"].as_u64(), a["kind"].as_str(), a["name"].as_str(), a["id"].as_str())
            .cmp(&(b["path"].as_str(), b["location"]["start_byte"].as_u64(), b["kind"].as_str(), b["name"].as_str(), b["id"].as_str()))
    });
    for fact in &mut capture.facts {
        if let Some(links) = fact["links"].as_array_mut() {
            links.sort_by(|a, b| (a["relation"].as_str(), a["target"].as_str()).cmp(&(b["relation"].as_str(), b["target"].as_str())));
        }
    }
    let coverage = capture.coverage();
    Ok(json!({
        "root_id": schema::digest(canonical_text.as_bytes()),
        "files": capture.files, "facts": capture.facts,
        "coverage": coverage, "diagnostics": capture.diagnostics,
        "producer": { "name": "thistle", "engine": "rust", "core_version": env!("CARGO_PKG_VERSION"), "capture_schema": 1,
            "prism_version": PRISM_VERSION, "parser_stack_bytes":PARSER_STACK_BYTES, "capture_concurrency":1 }
    }))
}

fn open_root(root: &Path) -> Result<File> {
    let mut current = OpenOptions::new().read(true).custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC).open("/")?;
    for component in root.components() {
        match component {
            Component::RootDir => (),
            Component::Normal(name) => {
                let name = CString::new(name.as_bytes()).map_err(|_| CoreError::input("Capture path contains NUL"))?;
                current = open_at(&current, &name, true)?;
            }
            _ => return Err(CoreError::input("Expected a canonical absolute source root")),
        }
    }
    Ok(current)
}

fn open_at(parent: &File, name: &CStr, directory: bool) -> Result<File> {
    let mut flags = libc::O_RDONLY | libc::O_CLOEXEC | libc::O_NOFOLLOW | libc::O_NONBLOCK;
    if directory { flags |= libc::O_DIRECTORY; }
    // SAFETY: parent is a live owned descriptor; name is a terminated C string.
    // NOFOLLOW applies to this one component; every ancestor is already pinned.
    let raw = unsafe { libc::openat(parent.as_raw_fd(), name.as_ptr(), flags) };
    if raw < 0 { return Err(std::io::Error::last_os_error().into()); }
    // SAFETY: openat returned a new descriptor and File takes its sole ownership.
    Ok(unsafe { File::from_raw_fd(raw) })
}

struct DirectoryStream(*mut libc::DIR);
impl Drop for DirectoryStream {
    fn drop(&mut self) {
        // SAFETY: this object owns a successful fdopendir result exactly once.
        unsafe { libc::closedir(self.0); }
    }
}

fn metadata_signature(meta: &Metadata) -> (u64, u64, u64, i64, i64, i64, i64) {
    (meta.dev(), meta.ino(), meta.len(), meta.mtime(), meta.mtime_nsec(), meta.ctime(), meta.ctime_nsec())
}

impl Capture {
    fn limit(&self, key: &str) -> usize { self.limits[key] }

    fn walk(&mut self, directory: &File, relative: &str, depth: usize) -> Result<()> {
        if depth > self.limit("max_depth") { return Err(CoreError::limit("Source tree exceeds max_depth")); }
        // Opening '.' produces a new directory position; dup would share its
        // offset with any caller reusing the same descriptor.
        let dot = CString::new(".").expect("literal");
        let stream_file = open_at(directory, &dot, true)?;
        use std::os::fd::IntoRawFd;
        let raw = stream_file.into_raw_fd();
        // SAFETY: raw is a newly owned directory descriptor transferred on success.
        let stream = unsafe { libc::fdopendir(raw) };
        if stream.is_null() {
            let error = std::io::Error::last_os_error();
            // SAFETY: failed fdopendir did not take descriptor ownership.
            unsafe { libc::close(raw); }
            return Err(error.into());
        }
        let stream = DirectoryStream(stream);
        let mut names = Vec::new();
        loop {
            // SAFETY: stream remains open; returned dirent is copied before the
            // next readdir. errno is thread-local on this supported Linux build.
            unsafe { *libc::__errno_location() = 0; }
            let entry = unsafe { libc::readdir(stream.0) };
            if entry.is_null() {
                let error = std::io::Error::last_os_error();
                if error.raw_os_error() != Some(0) { return Err(error.into()); }
                break;
            }
            let bytes = unsafe { CStr::from_ptr((*entry).d_name.as_ptr()) }.to_bytes();
            if bytes == b"." || bytes == b".." { continue; }
            self.entries += 1;
            if self.entries > self.limit("max_entries") { return Err(CoreError::limit("Source tree exceeds max_entries")); }
            let name = std::str::from_utf8(bytes).map_err(|_| CoreError::input("Source filename is not valid UTF-8"))?;
            names.push(name.to_owned());
        }
        drop(stream);
        names.sort();
        for name in names {
            let relative_path = if relative.is_empty() { name.clone() } else { format!("{relative}/{name}") };
            schema::path(&relative_path)?;
            let c_name = CString::new(name.as_bytes()).map_err(|_| CoreError::input("Source filename contains NUL"))?;
            let mut stat = std::mem::MaybeUninit::<libc::stat>::uninit();
            // SAFETY: stat is written by fstatat on success; no symlink is followed.
            if unsafe { libc::fstatat(directory.as_raw_fd(), c_name.as_ptr(), stat.as_mut_ptr(), libc::AT_SYMLINK_NOFOLLOW) } != 0 {
                return Err(std::io::Error::last_os_error().into());
            }
            let stat = unsafe { stat.assume_init() };
            let kind = stat.st_mode & libc::S_IFMT;
            if kind == libc::S_IFLNK {
                self.inventory_partial = true;
                self.diagnostic("symlink_skipped", "Symbolic links are outside the capture scope", &relative_path)?;
                continue;
            }
            if kind == libc::S_IFDIR && EXCLUDED.contains(&name.as_str()) { continue; }
            let source = source_name(&name);
            if kind != libc::S_IFDIR && !source { continue; }
            if kind != libc::S_IFDIR && kind != libc::S_IFREG {
                self.inventory_partial = true;
                self.diagnostic("non_regular_file", "Only regular source files are captured", &relative_path)?;
                continue;
            }
            let mut child = open_at(directory, &c_name, kind == libc::S_IFDIR)?;
            let before = child.metadata()?;
            if before.is_dir() {
                self.walk(&child, &relative_path, depth + 1)?;
            } else if before.is_file() && source {
                self.read_file(&mut child, &relative_path, &before)?;
            } else {
                return Err(CoreError::new("source_changed", "Source entry changed type during capture; retry"));
            }
        }
        Ok(())
    }

    fn read_file(&mut self, file: &mut File, path: &str, before: &Metadata) -> Result<()> {
        if self.files.len() >= self.limit("max_files") { return Err(CoreError::limit("Source inventory exceeds max_files")); }
        if before.len() > self.limit("max_file_bytes") as u64 { return Err(CoreError::limit(format!("Source file exceeds max_file_bytes: {path}"))); }
        if self.total_bytes + before.len() as usize > self.limit("max_total_bytes") { return Err(CoreError::limit("Source inventory exceeds max_total_bytes")); }
        let mut content = Vec::with_capacity(before.len() as usize);
        file.take(self.limit("max_file_bytes") as u64 + 1).read_to_end(&mut content)?;
        if content.len() > self.limit("max_file_bytes") { return Err(CoreError::limit(format!("Source file exceeds max_file_bytes: {path}"))); }
        let after = file.metadata()?;
        if metadata_signature(before) != metadata_signature(&after) || after.len() != content.len() as u64 {
            return Err(CoreError::new("source_changed", format!("Source changed while it was read: {path}; retry capture")));
        }
        self.total_bytes += content.len();
        if self.total_bytes > self.limit("max_total_bytes") { return Err(CoreError::limit("Source inventory exceeds max_total_bytes")); }
        let text = match std::str::from_utf8(&content) {
            Ok(text) => text,
            Err(_) => {
                self.inventory_partial = true; self.declarations_partial = true;
                return self.diagnostic("unsupported_encoding", "Only source whose exact bytes are valid UTF-8 is captured", path);
            }
        };
        if path.ends_with(".rs") {
            let lines = LineIndex::new(&content);
            let digest = schema::digest(&content);
            self.add_fact("file", path, path, json!({
                "start_line":1, "end_line":lines.file_end_line(&content), "start_byte":0, "end_byte":content.len()
            }), json!({"sha256":digest,"bytes":content.len(),"language":"rust","parse_status":"not_parsed"}))?;
            self.files.push(json!({"path":path,"sha256":digest,"bytes":content.len(),"encoding":"UTF-8","content":text}));
            return Ok(());
        }
        let parsed = ruby_prism::parse(&content);
        for comment in parsed.magic_comments() {
            let key = String::from_utf8_lossy(comment.key()).to_ascii_lowercase();
            if key == "coding" || key == "encoding" {
                let value = String::from_utf8_lossy(comment.value()).to_ascii_lowercase().replace(['-', '_'], "");
                if !matches!(value.as_str(), "utf8" | "usascii" | "ascii") {
                    self.inventory_partial = true; self.declarations_partial = true;
                    return self.diagnostic("unsupported_encoding", "Ruby's declared encoding is not UTF-8 or US-ASCII; source omitted to preserve byte locations", path);
                }
            }
        }
        let lines = LineIndex::new(&content);
        let errors: Vec<_> = parsed.errors().take(self.limit("max_diagnostics") + 1).collect();
        if errors.len() > self.limit("max_diagnostics") { return Err(CoreError::limit("Capture exceeds max_diagnostics")); }
        let file_position = json!({"start_line":1, "end_line":lines.file_end_line(&content), "start_byte":0, "end_byte":content.len()});
        self.add_fact("file", path, path, file_position, json!({
            "sha256":schema::digest(&content), "bytes":content.len(), "language":"ruby", "parse_status":if errors.is_empty() { "valid" } else { "invalid" }
        }))?;
        self.files.push(json!({ "path":path, "sha256":schema::digest(&content), "bytes":content.len(), "encoding":"UTF-8", "content":text }));
        if !errors.is_empty() {
            self.declarations_partial = true;
            for error in errors {
                let message = format!("Line {}: {}", lines.line(error.location().start_offset()), error.message());
                self.diagnostic("syntax_error", &message, path)?;
            }
            return Ok(());
        }
        self.extract(parsed.node(), path, &lines)
    }

    fn extract<'pr>(&mut self, root: Node<'pr>, path: &str, lines: &LineIndex) -> Result<()> {
        let initial = Rc::new(Scope { owner:"Object".to_owned(), namespace:None, singleton:false, current:None, dynamic:false });
        let mut pending = vec![(root, initial)];
        while let Some((node, scope)) = pending.pop() {
            self.nodes += 1;
            if self.nodes > self.limit("max_nodes") { return Err(CoreError::limit("Parsed sources exceed max_nodes")); }
            if let Some(class) = node.as_class_node() {
                if scope.dynamic || scope.singleton { self.uncertain_scope(path)?; continue; }
                let raw = constant_expression(&class.constant_path());
                let (name, resolution) = declaration_name(&raw, scope.namespace.as_deref());
                let index = self.add_fact("class", &name, path, lines.location(&class.location()), json!({
                    "declaration_name":raw, "lexical_scope":scope.namespace.iter().collect::<Vec<_>>(), "name_resolution":resolution
                }))?;
                if let Some(parent) = class.superclass() { self.add_link(index, "inherits", parent.location().as_slice(), path)?; }
                let next = Rc::new(Scope { owner:name.clone(), namespace:Some(name), singleton:false, current:Some(index), dynamic:false });
                if let Some(body) = class.body() { pending.push((body, next)); }
            } else if let Some(module) = node.as_module_node() {
                if scope.dynamic || scope.singleton { self.uncertain_scope(path)?; continue; }
                let raw = constant_expression(&module.constant_path());
                let (name, resolution) = declaration_name(&raw, scope.namespace.as_deref());
                let index = self.add_fact("module", &name, path, lines.location(&module.location()), json!({
                    "declaration_name":raw, "lexical_scope":scope.namespace.iter().collect::<Vec<_>>(), "name_resolution":resolution
                }))?;
                let next = Rc::new(Scope { owner:name.clone(), namespace:Some(name), singleton:false, current:Some(index), dynamic:false });
                if let Some(body) = module.body() { pending.push((body, next)); }
            } else if let Some(method) = node.as_def_node() {
                if scope.dynamic { self.uncertain_scope(path)?; continue; }
                let (owner, singleton, resolution) = if let Some(receiver) = method.receiver() {
                    if receiver.as_self_node().is_some() {
                        if scope.singleton || self.in_method(&scope) { self.uncertain_scope(path)?; continue; }
                        (if scope.namespace.is_none() { "<main>".to_owned() } else { scope.owner.clone() }, true, "lexical")
                    } else { (text(receiver.location().as_slice()), true, "unresolved_receiver") }
                } else {
                    (if scope.singleton && scope.namespace.is_none() { "<main>".to_owned() } else { scope.owner.clone() }, scope.singleton, "lexical")
                };
                let method_name = text(method.name().as_slice());
                let name = format!("{owner}{}{method_name}", if singleton { "." } else { "#" });
                let parameters = method.parameters().map(|parameters| text(parameters.location().as_slice()));
                let index = self.add_fact("method", &name, path, lines.location(&method.location()), json!({
                    "owner":owner, "singleton":singleton, "method_name":method_name,
                    "name_resolution":resolution, "lexical_scope":scope.namespace.iter().collect::<Vec<_>>(), "parameters_source":parameters
                }))?;
                let next = Rc::new(Scope { current:Some(index), ..(*scope).clone() });
                if let Some(body) = method.body() { pending.push((body, Rc::clone(&next))); }
                if let Some(parameters) = method.parameters() { pending.push((parameters.as_node(), next)); }
            } else if let Some(singleton) = node.as_singleton_class_node() {
                if singleton.expression().as_self_node().is_some() && !scope.dynamic && !scope.singleton && !self.in_method(&scope) {
                    if let Some(body) = singleton.body() { pending.push((body, Rc::new(Scope { singleton:true, ..(*scope).clone() }))); }
                } else { self.uncertain_scope(path)?; }
            } else if node.as_block_node().is_some() || node.as_lambda_node().is_some() {
                let next = Rc::new(Scope { dynamic:true, ..(*scope).clone() });
                children::for_each_child(&node, |child| pending.push((child, Rc::clone(&next))));
            } else {
                if let Some(call) = node.as_call_node() { self.collect_call(&call, &scope, path)?; }
                children::for_each_child(&node, |child| pending.push((child, Rc::clone(&scope))));
            }
        }
        Ok(())
    }

    fn collect_call(&mut self, call: &ruby_prism::CallNode<'_>, scope: &Scope, path: &str) -> Result<()> {
        let Some(current) = scope.current else { return Ok(()); };
        let name = text(call.name().as_slice());
        let receiver_is_self = call.receiver().map_or(true, |receiver| receiver.as_self_node().is_some());
        let namespace = matches!(self.facts[current]["kind"].as_str(), Some("class") | Some("module"));
        if (scope.dynamic || scope.singleton) && receiver_is_self && namespace && matches!(name.as_str(), "include" | "extend" | "prepend") {
            self.declarations_partial = true;
            return self.diagnostic("dynamic_scope", "A mixin call in a block or singleton namespace has an unverified owner and was not attached to the ordinary class", path);
        }
        if receiver_is_self && namespace && matches!(name.as_str(), "include" | "extend" | "prepend") {
            let relation = match name.as_str() { "include" => "includes", "extend" => "extends", _ => "prepends" };
            if let Some(arguments) = call.arguments() {
                for argument in &arguments.arguments() { self.add_link(current, relation, argument.location().as_slice(), path)?; }
            }
        } else if let Some(receiver) = call.receiver() {
            let location = receiver.location();
            if location.as_slice().len() > 1_000 {
                self.declarations_partial = true;
                return self.diagnostic("link_expression_too_large", "A relationship receiver exceeded 1000 bytes and is unavailable", path);
            }
            let target = format!("{}.{name}", text(location.as_slice()));
            self.add_link(current, "calls", target.as_bytes(), path)?;
        } else {
            self.add_link(current, "calls", name.as_bytes(), path)?;
        }
        Ok(())
    }

    fn add_fact(&mut self, kind: &str, name: &str, path: &str, position: Value, attributes: Value) -> Result<usize> {
        if self.facts.len() >= self.limit("max_facts") { return Err(CoreError::limit("Capture exceeds max_facts")); }
        if name.is_empty() || name.len() > 4_096 { return Err(CoreError::limit("Declaration name is empty or exceeds 4096 bytes")); }
        let identity = serde_json::to_vec(&json!(["ruby", kind, name, path, position["start_byte"]]))?;
        let index = self.facts.len();
        let fact = json!({
            "id":schema::digest(&identity), "kind":kind, "name":name, "path":path,
            "location":position, "evidence":"static", "attributes":attributes, "links":[]
        });
        self.charge_evidence(serde_json::to_vec(&fact)?.len() + 1)?;
        self.facts.push(fact);
        Ok(index)
    }

    fn in_method(&self, scope: &Scope) -> bool {
        scope.current.is_some_and(|index| self.facts[index]["kind"] == "method")
    }

    fn add_link(&mut self, current: usize, relation: &str, target: &[u8], path: &str) -> Result<()> {
        if target.len() > 1_024 {
            self.declarations_partial = true;
            return self.diagnostic("link_expression_too_large", "A relationship expression exceeded 1024 bytes and is unavailable", path);
        }
        let target = text(target);
        if !self.link_keys.insert((current, relation.to_owned(), target.clone())) { return Ok(()); }
        self.links += 1;
        if self.links > self.limit("max_links") { return Err(CoreError::limit("Capture exceeds max_links")); }
        let link = json!({"relation":relation,"target":target,"resolution":"unresolved"});
        self.charge_evidence(serde_json::to_vec(&link)?.len() + 1)?;
        self.facts[current]["links"].as_array_mut().expect("fact links array").push(link);
        Ok(())
    }

    fn charge_evidence(&mut self, bytes: usize) -> Result<()> {
        self.evidence_bytes = self.evidence_bytes.checked_add(bytes)
            .ok_or_else(|| CoreError::limit("Capture evidence size overflow"))?;
        if self.evidence_bytes > schema::MAX_FACTS_BYTES {
            return Err(CoreError::limit("Capture fact evidence exceeds the 64 MiB payload budget"));
        }
        Ok(())
    }

    fn diagnostic(&mut self, code: &str, message: &str, path: &str) -> Result<()> {
        if self.diagnostics.len() >= self.limit("max_diagnostics") { return Err(CoreError::limit("Capture exceeds max_diagnostics")); }
        if message.len() > 8_192 { return Err(CoreError::limit("Capture diagnostic exceeds 8192 bytes")); }
        self.diagnostics.push(json!({"code":code,"message":message,"path":path}));
        Ok(())
    }

    fn uncertain_scope(&mut self, path: &str) -> Result<()> {
        self.declarations_partial = true;
        self.diagnostic("dynamic_scope", "A declaration inside a dynamic block or singleton receiver was not assigned a speculative owner", path)
    }

    fn coverage(&self) -> Value {
        json!([
            { "family":"source_inventory", "status":if self.inventory_partial {"partial"} else {"complete"},
              "scope":format!("Regular UTF-8 *.rb, *.rake, *.gemspec, *.rs, Gemfile and Rakefile; excludes {}; no symlinks",EXCLUDED.join(", ")),
              "reason":if self.inventory_partial {Some("Some source entries were unavailable; see diagnostics")} else {None} },
            { "family":"ruby_declarations", "status":if self.declarations_partial {"partial"} else {"complete"},
              "scope":"Explicit Ruby class, module and method syntax in captured valid source; names are lexical labels",
              "reason":if self.declarations_partial {Some("Some declarations or relationships were unavailable; see diagnostics")} else {None} },
            { "family":"dynamic_resolution", "status":"unavailable", "scope":"Ruby constant lookup, metaprogramming, visibility, dispatch and generated methods",
              "reason":"Static capture does not evaluate application code; relationship targets are unresolved" },
            { "family":"execution_trace", "status":"unavailable", "scope":"Observed execution", "reason":"A syntax relationship is not evidence that a call executed" },
            { "family":"rust_declarations", "status":"unavailable", "scope":"Rust symbols, types, macro expansion and call relationships",
              "reason":"Rust source files are available with exact digests and full source. This milestone does not include a Rust syntax or semantic analyzer" },
            { "family":"rails_routes", "status":"unavailable", "scope":"live application route set",
              "reason":"No application supplied. Static capture does not boot Rails" },
            { "family":"source_tree_coherence", "status":"unavailable", "scope":"One atomic source-tree revision",
              "reason":"Facts are derived from stored bytes. File reads detect ordinary concurrent writes, but capture does not certify a globally immutable tree or currentness after capture" }
        ])
    }
}

fn source_name(name: &str) -> bool {
    matches!(name, "Gemfile" | "Rakefile") || [".rb", ".rake", ".gemspec", ".rs"].iter().any(|suffix| name.ends_with(suffix))
}

fn text(bytes: &[u8]) -> String {
    // All captured input was validated as UTF-8; locations and identifiers are
    // parser-owned ranges. Rejecting invalid files precedes this conversion.
    String::from_utf8_lossy(bytes).into_owned()
}

fn constant_expression(node: &Node<'_>) -> String {
    // A nonrecursive constant-path walk also handles long :: chains safely.
    let mut suffixes = Vec::new();
    let mut current = if let Some(path) = node.as_constant_path_node() {
        suffixes.push(path.name().map(|name| text(name.as_slice())).unwrap_or_default());
        path.parent()
    } else { return text(node.location().as_slice()); };
    let mut prefix = String::new();
    while let Some(node) = current {
        if let Some(path) = node.as_constant_path_node() {
            suffixes.push(path.name().map(|name| text(name.as_slice())).unwrap_or_default());
            current = path.parent();
        } else {
            prefix = text(node.location().as_slice());
            break;
        }
    }
    for suffix in suffixes.into_iter().rev() { prefix.push_str("::"); prefix.push_str(&suffix); }
    prefix
}

fn declaration_name(raw: &str, namespace: Option<&str>) -> (String, &'static str) {
    if let Some(absolute) = raw.strip_prefix("::") { return (absolute.to_owned(), "absolute_lexical"); }
    if namespace.is_some() && raw.contains("::") { return (raw.to_owned(), "unresolved_relative_path"); }
    (namespace.map_or_else(|| raw.to_owned(), |namespace| format!("{namespace}::{raw}")), "lexical")
}

struct LineIndex(Vec<usize>);
impl LineIndex {
    fn new(bytes: &[u8]) -> Self {
        let mut starts = vec![0];
        starts.extend(bytes.iter().enumerate().filter_map(|(index, byte)| (*byte == b'\n').then_some(index + 1)));
        Self(starts)
    }
    fn line(&self, offset: usize) -> usize { self.0.partition_point(|start| *start <= offset) }
    fn file_end_line(&self, bytes: &[u8]) -> usize {
        // Source ranges are half-open. A final newline places the exclusive
        // endpoint at column zero of the following line, as for Prism locations.
        self.line(bytes.len())
    }
    fn location(&self, location: &Location<'_>) -> Value {
        json!({"start_line":self.line(location.start_offset()),"end_line":self.line(location.end_offset()),
               "start_byte":location.start_offset(),"end_byte":location.end_offset()})
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::os::unix::fs::symlink;

    // Functional tests can run in parallel without contending for the public
    // capture permit. Parser-stack probes exercise the actual public boundary
    // in bounded subprocesses, including calls from Ruby worker threads.
    fn capture(root: &Path, limits: &Value) -> Result<Value> { capture_inner(root, limits) }

    #[test]
    fn native_capture_declares_methods_and_does_not_execute_source() {
        let root = tempfile::tempdir().unwrap();
        let sentinel = root.path().join("executed");
        let source = format!("File.write({:?}, 'unsafe')\nmodule Orchard\n class Basket < Container\n include Tagged\n def count_items; items.length; end\n end\nend\n", sentinel.to_str().unwrap());
        std::fs::write(root.path().join("basket.rb"), &source).unwrap();
        let result = capture(root.path(), &json!({})).unwrap();
        assert!(!sentinel.exists());
        assert!(result["facts"].as_array().unwrap().iter().any(|fact| fact["name"] == "Orchard::Basket#count_items"));
        assert_eq!(result["files"][0]["content"], source);
        assert_eq!(result["producer"]["engine"], "rust");
        schema::capture(&result).unwrap();
    }

    #[test]
    fn directory_descriptor_survives_ancestor_replacement() {
        let root = tempfile::tempdir().unwrap();
        let outside = tempfile::tempdir().unwrap();
        std::fs::create_dir(root.path().join("sub")).unwrap();
        std::fs::write(root.path().join("sub/child.rb"), "class Intended; end").unwrap();
        std::fs::write(outside.path().join("child.rb"), "class SecretOutside; end").unwrap();
        let parent = open_root(&root.path().join("sub")).unwrap();
        std::fs::rename(root.path().join("sub"), root.path().join("retained")).unwrap();
        symlink(outside.path(), root.path().join("sub")).unwrap();
        let name = CString::new("child.rb").unwrap();
        let mut file = open_at(&parent, &name, false).unwrap();
        let mut bytes = String::new();
        file.read_to_string(&mut bytes).unwrap();
        assert_eq!(bytes, "class Intended; end");
    }

    #[test]
    fn syntax_failure_and_symlinks_report_incompleteness() {
        let root = tempfile::tempdir().unwrap();
        let outside = tempfile::tempdir().unwrap();
        std::fs::write(root.path().join("broken.rb"), "class Broken\n def missing(").unwrap();
        std::fs::write(outside.path().join("secret.rb"), "class SecretOutside; end").unwrap();
        symlink(outside.path().join("secret.rb"), root.path().join("secret.rb")).unwrap();
        let result = capture(root.path(), &json!({})).unwrap();
        assert_eq!(result["files"].as_array().unwrap().len(), 1);
        assert!(result["diagnostics"].as_array().unwrap().iter().any(|d| d["code"] == "syntax_error"));
        assert!(result["diagnostics"].as_array().unwrap().iter().any(|d| d["code"] == "symlink_skipped"));
        assert!(!result.to_string().contains("SecretOutside"));
    }

    #[test]
    fn native_limits_fail_closed() {
        let root = tempfile::tempdir().unwrap();
        std::fs::write(root.path().join("a.rb"), "class A; end").unwrap();
        assert_eq!(capture(root.path(), &json!({"max_file_bytes":1})).unwrap_err().code, "limit_exceeded");
        assert_eq!(capture(root.path(), &json!({"unknown":1})).unwrap_err().code, "invalid_input");
    }

    #[test]
    fn file_source_endpoints_follow_half_open_byte_ranges() {
        for source in ["", "class Demo; end", "class Demo; end\n", "# 確認\nclass Demo\nend\n"] {
            let root = tempfile::tempdir().unwrap();
            std::fs::write(root.path().join("demo.rb"), source).unwrap();
            let result = capture(root.path(), &json!({})).unwrap();
            schema::capture(&result).unwrap();
            let file = result["facts"].as_array().unwrap().iter().find(|fact| fact["kind"] == "file").unwrap();
            assert_eq!(file["location"]["end_byte"], source.len());
            assert_eq!(file["location"]["end_line"], source.bytes().filter(|byte| *byte == b'\n').count() + 1);
        }
    }

    #[test]
    fn singleton_and_method_receivers_do_not_invent_ordinary_owners() {
        let root = tempfile::tempdir().unwrap();
        let source = "class C\n def setup\n class << self\n def custom; end\n end\n def self.other; end\n end\n class << self\n def allowed; end\n include SingletonMixin\n class Nested; end\n def self.meta; end\n end\nend\n";
        std::fs::write(root.path().join("singleton.rb"), source).unwrap();
        let result = capture(root.path(), &json!({})).unwrap();
        let names: Vec<_> = result["facts"].as_array().unwrap().iter().map(|fact| fact["name"].as_str().unwrap()).collect();
        assert!(names.contains(&"C#setup"));
        assert!(names.contains(&"C.allowed"));
        for false_name in ["C.custom", "C.other", "C::Nested", "C.meta"] { assert!(!names.contains(&false_name), "{false_name}"); }
        assert!(!result["facts"].as_array().unwrap().iter().any(|fact| fact["links"].as_array().unwrap().iter().any(|link| link["relation"] == "includes" && link["target"] == "SingletonMixin")));
        assert!(result["coverage"].as_array().unwrap().iter().any(|coverage| coverage["family"] == "ruby_declarations" && coverage["status"] == "partial"));
    }
}
