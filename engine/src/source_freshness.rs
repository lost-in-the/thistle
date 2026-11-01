//! Explicit comparison with one pinned recorded digest, never blob integrity.
use crate::{error::{CoreError, Result}, fs::Dir, schema, store::Reader};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{fs::Metadata, io::{self, Read}, os::unix::fs::MetadataExt, path::Path};

pub(crate) const SCRATCH: usize = 256 * 1024;
const DEFAULT_BYTES: usize = 2 * 1024 * 1024;
const PATH_BYTES: usize = 4096;
const DEPTH: usize = 64;
const CHUNK: usize = 16 * 1024;
const IO_ATTEMPTS: usize = 1024;

pub(crate) struct Query<'a> { path: &'a str, root: Option<&'a str>, max_bytes: usize }
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let path = schema::path(schema::string(request, "file_path")?)?;
        let root = match request.get("workspace_root") {
            None | Some(Value::Null) => None,
            Some(value) => Some(value.as_str().ok_or_else(|| CoreError::input("Workspace root must be a string or null"))?),
        };
        let max_bytes = match request.get("max_bytes") {
            None => DEFAULT_BYTES,
            Some(value) => value.as_u64().filter(|n| *n <= schema::MAX_SOURCE as u64)
                .ok_or_else(|| CoreError::input("Source freshness max_bytes must be an integer from 0 through 4194304"))? as usize,
        };
        Ok(Self { path, root, max_bytes })
    }
}

#[derive(Default)]
struct Usage {
    directory_opens: usize, file_opens: usize, stats: usize, reads: usize,
    bytes_read: usize, bytes_hashed: usize,
}
#[derive(Clone, Copy)]
enum Attempt { Directory, File, Stat, Read }
impl Usage {
    fn attempt(&mut self, kind: Attempt) -> std::result::Result<(), &'static str> {
        if self.directory_opens + self.file_opens + self.stats + self.reads >= IO_ATTEMPTS { return Err("work_limit"); }
        match kind {
            Attempt::Directory => self.directory_opens += 1,
            Attempt::File => self.file_opens += 1,
            Attempt::Stat => self.stats += 1,
            Attempt::Read => self.reads += 1,
        }
        Ok(())
    }
    fn value(&self) -> Value {
        json!({"metadata_lookups":1, "directory_open_attempts":self.directory_opens,
            "file_open_attempts":self.file_opens, "stat_attempts":self.stats, "read_attempts":self.reads,
            "io_attempts":self.directory_opens+self.file_opens+self.stats+self.reads,
            "bytes_read":self.bytes_read,"bytes_hashed":self.bytes_hashed})
    }
}

#[derive(Clone, Copy)]
enum Event { BeforeOpen, Opened, BeforeRead, ReadComplete, BeforeRevalidate }
#[derive(Default)]
struct Observer<'a> {
    #[cfg(test)]
    hook: Option<&'a mut dyn FnMut(Event) -> io::Result<()>>,
    lifetime: std::marker::PhantomData<&'a ()>,
}
impl Observer<'_> {
    fn at(&mut self, _event: Event) -> io::Result<()> {
        #[cfg(test)]
        if let Some(hook) = &mut self.hook { return hook(_event); }
        Ok(())
    }
}

fn access(error: CoreError) -> &'static str {
    match error.code {
        "not_found" => "missing",
        "unsafe_path" => "unsafe_path_or_nonregular",
        "unsupported_platform" => "unsupported_platform",
        _ => "unreadable",
    }
}
fn read_error(error: io::Error) -> &'static str {
    if error.kind() == io::ErrorKind::Interrupted { "interrupted" } else { "read_failed" }
}
fn same_directory(a: &Metadata, b: &Metadata) -> bool { a.dev() == b.dev() && a.ino() == b.ino() && b.is_dir() }
fn same_file(a: &Metadata, b: &Metadata) -> bool {
    a.is_file() && b.is_file() && a.dev() == b.dev() && a.ino() == b.ino() && a.len() == b.len() &&
        a.mode() == b.mode() && a.nlink() == b.nlink() && a.uid() == b.uid() && a.gid() == b.gid() &&
        a.mtime() == b.mtime() && a.mtime_nsec() == b.mtime_nsec() &&
        a.ctime() == b.ctime() && a.ctime_nsec() == b.ctime_nsec()
}

pub(crate) fn select(reader: &Reader, q: &Query<'_>) -> Result<Value> {
    select_observed(reader, q, &mut Observer::default())
}
fn select_observed(reader: &Reader, q: &Query<'_>, observer: &mut Observer<'_>) -> Result<Value> {
    // Selected metadata is validated BEFORE any root access, including hooks.
    let saved = reader.selected_file_metadata(q.path)?;
    let mut usage = Usage::default();
    let (status, reason) = match q.root {
        None => ("not_checked", "workspace_root_not_supplied"),
        Some(root) => match compare(q, root, saved, &mut usage, observer) {
            Ok(true) => ("matching", "recorded_digest_matches"),
            Ok(false) => ("changed", "recorded_digest_differs"),
            Err(reason) => ("unverifiable", reason),
        },
    };
    Ok(json!({"version":1,"generation":reader.generation,
        "file":{"path":saved["path"],"sha256":saved["sha256"],"bytes":saved["bytes"]},
        "status":status,"reason":reason,"usage":usage.value(),
        "limits":{"max_bytes":q.max_bytes,"max_read_bytes":q.max_bytes+1,"eof_probe_bytes":1,
            "max_root_bytes":PATH_BYTES,"max_path_bytes":PATH_BYTES,
            "max_root_components":DEPTH,"max_path_components":DEPTH,"chunk_bytes":CHUNK,
            "max_retained_directory_descriptors":2*DEPTH,"max_live_descriptors":2*DEPTH+2,
            "max_io_attempts":IO_ATTEMPTS,"scratch_reserved_bytes":SCRATCH},
        "scope":"One file compared with its recorded digest at check time; saved blob integrity, CURRENT freshness and source/runtime coherence are separate. Descriptor and path revalidation detect some races, not an atomic snapshot or future freshness guarantee."}))
}

fn compare(q: &Query<'_>, root: &str, saved: &Value, usage: &mut Usage, observer: &mut Observer<'_>) -> std::result::Result<bool, &'static str> {
    if root.len() > PATH_BYTES { return Err("root_limit"); }
    // Require an explicit absolute spelling. No current_dir, manifest root,
    // canonicalize, symlink following, or lexical normalization.
    if !root.starts_with('/') || root == "/" || root.contains('\\') || root.chars().any(char::is_control) ||
        root[1..].split('/').any(|s| s.is_empty() || s == "." || s == "..") { return Err("unsafe_root"); }
    let root_depth = root[1..].split('/').count();
    let path_depth = q.path.split('/').count();
    if root_depth > DEPTH { return Err("root_limit"); }
    if path_depth > DEPTH { return Err("path_limit"); }
    observer.at(Event::BeforeOpen).map_err(|error| if error.kind() == io::ErrorKind::Interrupted { "interrupted" } else { "unreadable" })?;

    // Retain the bounded descriptor chain, including every absolute ancestor.
    // Reopen each named edge relative to its original parent before deciding.
    let mut chain = Vec::with_capacity(root_depth + path_depth);
    usage.attempt(Attempt::Directory)?;
    let slash = Dir::open(Path::new("/"), false).map_err(access)?;
    usage.attempt(Attempt::Stat)?;
    let slash_meta = slash.metadata().map_err(access)?;
    chain.push((slash, slash_meta));
    let parents = root[1..].split('/').chain(q.path.split('/').take(path_depth - 1));
    for component in parents.clone() {
        usage.attempt(Attempt::Directory)?;
        let dir = chain.last().unwrap().0.child(component, false).map_err(access)?;
        usage.attempt(Attempt::Stat)?;
        let metadata = dir.metadata().map_err(access)?;
        chain.push((dir, metadata));
    }
    let leaf = q.path.rsplit('/').next().unwrap();
    let parent = &chain.last().unwrap().0;
    usage.attempt(Attempt::File)?;
    // The shared descriptor primitive uses O_NOFOLLOW|O_NONBLOCK; admit only
    // regular files by fstat before reading, including zero-length files.
    let mut file = parent.file_descriptor(leaf, libc::O_RDONLY).map_err(access)?;
    usage.attempt(Attempt::Stat)?;
    let before = file.metadata().map_err(|_| "unreadable")?;
    if !before.is_file() { return Err("unsafe_path_or_nonregular"); }
    observer.at(Event::Opened).map_err(read_error)?;
    if before.len() > q.max_bytes as u64 { return Err("byte_limit"); }

    let mut hash = Sha256::new();
    let mut buffer = [0u8; CHUNK];
    // A regular file's admitted stat size bounds the read exactly, including
    // empty files and files at max_bytes. A separately accounted one-byte EOF
    // probe below prevents nonstandard regular files with synthetic stat sizes
    // from being called matching without observing their complete extent.
    while usage.bytes_read < before.len() as usize {
        observer.at(Event::BeforeRead).map_err(read_error)?;
        let remaining = before.len() as usize - usage.bytes_read;
        usage.attempt(Attempt::Read)?;
        let count = file.read(&mut buffer[..remaining.min(CHUNK)]).map_err(read_error)?;
        if count == 0 { return Err("incomplete_read"); }
        usage.bytes_read += count;
        hash.update(&buffer[..count]);
        usage.bytes_hashed += count;
    }
    observer.at(Event::BeforeRead).map_err(read_error)?;
    usage.attempt(Attempt::Read)?;
    let probe = file.read(&mut buffer[..1]).map_err(read_error)?;
    if probe != 0 {
        usage.bytes_read += probe;
        // Charge and hash the successfully read probe even though this result
        // cannot be matching. The live digest never leaves this operation.
        hash.update(&buffer[..probe]); usage.bytes_hashed += probe;
        return Err("incomplete_read");
    }
    observer.at(Event::ReadComplete).map_err(read_error)?;
    usage.attempt(Attempt::Stat)?;
    let after = file.metadata().map_err(|_| "concurrent_change")?;
    if !same_file(&before, &after) { return Err("concurrent_change"); }
    observer.at(Event::BeforeRevalidate).map_err(read_error)?;
    for (index, component) in parents.enumerate() {
        usage.attempt(Attempt::Directory)?;
        let reopened = chain[index].0.child(component, false).map_err(|_| "concurrent_change")?;
        usage.attempt(Attempt::Stat)?;
        let current = reopened.metadata().map_err(|_| "concurrent_change")?;
        if !same_directory(&chain[index+1].1, &current) { return Err("concurrent_change"); }
    }
    usage.attempt(Attempt::File)?;
    let reopened = parent.file_descriptor(leaf, libc::O_RDONLY).map_err(|_| "concurrent_change")?;
    usage.attempt(Attempt::Stat)?;
    let current = reopened.metadata().map_err(|_| "concurrent_change")?;
    if !same_file(&before, &current) { return Err("concurrent_change"); }
    let digest = format!("{:x}", hash.finalize());
    Ok(saved["bytes"].as_u64() == Some(usage.bytes_read as u64) && saved["sha256"].as_str() == Some(digest.as_str()))
}

#[cfg(test)]
#[path = "source_freshness_tests.rs"]
mod tests;
