use crate::error::{CoreError, Result};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};

pub const VERSION: u64 = 3;

pub fn snapshot_version(value: &Value) -> Result<u64> {
    match value.as_u64() {
        Some(version @ (1 | 2 | 3)) => Ok(version),
        _ => Err(CoreError::input("Unsupported snapshot schema")),
    }
}

pub fn capture_version(value: &Value) -> Result<u64> {
    value.get("schema_version").map_or(Ok(1), snapshot_version)
}
pub const MAX_SOURCE: usize = 4 * 1024 * 1024;
pub const MAX_FACTS_BYTES: usize = 64 * 1024 * 1024;
pub const MAX_MANIFEST: usize = 8 * 1024 * 1024;
pub const MAX_REQUEST: usize = 128 * 1024 * 1024;
pub const MAX_DEPTH: usize = 64;

pub fn depth(value: &Value) -> Result<()> {
    let mut pending = vec![(value, 0usize)];
    while let Some((value, level)) = pending.pop() {
        if level > MAX_DEPTH { return Err(CoreError::limit("JSON structure exceeds 64 nested levels")); }
        match value {
            Value::Array(values) => pending.extend(values.iter().map(|v| (v, level + 1))),
            Value::Object(values) => pending.extend(values.values().map(|v| (v, level + 1))),
            _ => {},
        }
    }
    Ok(())
}

pub fn digest(bytes: &[u8]) -> String { format!("{:x}", Sha256::digest(bytes)) }
pub fn canonical(value: &Value) -> Result<Vec<u8>> { Ok(serde_json::to_vec(value)?) }

pub fn string<'a>(value: &'a Value, key: &str) -> Result<&'a str> {
    value.get(key).and_then(Value::as_str).ok_or_else(|| CoreError::input(format!("{key} must be a string")))
}
pub fn array<'a>(value: &'a Value, key: &str) -> Result<&'a Vec<Value>> {
    value.get(key).and_then(Value::as_array).ok_or_else(|| CoreError::input(format!("{key} must be an array")))
}
pub fn hash(value: &str) -> Result<&str> {
    if value.len() != 64 || !value.bytes().all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase()) {
        return Err(CoreError::input("Expected a lowercase SHA-256 digest"));
    }
    Ok(value)
}
pub fn path(value: &str) -> Result<&str> {
    if value.is_empty() || value.len() > 4096 || value.contains('\\') || value.chars().any(char::is_control) ||
        value.split('/').any(|part| part.is_empty() || part == "." || part == "..") {
        return Err(CoreError::new("unsafe_path", "Expected a safe relative source path"));
    }
    Ok(value)
}

pub fn files(files: &[Value], with_content: bool) -> Result<()> {
    if files.len() > 20_000 { return Err(CoreError::limit("Source file count exceeds 20000")); }
    let mut paths = HashSet::new();
    for file in files {
        let file_path = path(string(file, "path")?)?;
        if !paths.insert(file_path) { return Err(CoreError::input("Duplicate source path")); }
        let expected = hash(string(file, "sha256")?)?;
        let bytes = file["bytes"].as_u64().ok_or_else(|| CoreError::input("Source bytes must be nonnegative"))?;
        if bytes > MAX_SOURCE as u64 { return Err(CoreError::limit("Source exceeds 4 MiB")); }
        string(file, "encoding")?;
        if with_content {
            let content = string(file, "content")?.as_bytes();
            if content.len() as u64 != bytes || digest(content) != expected {
                return Err(CoreError::input("Source size/digest differs from captured UTF-8 content"));
            }
        }
    }
    Ok(())
}

pub fn facts(facts: &[Value], files: &[Value], version: u64) -> Result<()> {
    validate_facts(facts.iter(), files, version, false)
}

/// Stored rows are interpreted only through explicit manifest context. Iterators
/// let Source/Check validate pinned subsets without cloning their link trees.
pub(crate) fn stored_facts<'a>(facts: impl IntoIterator<Item = &'a Value>, files: &[Value], version: u64) -> Result<()> {
    validate_facts(facts, files, version, true)
}

fn validate_facts<'a>(facts: impl IntoIterator<Item = &'a Value>, files: &[Value], version: u64, stored: bool) -> Result<()> {
    if !matches!(version, 1 | 2 | 3) { return Err(CoreError::input("Unsupported snapshot schema")); }
    let facts = facts.into_iter();
    if facts.size_hint().0 > 100_000 { return Err(CoreError::limit("Fact count exceeds 100000")); }
    let by_path: HashMap<&str, &Value> = files.iter().map(|v| (v["path"].as_str().unwrap_or(""), v)).collect();
    let newlines: HashMap<&str, Vec<usize>> = files.iter().filter_map(|file| {
        file["content"].as_str().map(|content| (file["path"].as_str().unwrap_or(""),
            content.bytes().enumerate().filter_map(|(offset, byte)| (byte == b'\n').then_some(offset)).collect()))
    }).collect();
    let mut ids = HashSet::new();
    for fact in facts {
        let id = hash(string(fact, "id")?)?;
        if !ids.insert(id) { return Err(CoreError::input("Duplicate fact identity")); }
        if ids.len() > 100_000 { return Err(CoreError::limit("Fact count exceeds 100000")); }
        for key in ["kind", "name"] {
            let v = string(fact, key)?;
            if v.is_empty() || v.len() > 4096 { return Err(CoreError::input("Fact name/kind is empty or oversized")); }
        }
        if !matches!(fact["evidence"].as_str(), Some("static") | Some("runtime")) {
            return Err(CoreError::input("Fact evidence must be static or runtime"));
        }
        if !fact["attributes"].is_object() { return Err(CoreError::input("Fact attributes must be an object")); }
        let file = if fact["path"].is_null() { None } else {
            let p = path(string(fact, "path")?)?;
            Some(*by_path.get(p).ok_or_else(|| CoreError::input("Fact source was not captured"))?)
        };
        if !fact["location"].is_null() {
            let file = file.ok_or_else(|| CoreError::input("Source location needs a captured file"))?;
            let location = &fact["location"];
            let values: Vec<u64> = ["start_line", "end_line", "start_byte", "end_byte"].iter().map(|key|
                location[*key].as_u64().ok_or_else(|| CoreError::input("Source bounds must be nonnegative integers"))
            ).collect::<Result<_>>()?;
            if values[0] == 0 || values[1] < values[0] || values[3] < values[2] || values[3] > file["bytes"].as_u64().unwrap_or(0) {
                return Err(CoreError::input("Source location is out of bounds"));
            }
            if let Some(content) = file["content"].as_str() {
                let lines = &newlines[file["path"].as_str().unwrap()];
                if !content.is_char_boundary(values[2] as usize) || !content.is_char_boundary(values[3] as usize) ||
                    lines.partition_point(|offset| *offset < values[2] as usize) as u64 + 1 != values[0] ||
                    lines.partition_point(|offset| *offset < values[3] as usize) as u64 + 1 != values[1] {
                    return Err(CoreError::input("Source byte and line positions disagree with captured content"));
                }
            }
        }
        if fact["kind"] == "rails_model" { model_fact(fact)?; }
        if fact["kind"] == "rails_save_callbacks" { crate::callbacks::validate_fact(fact)?; }
        for link in array(fact, "links")? {
            let view = if stored {
                crate::link_encoding::SemanticLinkView::from_wire(link, version, string(fact, "evidence")?)?
            } else {
                crate::link_encoding::SemanticLinkView::from_semantic(link, version, string(fact, "evidence")?)?
            };
            if let Some(call) = view.call_metadata() {
                let file = file.ok_or_else(|| CoreError::input("Call metadata needs captured source"))?;
                validate_call_location(call.location, file, &newlines)?;
                if let Some(receiver) = call.receiver_location { validate_call_location(receiver, file, &newlines)?; }
            }
        }
    }
    Ok(())
}

/// Named, borrowed interpretation of a single recognized extension. Unknown
/// extensions (including compact-looking v2 in schema 1) remain opaque.
pub struct CallMetadata<'a> {
    pub kind: &'a str,
    pub name: Option<&'a str>,
    pub omitted: bool,
    pub safe_navigation: bool,
    pub location: CallLocation,
    pub receiver_location: Option<CallLocation>,
}

#[derive(Clone, Copy)]
pub struct CallLocation {
    pub start_byte: u64,
    pub end_byte: u64,
    pub start_line: u64,
    pub end_line: u64,
}

impl CallLocation {
    fn decode(value: &Value, compact: bool) -> Result<Self> {
        let [start, end, first, last] = if compact {
            let values: &[Value; 4] = value.as_array().and_then(|v| v.as_slice().try_into().ok())
                .ok_or_else(|| CoreError::input("Call location must have four coordinates"))?;
            [&values[0], &values[1], &values[2], &values[3]]
        } else {
            exact_keys(value, &["start_byte", "end_byte", "start_line", "end_line"])?;
            [&value["start_byte"], &value["end_byte"], &value["start_line"], &value["end_line"]]
        };
        let number = |v: &Value| v.as_u64().ok_or_else(|| CoreError::input("Call bounds must be nonnegative integers"));
        Ok(Self { start_byte: number(start)?, end_byte: number(end)?, start_line: number(first)?, end_line: number(last)? })
    }
}

fn exact_keys(value: &Value, keys: &[&str]) -> Result<()> {
    if !value.as_object().is_some_and(|o| o.len() == keys.len() && keys.iter().all(|k| o.contains_key(*k))) {
        return Err(CoreError::input("Invalid call metadata shape"));
    }
    Ok(())
}

pub fn call_metadata(ext: &Value, schema: u64) -> Result<Option<CallMetadata<'_>>> {
    match ext.get("version").and_then(Value::as_u64) {
        Some(2) if matches!(schema, 2 | 3) => {
            // Schema 2 keeps its historical exact-key refusal. Schema 3 can
            // retain a complete extra-key object, but recognized DATA is strict.
            if schema == 2 { exact_keys(ext, &["version", "data"])?; }
            compact_call_metadata(&ext["data"]).map(Some)
        }
        Some(1) => {
            exact_keys(ext, &["version", "receiver", "safe_navigation", "call_location", "receiver_location"])?;
            let receiver = &ext["receiver"];
            exact_keys(receiver, &["kind", "name", "omitted_limit"])?;
            decode_call_fields([&receiver["kind"], &receiver["name"], &receiver["omitted_limit"],
                &ext["safe_navigation"], &ext["call_location"], &ext["receiver_location"]], false).map(Some)
        }
        _ => Ok(None),
    }
}

/// Borrow the existing compact-v2 SIX-SLOT DATA value, not an extension wrapper.
/// Explicit context selection belongs to call_metadata / SemanticLinkView.
pub(crate) fn compact_call_metadata(data: &Value) -> Result<CallMetadata<'_>> {
    let data: &[Value; 6] = data.as_array().and_then(|v| v.as_slice().try_into().ok())
        .ok_or_else(|| CoreError::input("Compact call data must have six fields"))?;
    decode_call_fields(data.each_ref(), true)
}

fn decode_call_fields(fields: [&Value; 6], compact: bool) -> Result<CallMetadata<'_>> {
    let [kind, name, omitted, safe, location, receiver_location] = fields;
    Ok(CallMetadata {
        kind: kind.as_str().ok_or_else(|| CoreError::input("Invalid receiver kind"))?,
        name: if name.is_null() { None } else { Some(name.as_str().ok_or_else(|| CoreError::input("Invalid receiver name"))?) },
        omitted: omitted.as_bool().ok_or_else(|| CoreError::input("Invalid omitted flag"))?,
        safe_navigation: safe.as_bool().ok_or_else(|| CoreError::input("Invalid safe navigation flag"))?,
        location: CallLocation::decode(location, compact)?,
        receiver_location: if receiver_location.is_null() { None } else { Some(CallLocation::decode(receiver_location, compact)?) },
    })
}

/// Receiver semantics shared by semantic objects and the borrowed row view.
/// Captured blob, UTF-8 and line/byte bounds remain full fact validation.
pub(crate) fn validate_call_shape(call: &CallMetadata<'_>) -> Result<()> {
    let named = matches!(call.kind, "constant" | "local" | "instance_variable");
    if !matches!(call.kind, "implicit" | "self" | "constant" | "local" | "instance_variable" | "call" | "literal" | "expression") ||
       (named && !(call.omitted && call.name.is_none() || !call.omitted && call.name.is_some_and(|s| !s.is_empty() && s.len() <= 256))) ||
       (!named && (call.name.is_some() || call.omitted)) {
        return Err(CoreError::input("Invalid call receiver combination"));
    }
    if call.kind == "implicit" {
        if call.safe_navigation || call.receiver_location.is_some() {
            return Err(CoreError::input("Implicit receiver has a location or safe navigation"));
        }
    } else if call.receiver_location.is_none() {
        return Err(CoreError::input("Missing receiver location"));
    }
    Ok(())
}

fn validate_call_location(location: CallLocation, file: &Value, newlines: &HashMap<&str, Vec<usize>>) -> Result<()> {
    let values = [location.start_line, location.end_line, location.start_byte, location.end_byte];
    if values[0] == 0 || values[1] < values[0] || values[3] < values[2] || values[3] > file["bytes"].as_u64().unwrap_or(0) {
        return Err(CoreError::input("Call location is out of bounds"));
    }
    if let Some(content) = file["content"].as_str() {
        let lines = &newlines[file["path"].as_str().unwrap()];
        if !content.is_char_boundary(values[2] as usize) || !content.is_char_boundary(values[3] as usize) ||
           lines.partition_point(|offset| *offset < values[2] as usize) as u64 + 1 != values[0] ||
           lines.partition_point(|offset| *offset < values[3] as usize) as u64 + 1 != values[1] {
            return Err(CoreError::input("Call byte and line positions disagree"));
        }
    }
    Ok(())
}

pub fn coverage(value: &Value) -> Result<()> {
    let coverage = array(value, "coverage")?;
    if coverage.is_empty() { return Err(CoreError::input("Explicit coverage is required")); }
    for item in coverage {
        if string(item, "family")?.is_empty() || !matches!(item["status"].as_str(), Some("complete") | Some("partial") | Some("unavailable")) ||
            item["scope"].as_str().is_none_or(|scope| scope.trim().is_empty()) || (!item["reason"].is_null() && !item["reason"].is_string()) {
            return Err(CoreError::input("Invalid scoped coverage"));
        }
    }
    Ok(())
}

// Diagnostic admission is separate from fact evidence. The existing manifest
// cap still applies to the complete output; this is not extra manifest space.
pub(crate) const MAX_DIAGNOSTIC_GROUPS: usize = 1_000;
pub(crate) const MAX_DIAGNOSTIC_BYTES: usize = MAX_MANIFEST;
// Covers the largest encoded {groups, occurrences} summary, including u64::MAX.
// Reserved even when a caller only emits individual records, so downstream
// summaries cannot turn an admitted array into an over-budget diagnostic output.
pub(crate) const DIAGNOSTIC_SUMMARY_BYTES: usize = 64;

/// Old records have one occurrence. Explicit counts must be exact positive u64s.
pub(crate) fn diagnostic_occurrences(record: &Value) -> Result<u64> {
    match record.get("occurrences") {
        None => Ok(1),
        Some(count) => count.as_u64().filter(|n| *n > 0)
            .ok_or_else(|| CoreError::input("Diagnostic occurrences must be a positive integer")),
    }
}

/// Count with the real JSON encoder without retaining another payload. Refuse
/// during encoding at the supplied budget, including checked accounting overflow.
pub(crate) fn encoded_bytes<T: serde::Serialize + ?Sized>(value: &T, max: usize) -> Result<usize> {
    Ok(encode_json(value, std::io::sink(), max)?.1)
}

/// The same bounded serde writer serves counting and retained publication bytes.
/// It refuses before a write would exceed the single global payload budget.
pub(crate) fn encoded_vec<T: serde::Serialize + ?Sized>(value: &T, max: usize) -> Result<Vec<u8>> {
    Ok(encode_json(value, Vec::new(), max)?.0)
}

fn encode_json<T: serde::Serialize + ?Sized, W: std::io::Write>(value: &T, writer: W, max: usize) -> Result<(W, usize)> {
    struct Bounded<W> { writer: W, bytes: usize, max: usize, refused: bool }
    impl<W: std::io::Write> std::io::Write for Bounded<W> {
        fn write(&mut self, bytes: &[u8]) -> std::io::Result<usize> {
            let Some(next) = self.bytes.checked_add(bytes.len()).filter(|n| *n <= self.max) else {
                self.refused = true;
                return Err(std::io::Error::other("Encoded JSON byte budget exceeded"));
            };
            self.writer.write_all(bytes)?;
            self.bytes = next;
            Ok(bytes.len())
        }
        fn flush(&mut self) -> std::io::Result<()> { self.writer.flush() }
    }
    let mut sink = Bounded { writer, bytes: 0, max, refused: false };
    if let Err(error) = serde_json::to_writer(&mut sink, value) {
        return Err(if sink.refused { CoreError::limit("Encoded JSON exceeds byte budget") } else { error.into() });
    }
    Ok((sink.writer, sink.bytes))
}

pub(crate) fn diagnostic_bytes<T: serde::Serialize + ?Sized>(value: &T) -> Result<usize> {
    encoded_bytes(value, MAX_DIAGNOSTIC_BYTES)
        .map_err(|_| CoreError::limit("Encoded diagnostics exceed the 8 MiB budget"))
}

pub(crate) fn diagnostic_budget(bytes: usize) -> Result<()> {
    if bytes.checked_add(DIAGNOSTIC_SUMMARY_BYTES).is_none_or(|n| n > MAX_DIAGNOSTIC_BYTES) {
        return Err(CoreError::limit("Encoded diagnostics exceed the 8 MiB budget"));
    }
    Ok(())
}

/// Machine-readable labels separate retained groups from total occurrences.
/// No summary is cached in capture metadata: Ruby can append runtime records.
pub(crate) fn diagnostic_counts(records: &[Value]) -> Result<Value> {
    if records.len() > MAX_DIAGNOSTIC_GROUPS {
        return Err(CoreError::limit("Diagnostics exceed 1000 retained groups"));
    }
    let mut occurrences = 0u64;
    for record in records {
        occurrences = occurrences.checked_add(diagnostic_occurrences(record)?)
            .ok_or_else(|| CoreError::limit("Diagnostic occurrence count overflow"))?;
    }
    diagnostic_budget(diagnostic_bytes(records)?)?;
    Ok(serde_json::json!({"groups": records.len(), "occurrences": occurrences}))
}

pub fn capture(value: &Value) -> Result<()> {
    depth(value)?;
    hash(string(value, "root_id")?)?;
    if !value["producer"].is_object() { return Err(CoreError::input("producer must be an object")); }
    files(array(value, "files")?, true)?;
    facts(array(value, "facts")?, array(value, "files")?, capture_version(value)?)?;
    coverage(value)?;
    diagnostic_counts(array(value, "diagnostics")?)?;
    Ok(())
}

/// Incremental admission shared by runtime observation families. Context is
/// untrusted; publication independently validates the complete actual capture.
/// Entries retain the existing per-observation-batch meaning, not source nodes.
pub(crate) struct ObservationAdmission {
    version: u64,
    max_facts: usize, max_links: usize, max_entries: usize,
    facts: usize, links: usize, entries: usize, bytes: usize,
    original_facts: usize, original_links: usize, original_bytes: usize,
}

impl ObservationAdmission {
    pub(crate) fn new(context: &Value) -> Result<Self> {
        let version = if let Some(version) = context.get("schema_version") {
            model_object(context, &["limits", "facts", "links", "diagnostics", "fact_bytes", "schema_version"])?;
            snapshot_version(version)?
        } else {
            model_object(context, &["limits", "facts", "links", "diagnostics", "fact_bytes"])?;
            1
        };
        let limits = &context["limits"];
        model_object(limits, &["max_facts", "max_links", "max_entries", "max_diagnostics"])?;
        let limit = |key, ceiling| -> Result<usize> {
            limits[key].as_u64().filter(|n| *n > 0 && *n <= ceiling).map(|n| n as usize)
                .ok_or_else(|| CoreError::input(format!("Invalid combined capture limit {key}")))
        };
        let max_facts = limit("max_facts", 100_000)?;
        let max_links = limit("max_links", 500_000)?;
        let max_entries = limit("max_entries", 100_000)?;
        let max_diagnostics = limit("max_diagnostics", 1_000)?;
        let used = |key: &str, ceiling: usize| -> Result<usize> {
            context[key].as_u64().filter(|n| *n <= ceiling as u64).map(|n| n as usize)
                .ok_or_else(|| CoreError::limit(format!("Invalid or exhausted observation admission counter {key}")))
        };
        let facts = used("facts", max_facts)?;
        let links = used("links", max_links)?;
        used("diagnostics", max_diagnostics)?;
        let bytes = used("fact_bytes", MAX_FACTS_BYTES)?;
        if bytes < 2 { return Err(CoreError::input("Fact array byte count must include its brackets")); }
        Ok(Self { version, max_facts, max_links, max_entries, facts, links, entries: 0, bytes,
            original_facts: facts, original_links: links, original_bytes: bytes })
    }

    pub(crate) fn ensure_facts(&self, count: usize) -> Result<()> {
        if self.facts.checked_add(count).is_none_or(|n| n > self.max_facts) {
            return Err(CoreError::limit("Combined observation capture exceeds max_facts"));
        }
        Ok(())
    }

    pub(crate) fn admit(&mut self, fact: &Value, entry_count: usize) -> Result<()> {
        self.ensure_facts(1)?;
        let entries = self.entries.checked_add(entry_count).filter(|n| *n <= self.max_entries)
            .ok_or_else(|| CoreError::limit("Observation metadata exceeds max_entries"))?;
        let links = self.links.checked_add(array(fact, "links")?.len()).filter(|n| *n <= self.max_links)
            .ok_or_else(|| CoreError::limit("Combined capture exceeds max_links"))?;
        // Existing [] already charged; every appended member needs at most one comma.
        let bytes = encoded_bytes(&crate::link_encoding::WireFact::new(fact, self.version)?, MAX_FACTS_BYTES)?.checked_add(1)
            .and_then(|n| self.bytes.checked_add(n)).filter(|n| *n <= MAX_FACTS_BYTES)
            .ok_or_else(|| CoreError::limit("Combined capture exceeds 64 MiB fact budget"))?;
        // No counter changes if any part of this fact refuses.
        self.facts += 1; self.links = links; self.entries = entries; self.bytes = bytes;
        Ok(())
    }

    /// Charges for this batch only, independent of caller-supplied prior sizes.
    pub(crate) fn appended(&self) -> Value {
        serde_json::json!({"facts":self.facts - self.original_facts,
            "links":self.links - self.original_links, "entries":self.entries,
            "fact_bytes":self.bytes - self.original_bytes})
    }
}

// Model v1 is deliberately closed: arbitrary nested application values must not
// cross this boundary, including opaque defaults that smuggle a serialized value.
pub(crate) fn model_object(value: &Value, fields: &[&str]) -> Result<()> {
    let object = value.as_object().ok_or_else(|| CoreError::input("Expected model object"))?;
    if object.len() != fields.len() || fields.iter().any(|k| !object.contains_key(*k)) {
        return Err(CoreError::input("Invalid model object fields"));
    }
    Ok(())
}

pub(crate) fn model_label(value: &Value) -> Result<()> {
    if value.is_null() || value.as_str().is_some_and(|s| !s.is_empty() && s.len() <= 4096) { return Ok(()); }
    Err(CoreError::input("Invalid model label"))
}

fn model_scalar(value: &Value) -> Result<()> {
    match value["kind"].as_str() {
        Some("literal" | "symbol") => {
            model_object(value, &["kind", "value"])?;
            let v = &value["value"];
            if value["kind"] == "symbol" {
                if v.as_str().is_none() { return Err(CoreError::input("Invalid model symbol")); }
                model_label(v)?;
            }
            if !(v.is_null() || v.is_boolean() || v.is_number() || v.as_str().is_some_and(|s| s.len() <= 4096)) {
                return Err(CoreError::input("Invalid model literal"));
            }
            Ok(())
        }
        Some("opaque" | "expression") => model_object(value, &["kind"]),
        _ => Err(CoreError::input("Invalid model value kind")),
    }
}

pub(crate) fn model_observation(data: &Value) -> Result<()> {
    model_object(data, &["name", "base_class", "superclass", "abstract", "table", "primary_key", "inheritance_column", "columns", "associations"])?;
    model_fields(data)
}

fn model_fields(data: &Value) -> Result<()> {
    for key in ["name", "base_class", "superclass", "table", "inheritance_column"] { model_label(&data[key])?; }
    if !data["abstract"].is_null() && !data["abstract"].is_boolean() { return Err(CoreError::input("Invalid abstract flag")); }
    if !data["primary_key"].is_null() {
        let keys = array(data, "primary_key")?;
        if keys.len() > 100_000 { return Err(CoreError::limit("Primary key exceeds max_entries")); }
        for key in keys { model_label(key)?; }
    }
    for family in ["columns", "associations"] {
        let value = &data[family];
        model_object(value, &["status", "entries"])?;
        let entries = array(value, "entries")?;
        if entries.len() > 100_000 { return Err(CoreError::limit("Model family exceeds max_entries")); }
        if !matches!(value["status"].as_str(), Some("observed" | "unavailable")) || value["status"] == "unavailable" && !entries.is_empty() {
            return Err(CoreError::input("Invalid model family coverage"));
        }
        let mut names = HashSet::new();
        for entry in entries {
            let name = string(entry, "name")?;
            model_label(&entry["name"])?;
            if !names.insert(name) { return Err(CoreError::input("Duplicate model family name")); }
            if family == "columns" {
                model_object(entry, &["name", "type", "sql_type", "null", "default"])?;
                model_label(&entry["type"])?;
                model_label(&entry["sql_type"])?;
                if !entry["null"].is_null() && !entry["null"].is_boolean() { return Err(CoreError::input("Invalid column nullability")); }
                model_scalar(&entry["default"])?;
            } else {
                model_object(entry, &["name", "macro", "target", "polymorphic", "through", "scope", "options", "omitted_options"])?;
                if !matches!(entry["macro"].as_str(), Some("belongs_to" | "has_many" | "has_one" | "has_and_belongs_to_many")) ||
                    !matches!(entry["scope"].as_str(), Some("none" | "opaque")) ||
                    !(entry["polymorphic"].is_null() || entry["polymorphic"].is_boolean()) ||
                    entry["polymorphic"] != false && !entry["target"].is_null() || entry["omitted_options"].as_u64().is_none() {
                    return Err(CoreError::input("Invalid association evidence"));
                }
                model_label(&entry["target"])?;
                model_label(&entry["through"])?;
                let options = entry["options"].as_object().ok_or_else(|| CoreError::input("Invalid association options"))?;
                for (key, value) in options {
                    if !["class_name", "foreign_key", "primary_key", "foreign_type", "as", "through", "source", "source_type", "inverse_of", "dependent", "optional", "required", "autosave", "counter_cache", "touch"].contains(&key.as_str()) {
                        return Err(CoreError::input("Unknown association option"));
                    }
                    model_scalar(value)?;
                }
            }
        }
    }
    Ok(())
}

fn model_fact(fact: &Value) -> Result<()> {
    model_object(&fact["attributes"], &["model"])?;
    let data = &fact["attributes"]["model"];
    if data["version"] != 1 || data["ordinal"].as_u64().is_none() || data["active_record_version"] != "8.1.4" ||
        data["coherence"] != "unknown" || data["source"] != "unavailable" || fact["evidence"] != "runtime" ||
        !fact["path"].is_null() || !fact["location"].is_null() {
        return Err(CoreError::input("Invalid model provenance"));
    }
    model_object(data, &["name", "base_class", "superclass", "abstract", "table", "primary_key", "inheritance_column", "columns", "associations",
        "version", "ordinal", "active_record_version", "coherence", "source"])?;
    model_fields(data)?;
    let name = data["name"].as_str().map(str::to_owned).unwrap_or_else(|| format!("Anonymous model {}", data["ordinal"]));
    let id = digest(&canonical(&serde_json::json!(["rails_model", 1, data["ordinal"], data["name"]]))?);
    if fact["name"] != name || fact["id"] != id || fact["links"] != Value::Array(crate::model::model_links(data)) {
        return Err(CoreError::input("Invalid model identity or labelled relationships"));
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn compact_types_arity_and_receiver_combinations_are_strict() {
        let content = "é\nhello\n";
        let files = vec![json!({"path":"a.rb","bytes":content.len(),"content":content})];
        let mut fact = json!({"id":"a".repeat(64),"kind":"method","name":"run","path":"a.rb","location":null,
            "evidence":"static","attributes":{},"links":[{"relation":"calls","target":"hello","resolution":"unresolved",
            "attributes":{"thistle_call":{"version":2,"data":["implicit",null,false,false,[0,2,1,1],null]}}}]});
        let pointer = "/links/0/attributes/thistle_call";
        for kind in ["implicit", "self", "constant", "local", "instance_variable", "call", "literal", "expression"] {
            let named = matches!(kind, "constant" | "local" | "instance_variable");
            for omitted in [false, true] {
                if omitted && !named { continue; }
                let name = if named && !omitted { json!("x".repeat(256)) } else { Value::Null };
                let receiver = if kind == "implicit" { Value::Null } else { json!([3,9,2,3]) };
                *fact.pointer_mut(pointer).unwrap() = json!({"version":2,"data":[kind,name,omitted,kind != "implicit",[0,2,1,1],receiver]});
                facts(&[fact.clone()], &files, 2).unwrap();
            }
        }
        let good = json!({"version":2,"data":["local","x",false,true,[0,2,1,1],[3,9,2,3]]});
        let mutations = [
            ("/data", json!([])), ("/data", json!(["local","x",false,true,[0,2,1,1],null,0])),
            ("/data/0", json!("unknown")), ("/data/1", json!(false)), ("/data/1", json!("")),
            ("/data/1", json!("x".repeat(257))), ("/data/2", json!(true)), ("/data/2", json!(0)),
            ("/data/3", json!(1)), ("/data/4", json!([0,2,1])), ("/data/4/0", json!(true)),
            ("/data/4/0", json!(-1)), ("/data/4/0", json!(0.0)), ("/data/4/1", json!(10)),
            ("/data/4/0", json!(1)), // inside UTF-8
            ("/data/4/2", json!(0)), ("/data/4/3", json!(2)), // line disagreement
            ("/data/5", Value::Null), ("/data/5/0", json!(1)), ("/data/5/1", json!(2)),
        ];
        for (path, value) in mutations {
            let mut bad = good.clone(); *bad.pointer_mut(path).unwrap() = value;
            *fact.pointer_mut(pointer).unwrap() = bad;
            assert!(facts(&[fact.clone()], &files, 2).is_err(), "{path}");
        }
        for extra in [json!({"version":2,"data":good["data"],"extra":0}), json!({"version":2})] {
            *fact.pointer_mut(pointer).unwrap() = extra;
            assert!(facts(&[fact.clone()], &files, 2).is_err());
        }
        *fact.pointer_mut(pointer).unwrap() = json!({"version":3,"future":true});
        facts(&[fact], &files, 2).unwrap();
    }
}
