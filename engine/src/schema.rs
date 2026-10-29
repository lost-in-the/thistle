use crate::error::{CoreError, Result};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::{HashMap, HashSet};

pub const VERSION: u64 = 1;
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

pub fn facts(facts: &[Value], files: &[Value]) -> Result<()> {
    if facts.len() > 100_000 { return Err(CoreError::limit("Fact count exceeds 100000")); }
    let by_path: HashMap<&str, &Value> = files.iter().map(|v| (v["path"].as_str().unwrap_or(""), v)).collect();
    let newlines: HashMap<&str, Vec<usize>> = files.iter().filter_map(|file| {
        file["content"].as_str().map(|content| (file["path"].as_str().unwrap_or(""),
            content.bytes().enumerate().filter_map(|(offset, byte)| (byte == b'\n').then_some(offset)).collect()))
    }).collect();
    let mut ids = HashSet::new();
    for fact in facts {
        let id = hash(string(fact, "id")?)?;
        if !ids.insert(id) { return Err(CoreError::input("Duplicate fact identity")); }
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
        for link in array(fact, "links")? {
            for key in ["relation", "target"] {
                let text = string(link, key)?;
                if text.is_empty() || text.len() > 4096 { return Err(CoreError::input("Invalid link label or target")); }
            }
            if !matches!(link["resolution"].as_str(), Some("resolved") | Some("unresolved")) {
                return Err(CoreError::input("Link resolution must be explicit"));
            }
            if let Some(ext) = link.get("attributes").and_then(|a| a.get("thistle_call")) {
                // Unrecognized versions are opaque. Version 1 is a strict, bounded contract.
                if ext.get("version").and_then(Value::as_u64) == Some(1) {
                    let obj = ext.as_object().ok_or_else(|| CoreError::input("Invalid call metadata"))?;
                    if obj.len() != 5 || !["version", "receiver", "safe_navigation", "call_location", "receiver_location"].iter().all(|k| obj.contains_key(*k)) ||
                        link["relation"] != "calls" || link["resolution"] != "unresolved" || fact["evidence"] != "static" || !ext["safe_navigation"].is_boolean() {
                        return Err(CoreError::input("Invalid call metadata shape"));
                    }
                    let receiver = ext["receiver"].as_object().ok_or_else(|| CoreError::input("Invalid call receiver"))?;
                    if receiver.len() != 3 || !["kind", "name", "omitted_limit"].iter().all(|k| receiver.contains_key(*k)) {
                        return Err(CoreError::input("Invalid call receiver shape"));
                    }
                    let kind = ext["receiver"]["kind"].as_str().ok_or_else(|| CoreError::input("Invalid receiver kind"))?;
                    let named = matches!(kind, "constant" | "local" | "instance_variable");
                    let omitted = ext["receiver"]["omitted_limit"].as_bool().ok_or_else(|| CoreError::input("Invalid omitted flag"))?;
                    let name = &ext["receiver"]["name"];
                    if !matches!(kind, "implicit" | "self" | "constant" | "local" | "instance_variable" | "call" | "literal" | "expression") ||
                       (named && !(omitted && name.is_null() || !omitted && name.as_str().is_some_and(|s| !s.is_empty() && s.len() <= 256))) ||
                       (!named && (!name.is_null() || omitted)) {
                        return Err(CoreError::input("Invalid call receiver combination"));
                    }
                    let file = file.ok_or_else(|| CoreError::input("Call metadata needs captured source"))?;
                    validate_call_location(&ext["call_location"], file, &newlines)?;
                    if kind == "implicit" {
                        if ext["safe_navigation"] == true { return Err(CoreError::input("Implicit receiver cannot use safe navigation")); }
                        if !ext["receiver_location"].is_null() { return Err(CoreError::input("Implicit receiver has a location")); }
                    } else {
                        validate_call_location(&ext["receiver_location"], file, &newlines)?;
                    }
                }
            }
        }
    }
    Ok(())
}

fn validate_call_location(location: &Value, file: &Value, newlines: &HashMap<&str, Vec<usize>>) -> Result<()> {
    let obj = location.as_object().ok_or_else(|| CoreError::input("Call location must be an object"))?;
    if obj.len() != 4 || !["start_line", "end_line", "start_byte", "end_byte"].iter().all(|k| obj.contains_key(*k)) {
        return Err(CoreError::input("Invalid call location shape"));
    }
    let values: Vec<u64> = ["start_line", "end_line", "start_byte", "end_byte"].iter().map(|key|
        location[*key].as_u64().ok_or_else(|| CoreError::input("Call bounds must be nonnegative integers"))
    ).collect::<Result<_>>()?;
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

pub fn capture(value: &Value) -> Result<()> {
    depth(value)?;
    hash(string(value, "root_id")?)?;
    if !value["producer"].is_object() { return Err(CoreError::input("producer must be an object")); }
    files(array(value, "files")?, true)?;
    facts(array(value, "facts")?, array(value, "files")?)?;
    coverage(value)?;
    array(value, "diagnostics")?;
    Ok(())
}
