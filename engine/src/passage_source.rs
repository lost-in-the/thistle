//! Narrow selected-action syntax, parsed only on the shared guarded worker.
use crate::{error::{CoreError, Result}, job_mail_source::{self as syntax, Spans}, schema};
use serde_json::{json,Value};
#[path="capture_children.rs"]
mod children;

pub(crate) fn analyze(declaration: &Value, content: &str) -> Result<Value> {
    let start=declaration["location"]["start_byte"].as_u64().ok_or_else(||CoreError::input("Action span required"))? as usize;
    let end=declaration["location"]["end_byte"].as_u64().ok_or_else(||CoreError::input("Action span required"))? as usize;
    let source=content.get(start..end).filter(|s| !s.is_empty() && s.len()<=syntax::MAX_BYTES)
        .ok_or_else(||CoreError::limit("Passage declaration unavailable or oversized"))?;
    let parsed=ruby_prism::parse(source.as_bytes());
    if parsed.errors().next().is_some() { return Ok(json!({"status":"unknown","reason":"syntax_error","rows":[],"scan_complete":false})); }
    let spans=Spans::new(content);
    let mut pending=vec![(parsed.node(),false)];
    let mut rows=Vec::new(); let mut nodes=0; let mut complete=true;
    while let Some((node,entered))=pending.pop() {
        nodes+=1;
        if nodes>20_000 || rows.len()==200 { complete=false; break; }
        if let Some(def)=node.as_def_node() {
            if !entered { if let Some(body)=def.body() { pending.push((body,true)); } }
            // Parameters/default expressions are deliberately outside the body.
            continue;
        }
        if node.as_class_node().is_some() || node.as_module_node().is_some() || node.as_lambda_node().is_some() || node.as_block_node().is_some() {
            // Unknown binding/later block execution is a stop, not inline flow.
            rows.push(json!({"kind":"boundary","operation":"nested_scope","span":spans.span(node.location(),start),
                "reason":"Nested declaration/block/lambda is not selected-action execution","condition":"unknown"}));
            continue;
        }
        if let Some(call)=node.as_call_node() {
            let name=syntax::text(call.name().as_slice());
            let receiver=call.receiver().and_then(|n|syntax::constant(&n));
            let rooted=receiver.as_deref().filter(|s| s.starts_with("::"));
            let (kind,reason)=if rooted.is_some() && !call.is_safe_navigation() && call.block().is_none() && matches!(name.as_str(),"create"|"create!") {
                ("save_operation","Direct root-qualified create syntax; model identity, dispatch, validation and outcome unknown")
            } else if rooted.is_some() && !call.is_safe_navigation() && call.block().is_none() && name=="perform_later" {
                ("async_boundary","Potential asynchronous request only; stop before invocation or job execution")
            } else if matches!(name.as_str(),"deliver_later"|"deliver_now") {
                ("mail_boundary","Potential delivery request; receiver chain/binding and delivery unknown")
            } else if rooted.is_some() {
                ("constant_call_boundary","Root-qualified call label only; no helper/model/job binding inferred")
            } else {
                ("boundary","Unsupported helper, alias, association, relative constant or receiver chain; no inferred save")
            };
            let location=node.location();
            let raw=std::str::from_utf8(location.as_slice()).map_err(|_|CoreError::input("Invalid selected source UTF-8"))?;
            let mut cut=raw.len().min(256); while !raw.is_char_boundary(cut) { cut-=1; }
            rows.push(json!({"kind":kind,"operation":name,"receiver":receiver,"span":spans.span(location,start),
                "syntax":&raw[..cut],"syntax_truncated":cut<raw.len(),"reason":reason,"condition":"unknown"}));
            // Traverse arguments and receivers as separate syntax witnesses, never
            // interpret a chain as a bound call graph. Explicit blocks stop above.
        }
        children::for_each_child(&node,|child|pending.push((child,entered)));
    }
    rows.sort_by_key(|row|row["span"]["start_byte"].as_u64());
    let mut result=json!({"status":if complete {"selected_body_syntax"} else {"bounded_partial"},
        "rows":rows,"scan_complete":complete,"nodes_visited":nodes,
        "ordering":"Lexical source order only; branch/condition satisfaction and runtime order unknown"});
    if !complete { result["unsearched"]=json!("remaining_node_or_row_work"); }
    schema::encoded_bytes(&result,256*1024)?;
    Ok(result)
}
