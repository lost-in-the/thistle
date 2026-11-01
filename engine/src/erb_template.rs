//! Inert ERB -> same-byte-offset Ruby projection -> maintained Prism AST.
//! No ERB compiler/evaluator, Rails lookup, helper dispatch or template execution.
use crate::{error::{CoreError, Result}, schema, job_mail_source as source};
use serde_json::{json, Value};

/// Shared admission for the existing descriptor-anchored capture reader. It
/// passes raw bounded bytes directly, without an alternate byte transport.
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
        "selection":"unknown","execution":"unknown","reason":null,"scan_complete":false,"unsearched":"unsupported_source"});
    let ruby = match projection(content) {
        Ok(ruby) => ruby,
        Err(_) => { result["reason"] = json!("unsupported_or_unclosed_erb"); return Ok(result); }
    };
    let parsed = ruby_prism::parse(&ruby);
    if parsed.errors().next().is_some() { result["reason"] = json!("unsupported_ruby_projection"); return Ok(result); }
    let mut references = Vec::new();
    let spans = source::Spans::new(content);
    let (nodes, complete) = source::walk(parsed.node(), |node| {
        if references.len() >= 200 { return Ok(false); }
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
                    references.push(json!({"kind":if call.is_variable_call() {"local_or_helper_candidate"} else {"call_or_helper_candidate"},"name":name,"span":span,
                        "binding":"unknown","invocation":"unknown"}));
                }
            }
        }
        Ok(true)
    })?;
    references.sort_by_key(|r| r["span"]["start_byte"].as_u64());
    result["references"] = json!(references);
    result["status"] = json!(if complete {"partial"} else {"bounded_partial"});
    result["scan_complete"] = json!(complete);
    result["nodes_visited"] = json!(nodes);
    result["unsearched"] = if complete {Value::Null} else {json!("remaining_reference_or_node_work")};
    result["reason"] = json!(if complete {"Supported ERB tags and Ruby syntax only; dynamic selection, local values, helper binding and execution remain unknown"}
        else {"Template reference/node allowance exhausted; remaining references unsearched. Binding and execution unknown"});
    schema::encoded_bytes(&result,128*1024)?;
    Ok(result)
}

#[cfg(test)]
#[path = "erb_template_tests.rs"]
mod tests;
