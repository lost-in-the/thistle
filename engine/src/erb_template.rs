//! Inert ERB -> same-byte-offset Ruby projection -> maintained Prism AST.
//! No ERB compiler/evaluator, Rails lookup, helper dispatch or template execution.
use crate::{error::{CoreError, Result}, schema, job_mail_source as source};
use serde_json::{json, Value};

/// Root's capture aggregator supplies bytes from its anchored open-file policy.
/// Admission yields a normal saved source-file record, never evaluates ERB.
pub(crate) fn admit_raw(raw: &Value) -> Result<Value> {
    schema::depth(raw)?;
    schema::model_object(raw,&["path","content_bytes","bytes","sha256","provenance"])?;
    let path = schema::path(schema::string(raw,"path")?)?;
    if !path.ends_with(".erb") || raw["provenance"] != "raw_template_bytes" {
        return Err(CoreError::input("Unsupported raw template provenance"));
    }
    let values = schema::array(raw,"content_bytes")?;
    if values.len() > source::MAX_BYTES { return Err(CoreError::limit("Raw template byte limit")); }
    let bytes = values.iter().map(|v| v.as_u64().filter(|n| *n <= 255).map(|n| n as u8)
        .ok_or_else(|| CoreError::input("Invalid raw template byte"))).collect::<Result<Vec<u8>>>()?;
    if raw["bytes"].as_u64() != Some(bytes.len() as u64) || raw["sha256"] != schema::digest(&bytes) {
        return Err(CoreError::input("Raw template size/digest mismatch"));
    }
    admit_bytes(path,&bytes,schema::string(raw,"sha256")?)
}

/// Shared admission for the existing descriptor-anchored capture reader. It
/// passes raw bounded bytes directly, without numeric JSON transport/copies.
pub(crate) fn admit_bytes(path: &str, bytes: &[u8], digest: &str) -> Result<Value> {
    schema::path(path)?;
    if !path.ends_with(".erb") { return Err(CoreError::input("Only ERB source is admitted")); }
    if bytes.len() > source::MAX_BYTES { return Err(CoreError::limit("Raw template byte limit")); }
    schema::hash(digest)?;
    if schema::digest(bytes) != digest { return Err(CoreError::input("Raw template digest mismatch")); }
    let content = std::str::from_utf8(bytes).map_err(|_| CoreError::input("Unsupported template encoding; UTF-8 required"))?;
    Ok(json!({"path":path,"bytes":bytes.len(),"sha256":digest,"encoding":"UTF-8","content":content}))
}

fn projection(content: &str) -> Result<Vec<u8>> {
    let bytes = content.as_bytes();
    let mut ruby: Vec<u8> = bytes.iter().map(|b| if *b == b'\n' { b'\n' } else { b' ' }).collect();
    let mut cursor = 0;
    while cursor + 1 < bytes.len() {
        if bytes[cursor..].starts_with(b"<%") {
            let begin = cursor;
            let escaped = bytes.get(cursor + 2) == Some(&b'%');
            let comment = bytes.get(cursor + 2) == Some(&b'#');
            cursor += if matches!(bytes.get(cursor+2), Some(b'='|b'-'|b'%'|b'#')) {3} else {2};
            let body = cursor;
            while cursor + 1 < bytes.len() && !bytes[cursor..].starts_with(b"%>") { cursor += 1; }
            if cursor + 1 >= bytes.len() { return Err(CoreError::input("Unclosed ERB tag")); }
            if !escaped && !comment {
                let end = if cursor > body && bytes[cursor-1] == b'-' { cursor-1 } else { cursor };
                ruby[body..end].copy_from_slice(&bytes[body..end]);
                ruby[cursor] = b';';
            }
            cursor += 2;
            if cursor <= begin { return Err(CoreError::input("Invalid ERB position")); }
        } else { cursor += 1; }
    }
    Ok(ruby)
}

/// Called on the existing capture parser worker. Input is an admitted UTF-8
/// file descriptor record; output contains source references, never execution.
pub(crate) fn analyze(path: &str, content: &str) -> Result<Value> {
    schema::path(path)?;
    if !path.ends_with(".erb") { return Err(CoreError::input("Only ERB is supported")); }
    if content.len() > source::MAX_BYTES { return Err(CoreError::limit("Template source byte limit")); }
    let mut result = json!({"version":1,"path":path,"sha256":schema::digest(content.as_bytes()),
        "bytes":content.len(),"provenance":"inert_source","status":"unknown","references":[],
        "selection":"unknown","execution":"unknown","reason":null});
    let ruby = match projection(content) {
        Ok(ruby) => ruby,
        Err(_) => { result["reason"] = json!("unsupported_or_unclosed_erb"); return Ok(result); }
    };
    let parsed = ruby_prism::parse(&ruby);
    if parsed.errors().next().is_some() { result["reason"] = json!("unsupported_ruby_projection"); return Ok(result); }
    let mut references = Vec::new();
    let spans = source::Spans::new(content);
    source::walk(parsed.node(), |node| {
        if references.len() >= 200 { return Err(CoreError::limit("Template reference limit")); }
        if let Some(var) = node.as_instance_variable_read_node() {
            references.push(json!({"kind":"instance_variable","name":source::text(var.name().as_slice()),
                "span":spans.span(node.location(),0),"value":"unknown"}));
        }
        if let Some(call) = node.as_call_node() {
            if call.receiver().is_none() {
                let name = source::text(call.name().as_slice());
                let span = spans.span(node.location(),0);
                if name == "render" {
                    let partial = source::keyword(&call,"partial")?;
                    let target = partial.as_ref().and_then(source::literal_string);
                    references.push(json!({"kind":"partial_candidate","target":target,"span":span,
                        "selection":if target.is_some() {"literal_source_candidate"} else {"dynamic_or_unsupported_unknown"},
                        "binding":"unknown"}));
                } else {
                    references.push(json!({"kind":"helper_candidate","name":name,"span":span,
                        "binding":"unknown","invocation":"unknown"}));
                }
            }
        }
        Ok(())
    })?;
    references.sort_by_key(|r| r["span"]["start_byte"].as_u64());
    result["references"] = json!(references);
    result["status"] = json!("partial");
    result["reason"] = json!("Supported ERB tags and Ruby syntax only; dynamic selection, local values, helper binding and execution remain unknown");
    schema::encoded_bytes(&result,128*1024)?;
    Ok(result)
}

#[cfg(test)]
#[path = "erb_template_tests.rs"]
mod tests;
