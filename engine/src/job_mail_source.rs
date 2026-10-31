//! Source-potential annotations. Call only on the existing guarded capture/parser
//! worker: Prism parsing AND destruction require its large native stack.
use crate::{error::{CoreError, Result}, schema};
use ruby_prism::{Node, Location};
use serde_json::{json, Value};

#[path = "capture_children.rs"]
mod children;

pub(crate) const MAX_BYTES: usize = 262_144;
const MAX_NODES: usize = 20_000;
const MAX_ROWS: usize = 200;

pub(crate) fn text(bytes: &[u8]) -> String { String::from_utf8_lossy(bytes).into_owned() }
pub(crate) struct Spans { lines: Vec<usize> }
impl Spans {
    pub(crate) fn new(content: &str) -> Self {
        Self {lines:content.bytes().enumerate().filter_map(|(i,b)| (b==b'\n').then_some(i+1)).collect()}
    }
    pub(crate) fn span(&self, location: Location<'_>, base: usize) -> Value {
        let start = base + location.start_offset();
        let end = base + location.end_offset();
        json!({"start_byte":start,"end_byte":end,
            "start_line":self.lines.partition_point(|n| *n<=start)+1,
            "end_line":self.lines.partition_point(|n| *n<=end)+1})
    }
}

/// A constant syntax label, without resolving it or changing lexical scope.
pub(crate) fn constant(node: &Node<'_>) -> Option<String> {
    if node.as_constant_read_node().is_some() {
        let location = node.location(); let label = location.as_slice();
        return (label.len() <= 256).then(|| text(label));
    }
    let mut cursor = Some(node.as_constant_path_node()?.as_node());
    let mut count = 0;
    while let Some(value) = cursor {
        count += 1;
        if count > 64 { return None; }
        if value.as_constant_read_node().is_some() { break; }
        cursor = value.as_constant_path_node()?.parent();
    }
    let label = node.location().as_slice();
    (label.len() <= 256).then(|| text(label))
}

pub(crate) fn literal_string(node: &Node<'_>) -> Option<String> {
    let string = node.as_string_node()?;
    let value = string.unescaped();
    if value.len() > 4096 { return None; }
    std::str::from_utf8(value).ok().map(str::to_owned)
}

pub(crate) fn arguments<'a>(call: &ruby_prism::CallNode<'a>) -> Result<Vec<Node<'a>>> {
    let values: Vec<_> = call.arguments().map(|n| n.arguments().iter().take(65).collect()).unwrap_or_default();
    if values.len() > 64 { return Err(CoreError::limit("Job/mail call argument inspection limit")); }
    Ok(values)
}

pub(crate) fn keyword<'a>(call: &ruby_prism::CallNode<'a>, key: &str) -> Result<Option<Node<'a>>> {
    let mut found = None;
    for arg in arguments(call)? {
        let Some(hash) = arg.as_keyword_hash_node() else { continue; };
        for (index,item) in hash.elements().iter().take(65).enumerate() {
            if index == 64 { return Err(CoreError::limit("Job/mail keyword inspection limit")); }
            let Some(pair) = item.as_assoc_node() else { return Ok(None); }; // **dynamic options invalidate static selection
            let key_node = pair.key();
            let Some(symbol) = key_node.as_symbol_node() else { return Ok(None); };
            if symbol.unescaped() == key.as_bytes() {
                if found.is_some() { return Ok(None); }
                found = Some(pair.value());
            }
        }
    }
    Ok(found)
}

fn value(node: Node<'_>) -> Value {
    let kind = if constant(&node).is_some() { "constant_label" }
        else if node.as_string_node().is_some() || node.as_symbol_node().is_some() ||
            node.as_integer_node().is_some() || node.as_float_node().is_some() ||
            node.as_true_node().is_some() || node.as_false_node().is_some() || node.as_nil_node().is_some() { "literal_syntax" }
        else { "dynamic_unknown" };
    // Display is bounded independently of literal decoding and physical spans.
    let location = node.location();
    let raw = std::str::from_utf8(location.as_slice()).expect("validated UTF-8 source span");
    let mut end = raw.len().min(256);
    while !raw.is_char_boundary(end) { end -= 1; }
    json!({"kind":kind,"source":&raw[..end],"source_bytes":raw.len(),"truncated":end < raw.len()})
}

/// Annotation of an already validated captured class/module/method declaration.
/// Caller owns source/fact coordinate validation and aggregate capture admission.
/// No owner reconstruction: use the canonical capture declaration's identity.
pub(crate) fn analyze(declaration: &Value, content: &str) -> Result<Value> {
    let start = declaration["location"]["start_byte"].as_u64().and_then(|n| usize::try_from(n).ok())
        .ok_or_else(|| CoreError::input("Declaration start required"))?;
    let end = declaration["location"]["end_byte"].as_u64().and_then(|n| usize::try_from(n).ok())
        .ok_or_else(|| CoreError::input("Declaration end required"))?;
    let source = content.get(start..end).filter(|s| !s.is_empty() && s.len() <= MAX_BYTES)
        .ok_or_else(|| CoreError::limit("Job/mail declaration source unavailable or oversized"))?;
    let method = declaration["kind"] == "method";
    if !method && declaration["kind"] != "class" && declaration["kind"] != "module" {
        return Err(CoreError::input("Job/mail requires a captured declaration"));
    }
    let parsed = ruby_prism::parse(source.as_bytes());
    if parsed.errors().next().is_some() { return Ok(json!({"status":"unknown","reason":"syntax_error","rows":[]})); }
    let mut pending = vec![(parsed.node(), false)];
    let spans = Spans::new(content);
    let mut rows = Vec::new();
    let mut nodes = 0;
    let mut complete = true;
    while let Some((node, entered)) = pending.pop() {
        nodes += 1;
        if nodes > MAX_NODES || rows.len() == MAX_ROWS { complete = false; break; }
        if node.as_class_node().is_some() || node.as_module_node().is_some() || node.as_def_node().is_some() {
            if entered { continue; } // Nested declarations have their own canonical facts.
            if let Some(n) = node.as_class_node() { if let Some(body) = n.body() { pending.push((body, true)); } }
            if let Some(n) = node.as_module_node() { if let Some(body) = n.body() { pending.push((body, true)); } }
            if let Some(n) = node.as_def_node() { if let Some(body) = n.body() { pending.push((body, true)); } }
            continue;
        }
        if let Some(call) = node.as_call_node() {
            let name = text(call.name().as_slice());
            let here = spans.span(node.location(), start);
            if !method && call.receiver().is_none() && matches!(name.as_str(), "retry_on"|"discard_on"|"rescue_from") {
                let exceptions: Vec<_> = arguments(&call)?.into_iter().filter(|n| n.as_keyword_hash_node().is_none()).map(value).collect();
                let mut options = serde_json::Map::new();
                for key in ["wait","attempts","queue","priority","jitter","report","with"] {
                    options.insert(key.to_owned(),keyword(&call,key)?.map(value).unwrap_or(json!({"kind":"not_statically_available"})));
                }
                rows.push(json!({"kind":"policy_declaration","operation":name,"span":here,
                    "exceptions":exceptions,"options":options,
                    "handler":if call.block().is_some() {"opaque_block"} else {"not_stated"},
                    "option_defaults":"not_captured","other_options":"not_interpreted",
                    "provenance":"source_syntax","registration_match":"unknown","condition":"unknown"}));
                // The block is opaque: do not attribute nested DSL calls to class declarations.
                continue;
            }
            if method {
                if let Some(receiver) = call.receiver().and_then(|n| constant(&n)) {
                    rows.push(json!({"kind":"mailer_action_candidate","receiver":receiver,"action":name,
                        "span":here,"provenance":"source_potential","binding":"unknown",
                        "receiver_framework_role":"unknown","invocation":"unknown","delivery":"unknown","condition":"unknown"}));
                }
                if matches!(name.as_str(),"deliver_later"|"deliver_now") {
                    if rows.len() == MAX_ROWS { complete = false; break; }
                    rows.push(json!({"kind":"delivery_request_candidate","operation":name,"span":here,
                        "provenance":"source_potential","receiver_binding":"unknown","invocation":"unknown","delivery":"unknown","condition":"unknown"}));
                }
                if call.receiver().is_none() && matches!(name.as_str(), "mail"|"render") {
                    let selection = keyword(&call,"template_path")?;
                    let template = keyword(&call,"template_name")?.or(keyword(&call,"template")?);
                    let label = template.as_ref().and_then(literal_string);
                    let directory = selection.as_ref().and_then(literal_string);
                    let status = if label.as_ref().zip(directory.as_ref()).is_some_and(|(name,path)|
                        schema::path(name).is_ok() && schema::path(path).is_ok()) { "literal_candidate" }
                        else if label.is_some() { "unsupported_selection_unknown" }
                        else if template.is_some() || selection.is_some() { "dynamic_unknown" }
                        else { "unsupported_selection_unknown" };
                    rows.push(json!({"kind":"template_selection","operation":name,"span":here,
                        "template":label,"template_path":directory,"status":status,
                        "provenance":"source_potential","binding":"unknown"}));
                }
            }
        }
        children::for_each_child(&node, |child| pending.push((child, entered)));
    }
    rows.sort_by_key(|r| r["span"]["start_byte"].as_u64());
    let result = json!({"version":1,"status":if complete {"partial"} else {"bounded_partial"},
        "declaration_id":declaration["id"],"rows":rows,"nodes_visited":nodes,
        "scan_complete":complete,"registration_match":"unknown","execution":"unknown"});
    schema::encoded_bytes(&result, 128*1024)?;
    Ok(result)
}

pub(crate) fn walk<'a>(root: Node<'a>, mut visit: impl FnMut(&Node<'a>) -> Result<bool>) -> Result<(usize,bool)> {
    let mut pending = vec![root]; let mut count = 0;
    while let Some(node) = pending.pop() {
        count += 1;
        if count > MAX_NODES { return Ok((count-1,false)); }
        if !visit(&node)? { return Ok((count,false)); }
        children::for_each_child(&node, |child| pending.push(child));
    }
    Ok((count,true))
}
