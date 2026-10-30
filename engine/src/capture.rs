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
// The supported wrapper passes null options, which Prism maps to LATEST.
// An upstream change to that alias requires an explicit grammar policy review.
const _: () = assert!(ruby_prism_sys::PM_OPTIONS_VERSION_LATEST == ruby_prism_sys::PM_OPTIONS_VERSION_CRUBY_4_1);
const RUBY_SYNTAX_VERSION: &str = "4.1";
const PARSER_POLICY: &str = "prism-default-guarded";
const PARSER_STACK_BYTES: usize = 64 * 1024 * 1024;
const DECLARATION_SCOPE_MESSAGE: &str = "A declaration inside a dynamic block or singleton receiver was not assigned a speculative owner";
const MIXIN_SCOPE_MESSAGE: &str = "A mixin call in a block or singleton namespace has an unverified owner and was not attached to the ordinary class";
// Provisional operational traversal ceiling, not a parser or process-memory bound.
const MAX_NODES_CEILING: usize = 5_000_000;
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
    ("max_diagnostics", schema::MAX_DIAGNOSTIC_GROUPS),
];

#[derive(Clone)]
struct Scope {
    owner: String,
    namespace: Option<String>,
    singleton: bool,
    current: Option<usize>,
    dynamic: bool,
}

/// Owning fact, target, receiver kind, receiver name, safe navigation and the
/// distinct site for receivers that do not group.
type CallKey = (usize, String, &'static str, Option<String>, bool, Option<(usize, usize)>);

struct Capture {
    limits: HashMap<String, usize>,
    files: Vec<Value>,
    facts: Vec<Value>,
    /// Kind of each fact by index, so scope checks on every node do not
    /// search the fact object.
    kinds: Vec<FactKind>,
    diagnostics: Vec<Value>,
    diagnostic_bytes: usize,
    diagnostic_occurrences: u64,
    entries: usize,
    total_bytes: usize,
    nodes: usize,
    links: usize,
    evidence_bytes: usize,
    link_keys: HashSet<(usize, String, String)>,
    call_keys: HashMap<CallKey, usize>,
    inventory_partial: bool,
    declarations_partial: bool,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum FactKind { File, Class, Module, Method }

impl FactKind {
    fn label(self) -> &'static str {
        match self { Self::File => "file", Self::Class => "class", Self::Module => "module", Self::Method => "method" }
    }
}

struct CapturePermit;
impl Drop for CapturePermit {
    fn drop(&mut self) { CAPTURE_ACTIVE.store(false, Ordering::Release); }
}

pub fn capture(root: &Path, limits: &Value) -> Result<Value> {
    let effective = effective_limits(limits)?;
    if CAPTURE_ACTIVE.compare_exchange(false, true, Ordering::AcqRel, Ordering::Acquire).is_err() {
        return Err(CoreError::new("busy", "A native capture is already active; retry after it completes"));
    }
    let _permit = CapturePermit;
    let root = root.to_path_buf();
    // Prism's C parser and AST destructor recurse. Ruby worker stacks are much
    // smaller than its depth guard assumes. Keep parsing and destruction on one
    // explicitly sized native stack, and bound concurrency to one capture.
    // This is not a sandbox or a CPU deadline; controller workers remain needed
    // for hostile-input qualification and enforced process resource limits.
    std::thread::Builder::new()
        .name("thistle-capture".to_owned())
        .stack_size(PARSER_STACK_BYTES)
        .spawn(move || capture_inner(&root, effective))?
        .join()
        .map_err(|_| CoreError::new("internal_error", "Native capture worker panicked; no result was published"))?
}

fn effective_limits(limits: &Value) -> Result<HashMap<String, usize>> {
    let mut effective: HashMap<String, usize> = DEFAULT_LIMITS
        .iter()
        .map(|(key, value)| ((*key).to_owned(), *value))
        .collect();
    if !limits.is_null() {
        let values = limits.as_object().ok_or_else(|| CoreError::input("Capture limits must be an object"))?;
        for (key, value) in values {
            let default = effective.get(key).ok_or_else(|| CoreError::input(format!("Unknown capture limit: {key}")))?;
            let ceiling = if key == "max_nodes" { MAX_NODES_CEILING } else { *default };
            let supplied = value.as_u64().ok_or_else(|| CoreError::input(format!("Capture limit {key} must be a positive integer")))?;
            let supplied = usize::try_from(supplied).map_err(|_| CoreError::input(format!("Capture limit {key} is too large")))?;
            if supplied == 0 || supplied > ceiling {
                return Err(CoreError::input(format!("Capture limit {key} must be between 1 and {ceiling}")));
            }
            effective.insert(key.to_owned(), supplied);
        }
    }
    Ok(effective)
}

fn capture_inner(root: &Path, effective: HashMap<String, usize>) -> Result<Value> {
    let canonical = std::fs::canonicalize(root)?;
    let canonical_text = canonical.to_str().ok_or_else(|| CoreError::input("Capture root must be valid UTF-8"))?;
    let directory = open_root(&canonical)?;
    let mut capture = Capture {
        limits: effective,
        files: Vec::new(), facts: Vec::new(), kinds: Vec::new(), diagnostics: Vec::new(), diagnostic_bytes: 2, diagnostic_occurrences: 0,
        entries: 0, total_bytes: 0, nodes: 0, links: 0, evidence_bytes: 2,
        link_keys: HashSet::new(), call_keys: HashMap::new(), inventory_partial: false, declarations_partial: false,
    };
    capture.walk(&directory, "", 0)?;
    // Sort keys are read once per element. Comparing through string-keyed
    // lookups on every comparison dominated the walk for large inventories.
    let order = sort_order(&capture.files, |file| file["path"].as_str());
    apply_order(&mut capture.files, order);
    let order = sort_order(&capture.facts, |fact| {
        (fact["path"].as_str(), fact["location"]["start_byte"].as_u64(), fact["kind"].as_str(), fact["name"].as_str(), fact["id"].as_str())
    });
    apply_order(&mut capture.facts, order);
    for fact in &mut capture.facts {
        if let Some(links) = fact["links"].as_array_mut() {
            if links.len() < 2 { continue; }
            let order = sort_order(links, call_sort_key);
            apply_order(links, order);
        }
    }
    let coverage = capture.coverage();
    let producer = json!({ "name": "thistle", "engine": "rust", "core_version": env!("CARGO_PKG_VERSION"), "capture_schema": 1,
        "call_target_schema":2, "link_encoding_schema":1, "prism_version": PRISM_VERSION, "ruby_syntax_version": RUBY_SYNTAX_VERSION, "parser_policy": PARSER_POLICY, "parser_stack_bytes":PARSER_STACK_BYTES, "capture_concurrency":1,
        "effective_limits": capture.limits, "visited_nodes": capture.nodes });
    // Move the retained inventory into the response. `json!` would serialize
    // every file body and fact tree into a second copy before dropping the first.
    let mut output = serde_json::Map::new();
    output.insert("schema_version".to_owned(), json!(schema::VERSION));
    output.insert("root_id".to_owned(), Value::String(schema::digest(canonical_text.as_bytes())));
    output.insert("files".to_owned(), Value::Array(capture.files));
    output.insert("facts".to_owned(), Value::Array(capture.facts));
    output.insert("coverage".to_owned(), coverage);
    output.insert("diagnostics".to_owned(), Value::Array(capture.diagnostics));
    output.insert("evidence_accounting".to_owned(), json!({"schema_version":schema::VERSION,"fact_bytes_upper_bound":capture.evidence_bytes}));
    output.insert("producer".to_owned(), producer);
    Ok(Value::Object(output))
}

/// Stable order by a key computed once per element. Keys may borrow the
/// values; `apply_order` moves them after those borrows end.
fn sort_order<'a, K: Ord>(values: &'a [Value], key: impl Fn(&'a Value) -> K) -> Vec<usize> {
    let keys: Vec<K> = values.iter().map(key).collect();
    let mut order: Vec<usize> = (0..values.len()).collect();
    order.sort_by(|a, b| keys[*a].cmp(&keys[*b]));
    order
}

fn apply_order(values: &mut Vec<Value>, order: Vec<usize>) {
    if order.iter().enumerate().all(|(position, index)| position == *index) { return; }
    let mut slots: Vec<Option<Value>> = std::mem::take(values).into_iter().map(Some).collect();
    values.extend(order.into_iter().map(|index| slots[index].take().expect("each index moves once")));
}

fn call_sort_key(link: &Value) -> (Option<&str>, Option<&str>, Option<&str>, Option<&str>, Option<bool>, Option<u64>, Option<u64>) {
    let call = schema::call_metadata(&link["attributes"]["thistle_call"], schema::VERSION).expect("captured call metadata");
    (link["relation"].as_str(), link["target"].as_str(), call.as_ref().map(|c| c.kind),
        call.as_ref().and_then(|c| c.name), call.as_ref().map(|c| c.safe_navigation),
        call.as_ref().map(|c| c.location.start_byte), call.as_ref().map(|c| c.location.end_byte))
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
            // next readdir. Reset thread-local errno to distinguish EOF from error.
            errno::set_errno(errno::Errno(0));
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
        let text = match String::from_utf8(content) {
            Ok(text) => text,
            Err(_) => {
                self.inventory_partial = true; self.declarations_partial = true;
                return self.diagnostic("unsupported_encoding", "Only source whose exact bytes are valid UTF-8 is captured", path);
            }
        };
        let content = text.as_bytes();
        let digest = schema::digest(content);
        if path.ends_with(".rs") {
            let lines = LineIndex::new(content);
            self.add_fact(FactKind::File, path, path, json!({
                "start_line":1, "end_line":lines.file_end_line(content), "start_byte":0, "end_byte":content.len()
            }), json!({"sha256":digest,"bytes":content.len(),"language":"rust","parse_status":"not_parsed"}))?;
            self.files.push(file_record(path, digest, text));
            return Ok(());
        }
        let parsed = ruby_prism::parse(content);
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
        let lines = LineIndex::new(content);
        let errors: Vec<_> = parsed.errors().take(self.limit("max_diagnostics") + 1).collect();
        if errors.len() > self.limit("max_diagnostics") { return Err(CoreError::limit("Capture exceeds max_diagnostics")); }
        let file_position = json!({"start_line":1, "end_line":lines.file_end_line(content), "start_byte":0, "end_byte":content.len()});
        self.add_fact(FactKind::File, path, path, file_position, json!({
            "sha256":digest, "bytes":content.len(), "language":"ruby", "parse_status":if errors.is_empty() { "valid" } else { "invalid" }
        }))?;
        let extracted = if errors.is_empty() {
            self.extract(parsed.node(), path, &lines)
        } else {
            self.declarations_partial = true;
            errors.iter().try_for_each(|error| {
                let message = format!("Line {}: {}", lines.line(error.location().start_offset()), error.message());
                self.admit_diagnostic(json!({"code":"syntax_error", "message":message, "path":path,
                    "prism_version":PRISM_VERSION, "ruby_syntax_version":RUBY_SYNTAX_VERSION,
                    "parser_policy":PARSER_POLICY}))
            })
        };
        // The parse result borrows the source; release it before moving the
        // validated text into the inventory without another copy.
        drop(errors);
        drop(parsed);
        extracted?;
        self.files.push(file_record(path, digest, text));
        Ok(())
    }

    fn extract<'pr>(&mut self, root: Node<'pr>, path: &str, lines: &LineIndex) -> Result<()> {
        let initial = Rc::new(Scope { owner:"Object".to_owned(), namespace:None, singleton:false, current:None, dynamic:false });
        // Preserve the historical LIFO encounter order: diagnostic groups and
        // admission/refusal boundaries depend on more than the final fact sort.
        let mut pending = vec![(root, initial)];
        while let Some((node, scope)) = pending.pop() {
            self.nodes += 1;
            if self.nodes > self.limit("max_nodes") { return Err(CoreError::limit("Parsed sources exceed max_nodes")); }
            if let Some(class) = node.as_class_node() {
                if scope.dynamic || scope.singleton { self.uncertain_scope(path)?; continue; }
                let raw = constant_expression(&class.constant_path());
                let (name, resolution) = declaration_name(&raw, scope.namespace.as_deref());
                let index = self.add_fact(FactKind::Class, &name, path, lines.location(&class.location()), json!({
                    "declaration_name":raw, "lexical_scope":scope.namespace.iter().collect::<Vec<_>>(), "name_resolution":resolution
                }))?;
                if let Some(parent) = class.superclass() { self.add_link(index, "inherits", parent.location().as_slice(), path)?; }
                let next = Rc::new(Scope { owner:name.clone(), namespace:Some(name), singleton:false, current:Some(index), dynamic:false });
                if let Some(body) = class.body() { pending.push((body, next)); }
            } else if let Some(module) = node.as_module_node() {
                if scope.dynamic || scope.singleton { self.uncertain_scope(path)?; continue; }
                let raw = constant_expression(&module.constant_path());
                let (name, resolution) = declaration_name(&raw, scope.namespace.as_deref());
                let index = self.add_fact(FactKind::Module, &name, path, lines.location(&module.location()), json!({
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
                let index = self.add_fact(FactKind::Method, &name, path, lines.location(&method.location()), json!({
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
                if let Some(call) = node.as_call_node() { self.collect_call(&call, &scope, path, lines)?; }
                children::for_each_child(&node, |child| pending.push((child, Rc::clone(&scope))));
            }
        }
        Ok(())
    }

    fn collect_call(&mut self, call: &ruby_prism::CallNode<'_>, scope: &Scope, path: &str, lines: &LineIndex) -> Result<()> {
        let Some(current) = scope.current else { return Ok(()); };
        let method_name = call.name();
        if method_name.as_slice().len() > 4096 { return Err(CoreError::limit("Call method exceeds 4096 bytes")); }
        let name = text(method_name.as_slice());
        let receiver_is_self = call.receiver().map_or(true, |receiver| receiver.as_self_node().is_some());
        let namespace = matches!(self.kinds[current], FactKind::Class | FactKind::Module);
        if (scope.dynamic || scope.singleton) && receiver_is_self && namespace && matches!(name.as_str(), "include" | "extend" | "prepend") {
            self.declarations_partial = true;
            return self.diagnostic("dynamic_scope", MIXIN_SCOPE_MESSAGE, path);
        }
        if receiver_is_self && namespace && matches!(name.as_str(), "include" | "extend" | "prepend") {
            let relation = match name.as_str() { "include" => "includes", "extend" => "extends", _ => "prepends" };
            if let Some(arguments) = call.arguments() {
                for argument in &arguments.arguments() { self.add_link(current, relation, argument.location().as_slice(), path)?; }
            }
        } else {
            let raw_name = call.name();
            let raw_name = raw_name.as_slice();
            if raw_name.len() > 4096 { return Err(CoreError::limit("Call method exceeds 4096 bytes")); }
            let target = text(raw_name);
            let receiver = call.receiver();
            let (kind, name, omitted) = receiver.as_ref().map_or(("implicit", None, false), classify_receiver);
            let location = call.location();
            let start = location.start_offset();
            let end = location.end_offset();
            let simple = matches!(kind, "implicit" | "self") || (matches!(kind, "constant" | "local" | "instance_variable") && name.is_some());
            let site = (!simple).then_some((start, end));
            let key = (current, target, kind, name, call.is_safe_navigation(), site);
            // Build the link only on admission or when an earlier saved site
            // replaces the current representative of this group.
            let link = |key: &CallKey| {
                let receiver_location = receiver.as_ref().map(|node| lines.call_location(&node.location()));
                let metadata = json!({"version":2, "data":(kind, &key.3, omitted,
                    call.is_safe_navigation(), lines.call_location(&location), receiver_location)});
                let mut attributes = serde_json::Map::new();
                attributes.insert("thistle_call".to_owned(), metadata);
                let mut link = serde_json::Map::new();
                link.insert("relation".to_owned(), Value::String("calls".to_owned()));
                link.insert("target".to_owned(), Value::String(key.1.clone()));
                link.insert("resolution".to_owned(), Value::String("unresolved".to_owned()));
                link.insert("attributes".to_owned(), Value::Object(attributes));
                Value::Object(link)
            };
            if let Some(&index) = self.call_keys.get(&key) {
                let old = &self.facts[current]["links"][index];
                if schema::call_metadata(&old["attributes"]["thistle_call"], schema::VERSION)?.expect("captured call").location.start_byte > start as u64 {
                    self.replace_link(current, index, link(&key))?;
                }
            } else {
                let links = self.links.checked_add(1).filter(|n| *n <= self.limit("max_links"))
                    .ok_or_else(|| CoreError::limit("Capture exceeds max_links"))?;
                let link = link(&key);
                self.charge_link(&link)?;
                self.links = links;
                let links = self.facts[current]["links"].as_array_mut().expect("fact links array");
                let index = links.len();
                links.push(link);
                self.call_keys.insert(key, index);
            }
        }
        Ok(())
    }

    fn add_fact(&mut self, kind: FactKind, name: &str, path: &str, position: Value, attributes: Value) -> Result<usize> {
        let label = kind.label();
        if self.facts.len() >= self.limit("max_facts") { return Err(CoreError::limit("Capture exceeds max_facts")); }
        if name.is_empty() || name.len() > 4_096 { return Err(CoreError::limit("Declaration name is empty or exceeds 4096 bytes")); }
        // The same compact JSON array as before, serialized without an
        // intermediate tree; fact identities are stable.
        let identity = serde_json::to_vec(&("ruby", label, name, path, &position["start_byte"]))?;
        let index = self.facts.len();
        let mut fact = serde_json::Map::new();
        fact.insert("id".to_owned(), Value::String(schema::digest(&identity)));
        fact.insert("kind".to_owned(), Value::String(label.to_owned()));
        fact.insert("name".to_owned(), Value::String(name.to_owned()));
        fact.insert("path".to_owned(), Value::String(path.to_owned()));
        fact.insert("location".to_owned(), position);
        fact.insert("evidence".to_owned(), Value::String("static".to_owned()));
        fact.insert("attributes".to_owned(), attributes);
        fact.insert("links".to_owned(), Value::Array(Vec::new()));
        let fact = Value::Object(fact);
        self.charge_evidence(schema::encoded_bytes(&crate::link_encoding::WireFact::new(&fact, schema::VERSION)?, schema::MAX_FACTS_BYTES)?
            .checked_add(1).ok_or_else(|| CoreError::limit("Capture evidence size overflow"))?)?;
        self.facts.push(fact);
        self.kinds.push(kind);
        Ok(index)
    }

    fn in_method(&self, scope: &Scope) -> bool {
        scope.current.is_some_and(|index| self.kinds[index] == FactKind::Method)
    }

    fn add_link(&mut self, current: usize, relation: &str, target: &[u8], path: &str) -> Result<()> {
        if target.len() > 1_024 {
            self.declarations_partial = true;
            return self.diagnostic("link_expression_too_large", "A relationship expression exceeded 1024 bytes and is unavailable", path);
        }
        let target = text(target);
        let key = (current, relation.to_owned(), target.clone());
        if self.link_keys.contains(&key) { return Ok(()); }
        let links = self.links.checked_add(1).filter(|n| *n <= self.limit("max_links"))
            .ok_or_else(|| CoreError::limit("Capture exceeds max_links"))?;
        let link = json!({"relation":relation,"target":target,"resolution":"unresolved"});
        self.charge_link(&link)?;
        self.links = links;
        self.link_keys.insert(key);
        self.facts[current]["links"].as_array_mut().expect("fact links array").push(link);
        Ok(())
    }

    // Group/representative selection belongs to collect_call. This only adjusts
    // the shared projected charge, refusing before either bytes or link mutate.
    fn replace_link(&mut self, current: usize, index: usize, link: Value) -> Result<()> {
        let old = &self.facts[current]["links"][index];
        let old_len = schema::encoded_bytes(&crate::link_encoding::WireLink::new(old, schema::VERSION, "static")?, schema::MAX_FACTS_BYTES)?;
        let new_len = schema::encoded_bytes(&crate::link_encoding::WireLink::new(&link, schema::VERSION, "static")?, schema::MAX_FACTS_BYTES)?;
        if new_len > old_len { self.charge_evidence(new_len - old_len)?; }
        else { self.evidence_bytes = self.evidence_bytes.checked_sub(old_len - new_len)
            .ok_or_else(|| CoreError::limit("Capture evidence refund underflow"))?; }
        self.facts[current]["links"][index] = link;
        Ok(())
    }

    fn charge_link(&mut self, link: &Value) -> Result<()> {
        let bytes = schema::encoded_bytes(&crate::link_encoding::WireLink::new(link, schema::VERSION, "static")?, schema::MAX_FACTS_BYTES)?;
        self.charge_evidence(bytes.checked_add(1).ok_or_else(|| CoreError::limit("Capture evidence size overflow"))?)
    }

    fn charge_evidence(&mut self, bytes: usize) -> Result<()> {
        let next = self.evidence_bytes.checked_add(bytes)
            .ok_or_else(|| CoreError::limit("Capture evidence size overflow"))?;
        if next > schema::MAX_FACTS_BYTES {
            return Err(CoreError::limit("Capture fact evidence exceeds the 64 MiB payload budget"));
        }
        self.evidence_bytes = next;
        Ok(())
    }

    fn diagnostic(&mut self, code: &str, message: &str, path: &str) -> Result<()> {
        self.admit_diagnostic(json!({"code":code,"message":message,"path":path}))
    }

    fn admit_diagnostic(&mut self, mut record: Value) -> Result<()> {
        if schema::string(&record, "message")?.len() > 8_192 {
            return Err(CoreError::limit("Capture diagnostic exceeds 8192 bytes"));
        }
        let count = schema::diagnostic_occurrences(&record)?;
        let total = self.diagnostic_occurrences.checked_add(count)
            .ok_or_else(|| CoreError::limit("Diagnostic occurrence count overflow"))?;
        record["occurrences"] = json!(count);
        // Only these two known recoverable classes coalesce. Compare ALL fields
        // except the count, preserving future reason/location/provenance fields.
        // A bounded scan avoids a second retained key/map and its memory budget.
        let grouped = record["code"] == "dynamic_scope" && matches!(record["message"].as_str(),
            Some(DECLARATION_SCOPE_MESSAGE) | Some(MIXIN_SCOPE_MESSAGE));
        let existing = if grouped {
            self.diagnostics.iter().position(|prior| {
                let (Some(a), Some(b)) = (prior.as_object(), record.as_object()) else { return false; };
                a.len() == b.len() && a.iter().all(|(key, value)| key == "occurrences" || b.get(key) == Some(value))
            })
        } else { None };
        let bytes = if let Some(index) = existing {
            let prior = &self.diagnostics[index];
            let count = schema::diagnostic_occurrences(prior)?.checked_add(count)
                .ok_or_else(|| CoreError::limit("Diagnostic occurrence count overflow"))?;
            record["occurrences"] = json!(count);
            let old_bytes = schema::diagnostic_bytes(prior)?;
            let new_bytes = schema::diagnostic_bytes(&record)?;
            self.diagnostic_bytes.checked_sub(old_bytes).and_then(|n| n.checked_add(new_bytes))
        } else {
            if self.diagnostics.len() >= self.limit("max_diagnostics") {
                return Err(CoreError::limit("Capture exceeds max_diagnostics retained groups"));
            }
            let encoded = schema::diagnostic_bytes(&record)?;
            self.diagnostic_bytes.checked_add(encoded)
                .and_then(|n| n.checked_add(usize::from(!self.diagnostics.is_empty())))
        }.ok_or_else(|| CoreError::limit("Diagnostic byte accounting overflow"))?;
        schema::diagnostic_budget(bytes)?;
        // Admission completes before any retained state changes.
        if let Some(index) = existing { self.diagnostics[index] = record; }
        else { self.diagnostics.push(record); }
        self.diagnostic_bytes = bytes;
        self.diagnostic_occurrences = total;
        Ok(())
    }

    fn uncertain_scope(&mut self, path: &str) -> Result<()> {
        self.declarations_partial = true;
        self.diagnostic("dynamic_scope", DECLARATION_SCOPE_MESSAGE, path)
    }

    fn coverage(&self) -> Value {
        json!([
            { "family":"source_inventory", "status":if self.inventory_partial {"partial"} else {"complete"},
              "scope":format!("Regular UTF-8 *.rb, *.rake, *.gemspec, *.rs, Gemfile and Rakefile; excludes {}; no symlinks",EXCLUDED.join(", ")),
              "reason":if self.inventory_partial {Some("Some source entries were unavailable; see diagnostics")} else {None} },
            { "family":"ruby_declarations", "status":if self.declarations_partial {"partial"} else {"complete"},
              "scope":"Explicit Ruby class, module and method syntax in captured valid source; names are lexical labels",
              "prism_version":PRISM_VERSION, "ruby_syntax_version":RUBY_SYNTAX_VERSION, "parser_policy":PARSER_POLICY,
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

fn file_record(path: &str, digest: String, content: String) -> Value {
    let mut record = serde_json::Map::new();
    record.insert("path".to_owned(), Value::String(path.to_owned()));
    record.insert("sha256".to_owned(), Value::String(digest));
    record.insert("bytes".to_owned(), json!(content.len()));
    record.insert("encoding".to_owned(), Value::String("UTF-8".to_owned()));
    record.insert("content".to_owned(), Value::String(content));
    Value::Object(record)
}

fn source_name(name: &str) -> bool {
    matches!(name, "Gemfile" | "Rakefile") || [".rb", ".rake", ".gemspec", ".rs"].iter().any(|suffix| name.ends_with(suffix))
}

fn text(bytes: &[u8]) -> String {
    // All captured input was validated as UTF-8; locations and identifiers are
    // parser-owned ranges. Rejecting invalid files precedes this conversion.
    String::from_utf8_lossy(bytes).into_owned()
}

// Only lexical syntax is named. No parser node or receiver source escapes capture.
fn bounded_name(kind: &'static str, bytes: &[u8]) -> (&'static str, Option<String>, bool) {
    if bytes.len() <= 256 { (kind, Some(text(bytes)), false) } else { (kind, None, true) }
}

fn classify_receiver(node: &Node<'_>) -> (&'static str, Option<String>, bool) {
    if node.as_self_node().is_some() { return ("self", None, false); }
    if let Some(n) = node.as_local_variable_read_node() { return bounded_name("local", n.name().as_slice()); }
    if let Some(n) = node.as_instance_variable_read_node() { return bounded_name("instance_variable", n.name().as_slice()); }
    if let Some(n) = node.as_constant_read_node() { return bounded_name("constant", n.name().as_slice()); }
    if node.as_constant_path_node().is_some() {
        let mut cursor = Some(node.as_constant_path_node().unwrap().as_node());
        let mut parts = Vec::new();
        let mut size = 0usize;
        let mut absolute = false;
        let mut oversized = false;
        while let Some(current) = cursor {
            if parts.len() >= 128 { return ("expression", None, false); }
            if let Some(path) = current.as_constant_path_node() {
                let Some(name) = path.name() else { return ("expression", None, false); };
                let bytes = name.as_slice();
                size += bytes.len() + 2;
                oversized |= size > 256;
                parts.push(if oversized { String::new() } else { text(bytes) });
                cursor = path.parent();
                if cursor.is_none() { absolute = true; }
            } else if let Some(read) = current.as_constant_read_node() {
                let name = read.name(); let bytes = name.as_slice(); size += bytes.len();
                oversized |= size > 256;
                parts.push(if oversized { String::new() } else { text(bytes) }); cursor = None;
            } else { return ("expression", None, false); }
        }
        if oversized { return ("constant", None, true); }
        parts.reverse();
        let name = format!("{}{}", if absolute { "::" } else { "" }, parts.join("::"));
        return if name.len() <= 256 { ("constant", Some(name), false) } else { ("constant", None, true) };
    }
    if node.as_call_node().is_some() { return ("call", None, false); }
    if node.as_array_node().is_some() || node.as_hash_node().is_some() || node.as_string_node().is_some() ||
       node.as_symbol_node().is_some() || node.as_integer_node().is_some() || node.as_float_node().is_some() ||
       node.as_regular_expression_node().is_some() || node.as_true_node().is_some() || node.as_false_node().is_some() || node.as_nil_node().is_some() {
        return ("literal", None, false);
    }
    ("expression", None, false)
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
    fn call_location(&self, location: &Location<'_>) -> (usize, usize, usize, usize) {
        (location.start_offset(), location.end_offset(), self.line(location.start_offset()), self.line(location.end_offset()))
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
    fn capture(root: &Path, limits: &Value) -> Result<Value> { capture_inner(root, effective_limits(limits)?) }

    fn empty_capture() -> Capture {
        Capture {
            limits: effective_limits(&json!({})).unwrap(),
            files: vec![], facts: vec![], kinds: vec![], diagnostics: vec![], diagnostic_bytes: 2, diagnostic_occurrences: 0,
            entries: 0, total_bytes: 0, nodes: 0, links: 0, evidence_bytes: 2,
            link_keys: HashSet::new(), call_keys: HashMap::new(), inventory_partial: false, declarations_partial: false,
        }
    }

    #[test]
    fn compact_is_charged_before_admission_and_earliest_grouped_site_replaces() {
        let source = b"self.call; self.call";
        let parsed = ruby_prism::parse(source);
        let program = parsed.node();
        let statements = program.as_program_node().unwrap().statements();
        let calls: Vec<_> = statements.body().iter().collect();
        let first = calls[0].as_call_node().unwrap();
        let last = calls[1].as_call_node().unwrap();
        let mut capture = empty_capture();
        capture.add_fact(FactKind::Method, "run", "a.rb", Value::Null, json!({})).unwrap();
        let scope = Scope { owner: "run".into(), namespace: None, singleton: false, current: Some(0), dynamic: false };
        let lines = LineIndex::new(source);
        capture.collect_call(&last, &scope, "a.rb", &lines).unwrap();
        let later_bytes = schema::encoded_bytes(&crate::link_encoding::WireLink::new(&capture.facts[0]["links"][0], schema::VERSION, "static").unwrap(), schema::MAX_FACTS_BYTES).unwrap();
        capture.facts[0]["links"] = json!([]); capture.call_keys.clear(); capture.links = 0;
        capture.evidence_bytes = schema::MAX_FACTS_BYTES - later_bytes - 1;
        capture.collect_call(&last, &scope, "a.rb", &lines).unwrap();
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES);
        capture.collect_call(&first, &scope, "a.rb", &lines).unwrap();
        let earliest = &capture.facts[0]["links"][0];
        assert_eq!(schema::call_metadata(&earliest["attributes"]["thistle_call"], 2).unwrap().unwrap().location.start_byte, 0);
        assert_eq!(capture.links, 1);
        let early_bytes = schema::encoded_bytes(&crate::link_encoding::WireLink::new(earliest, schema::VERSION, "static").unwrap(), schema::MAX_FACTS_BYTES).unwrap();
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES - later_bytes + early_bytes);
        capture.collect_call(&last, &scope, "a.rb", &lines).unwrap();
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES - later_bytes + early_bytes);
        assert!(capture.charge_evidence(later_bytes - early_bytes + 1).is_err());
    }

    #[test]
    fn projected_replacement_and_append_refuse_before_mutating_capture_state() {
        let mut capture = empty_capture();
        capture.add_fact(FactKind::Method, "run", "a.rb", Value::Null, json!({})).unwrap();
        let old = json!({"relation":"calls","target":"héllo\"\\","resolution":"unresolved",
            "attributes":{"thistle_call":{"version":2,"data":["implicit",null,false,false,[0,5,1,1],null]}}});
        let mut bigger = old.clone();
        bigger["attributes"]["thistle_call"]["data"][4] = json!([0,99999,1,999]);
        let size = |value: &Value| schema::encoded_bytes(
            &crate::link_encoding::WireLink::new(value, schema::VERSION, "static").unwrap(), schema::MAX_FACTS_BYTES).unwrap();
        let delta = size(&bigger) - size(&old);
        assert!(delta > 0);
        capture.facts[0]["links"] = json!([old]); capture.links = 1;
        capture.evidence_bytes = schema::MAX_FACTS_BYTES;
        assert!(capture.replace_link(0, 0, bigger.clone()).is_err());
        assert_eq!(capture.facts[0]["links"][0], old);
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES);
        capture.evidence_bytes -= delta;
        capture.replace_link(0, 0, bigger.clone()).unwrap();
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES);
        capture.replace_link(0, 0, old).unwrap();
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES - delta);

        capture.facts[0]["links"] = json!([]); capture.links = 0;
        let link = json!({"relation":"inherits","target":"X","resolution":"unresolved"});
        capture.evidence_bytes = schema::MAX_FACTS_BYTES - size(&link);
        let before = capture.evidence_bytes;
        assert!(capture.add_link(0, "inherits", b"X", "a.rb").is_err());
        assert_eq!(capture.evidence_bytes, before);
        assert_eq!(capture.links, 0);
        assert!(capture.link_keys.is_empty());
        assert!(capture.facts[0]["links"].as_array().unwrap().is_empty());
        capture.evidence_bytes -= 1;
        capture.add_link(0, "inherits", b"X", "a.rb").unwrap();
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES);
        assert!(capture.charge_evidence(usize::MAX).is_err());
        assert_eq!(capture.evidence_bytes, schema::MAX_FACTS_BYTES);
    }

    #[test]
    fn native_hint_is_conservative_for_the_same_single_published_projection() {
        let temp = tempfile::tempdir().unwrap();
        std::fs::write(temp.path().join("calls.rb"), "class Box; def run(x); x&.call; self.call; end; end\n").unwrap();
        let data = capture(temp.path(), &json!({})).unwrap();
        assert_eq!(data["schema_version"], 3);
        assert_eq!(data["producer"]["call_target_schema"], 2);
        assert_eq!(data["producer"]["link_encoding_schema"], 1);
        let facts = data["facts"].as_array().unwrap();
        let refs: Vec<_> = facts.iter().collect();
        let bytes = serde_json::to_vec(&crate::link_encoding::WireFacts::new(&refs, 3)).unwrap();
        let nonempty_links = facts.iter().filter(|fact| !fact["links"].as_array().unwrap().is_empty()).count();
        assert_eq!(data["evidence_accounting"]["fact_bytes_upper_bound"], bytes.len() + 1 + nonempty_links);
        assert!(facts.iter().all(|fact| fact["links"].as_array().unwrap().iter().all(Value::is_object)));
        let path = temp.path().join("store");
        let manifest = crate::store::publish(&path, &data).unwrap();
        let saved = std::fs::read(path.join("generations").join(manifest["generation"].as_str().unwrap()).join("facts.json")).unwrap();
        assert_eq!(saved.len(), bytes.len());
        let reader = crate::store::Reader::open(&path, None).unwrap();
        for fact in facts { assert_eq!(reader.fact(fact["id"].as_str().unwrap()).unwrap(), *fact); }
        reader.check().unwrap();
    }

    #[test]
    fn fact_identity_is_the_digest_of_the_compact_identity_array() {
        let root = tempfile::tempdir().unwrap();
        std::fs::write(root.path().join("demo.rb"), "module Demo
  def self.run; end
end
").unwrap();
        let result = capture(root.path(), &json!({})).unwrap();
        let facts = result["facts"].as_array().unwrap();
        for (kind, name, start) in [("file", "demo.rb", 0), ("module", "Demo", 0), ("method", "Demo.run", 14)] {
            let fact = facts.iter().find(|fact| fact["kind"] == kind && fact["name"] == name).unwrap();
            assert_eq!(fact["location"]["start_byte"], start);
            let identity = format!(r#"["ruby","{kind}","{name}","demo.rb",{start}]"#);
            assert_eq!(fact["id"], schema::digest(identity.as_bytes()));
        }
    }

    #[test]
    fn names_and_method_size_limits_are_explicit() {
        assert_eq!(bounded_name("local", &vec![b'x'; 256]).1.unwrap().len(), 256);
        assert_eq!(bounded_name("local", &vec![b'x'; 257]), ("local", None, true));
        let root = tempfile::tempdir().unwrap();
        let path = root.path().join("limits.rb");
        std::fs::write(&path, format!("class Limits; def run; self.{}; end; end\n", "a".repeat(4096))).unwrap();
        let result = capture(root.path(), &json!({})).unwrap();
        let fact = result["facts"].as_array().unwrap().iter().find(|f| f["name"] == "Limits#run").unwrap();
        assert_eq!(fact["links"][0]["target"].as_str().unwrap().len(), 4096);
        std::fs::write(path, format!("class Limits; def run; self.{}; end; end\n", "a".repeat(4097))).unwrap();
        assert_eq!(capture(root.path(), &json!({})).unwrap_err().code, "limit_exceeded");
    }

    #[test]
    fn structured_calls_keep_long_receivers_and_distinct_sites() {
        let root = tempfile::tempdir().unwrap();
        let long = "x".repeat(8192);
        let source = format!("class Box\n def inspect_calls(x)\n  plain; self.plain; Box.call; x.call; @x.call; x&.call; x.call\n  [1].same; [2].same; /a  b/.match; \"{}\".size\n end\nend\n", long);
        std::fs::write(root.path().join("fixture.rb"), &source).unwrap();
        let result = capture(root.path(), &json!({})).unwrap();
        schema::capture(&result).unwrap();
        let fact = result["facts"].as_array().unwrap().iter().find(|f| f["name"] == "Box#inspect_calls").unwrap();
        let calls = fact["links"].as_array().unwrap();
        fn metadata(link: &Value) -> schema::CallMetadata<'_> { schema::call_metadata(&link["attributes"]["thistle_call"], schema::VERSION).unwrap().unwrap() }
        let selected = |target: &str, kind: &str| calls.iter().filter(|link| link["target"] == target && metadata(link).kind == kind).collect::<Vec<_>>();
        assert_eq!(selected("plain", "implicit").len(), 1);
        assert_eq!(selected("plain", "self").len(), 1);
        assert_eq!(metadata(selected("call", "constant")[0]).name, Some("Box"));
        let locals = selected("call", "local");
        assert_eq!(locals.len(), 2);
        assert_eq!(locals.iter().filter(|v| metadata(v).safe_navigation).count(), 1);
        assert_eq!(selected("same", "literal").len(), 2);
        let long_call = selected("size", "literal")[0];
        let loc = metadata(long_call).receiver_location.unwrap();
        assert_eq!(&source[loc.start_byte as usize..loc.end_byte as usize], format!("\"{}\"", long));
        assert_eq!(result["files"][0]["content"], source);
        assert!(result["diagnostics"].as_array().unwrap().iter().all(|d| d["code"] != "link_expression_too_large"));
    }

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
    fn guarded_grammar_reports_version_sensitive_source_and_errors() {
        let root = tempfile::tempdir().unwrap();
        std::fs::write(root.path().join("modern.rb"), "class Example\n private def greet = puts 'Hello'\nend\n").unwrap();
        std::fs::write(root.path().join("broken.rb"), "class Broken\n def missing(").unwrap();
        let result = capture(root.path(), &json!({})).unwrap();
        assert!(result["facts"].as_array().unwrap().iter().any(|f| f["name"] == "Example#greet"));
        let coverage = result["coverage"].as_array().unwrap().iter().find(|c| c["family"] == "ruby_declarations").unwrap();
        let diagnostic = result["diagnostics"].as_array().unwrap().iter().find(|d| d["code"] == "syntax_error").unwrap();
        for metadata in [&result["producer"], coverage, diagnostic] {
            assert_eq!(metadata["prism_version"], "1.9.0");
            assert_eq!(metadata["ruby_syntax_version"], "4.1");
            assert_eq!(metadata["parser_policy"], "prism-default-guarded");
        }
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
    fn node_limit_validation_is_typed_and_bounded() {
        assert_eq!(effective_limits(&json!({})).unwrap()["max_nodes"], 1_000_000);
        for n in [1, 999_999, 5_000_000] {
            assert_eq!(effective_limits(&json!({"max_nodes": n})).unwrap()["max_nodes"], n);
        }
        for value in [json!(0), json!(-1), json!(1.0), json!("1"), json!(null), json!(5_000_001), json!(u64::MAX)] {
            assert_eq!(effective_limits(&json!({"max_nodes": value})).unwrap_err().code, "invalid_input");
        }
        assert_eq!(effective_limits(&json!({"max_files": 10_001})).unwrap_err().code, "invalid_input");
        assert_eq!(effective_limits(&json!({"unknown": 1})).unwrap_err().code, "invalid_input");
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

#[cfg(test)]
#[path = "capture_diagnostics_tests.rs"]
mod diagnostics_tests;
