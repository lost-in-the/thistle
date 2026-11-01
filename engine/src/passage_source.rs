//! Narrow selected-action syntax, parsed only on the shared guarded worker.
use crate::{error::{CoreError, Result}, job_mail_source::{self as syntax, Spans}, schema};
use serde_json::{json,Value};
use ruby_prism::Node;
#[path="capture_children.rs"]
mod children;

#[derive(Clone,Copy)]
struct Branch { kind:&'static str, span:[u64;4] }
fn branch_kind(node:&Node<'_>)->Option<&'static str> {
    match node {
        Node::IfNode{..}=>Some("if"),Node::UnlessNode{..}=>Some("unless"),
        Node::CaseNode{..}|Node::CaseMatchNode{..}=>Some("case"),
        Node::WhenNode{..}=>Some("when"),Node::InNode{..}=>Some("in"),
        Node::AndNode{..}=>Some("and"),Node::OrNode{..}=>Some("or"),
        Node::WhileNode{..}=>Some("while"),Node::UntilNode{..}=>Some("until"),Node::ForNode{..}=>Some("for"),
        Node::RescueNode{..}|Node::RescueModifierNode{..}=>Some("rescue"),Node::EnsureNode{..}=>Some("ensure"),
        Node::BeginNode{..} if node.as_begin_node().unwrap().rescue_clause().is_some()=>Some("begin_rescue"),_=>None,
    }
}
pub(super) fn unknown(reason:&str)->Value {
    json!({"status":"unknown","reason":reason,"rows":[],"scan_complete":false,"unsearched":"selected_action_source_not_scanned"})
}
fn enclose(row:&mut Value,branch:Option<Branch>) {
    row["condition"]=json!(if branch.is_some(){"inside_branch_syntax"}else{"no_enclosing_branch_syntax"});
    if let Some(Branch{kind,span:[start_byte,end_byte,start_line,end_line]})=branch {
        row["branch"]=json!({"kind":kind,"span":{"start_byte":start_byte,"end_byte":end_byte,"start_line":start_line,"end_line":end_line}});
    }
}

pub(crate) fn analyze(declaration: &Value, content: &str) -> Result<Value> {
    let start=declaration["location"]["start_byte"].as_u64().ok_or_else(||CoreError::input("Action span required"))? as usize;
    let end=declaration["location"]["end_byte"].as_u64().ok_or_else(||CoreError::input("Action span required"))? as usize;
    let source=content.get(start..end).filter(|s|!s.is_empty()).ok_or_else(||CoreError::snapshot("Invalid selected action span"))?;
    if source.len()>syntax::MAX_BYTES {return Ok(unknown("selected_declaration_exceeds_source_allowance"));}
    let parsed=ruby_prism::parse(source.as_bytes());
    if parsed.errors().next().is_some() { return Ok(unknown("syntax_error")); }
    let spans=Spans::new(content);
    let mut pending=vec![(parsed.node(),false,None)];
    let mut rows=Vec::new(); let mut nodes=0; let mut complete=true;
    let mut stop=None;
    while let Some((node,entered,mut branch))=pending.pop() {
        if nodes==20_000 || rows.len()==200 {complete=false;stop=Some(spans.span(node.location(),start));break;}
        nodes+=1;
        if let Some(def)=node.as_def_node() {
            if !entered { if let Some(body)=def.body() { pending.push((body,true,branch)); } }
            // Parameters/default expressions are deliberately outside the body.
            continue;
        }
        if node.as_class_node().is_some() || node.as_module_node().is_some() || node.as_lambda_node().is_some() || node.as_block_node().is_some() {
            // Unknown binding/later block execution is a stop, not inline flow.
            let mut row=json!({"kind":"boundary","operation":"nested_scope","span":spans.span(node.location(),start),
                "reason":"Nested declaration, block or lambda body not scanned; whether, when and how often it runs is unknown"});
            enclose(&mut row,branch);rows.push(row);
            continue;
        }
        if let Some(kind)=branch_kind(&node) {
            let span=spans.span(node.location(),start);
            branch=Some(Branch{kind,span:[span["start_byte"].as_u64().unwrap(),span["end_byte"].as_u64().unwrap(),span["start_line"].as_u64().unwrap(),span["end_line"].as_u64().unwrap()]});
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
            let mut row=json!({"kind":kind,"operation":name,"receiver":receiver,"span":spans.span(location,start),
                "syntax":&raw[..cut],"syntax_truncated":cut<raw.len(),"reason":reason});
            enclose(&mut row,branch);rows.push(row);
            // Traverse arguments and receivers as separate syntax witnesses, never
            // interpret a chain as a bound call graph. Explicit blocks stop above.
        }
        let mut next=Vec::new();
        children::for_each_child(&node,|child|next.push(child));
        // Schema order can differ for modifier conditions. Sort physical starts,
        // then reverse LIFO pushes so a bounded scan retains a lexical prefix.
        next.sort_by_key(|child|child.location().start_offset());
        for child in next.into_iter().rev() {pending.push((child,entered,branch));}
    }
    rows.sort_by_key(|row|row["span"]["start_byte"].as_u64());
    let mut result=json!({"status":if complete {"selected_body_syntax"} else {"bounded_partial"},
        "rows":rows,"scan_complete":complete,"nodes_visited":nodes,
        "ordering":"Lexical source order only; branch/condition satisfaction and runtime order unknown"});
    if !complete {
        result["unsearched"]=json!("remaining_node_or_row_work");
        result["unsearched_from_byte"]=stop.as_ref().unwrap()["start_byte"].clone();
        result["stop_region"]=stop.unwrap();
    }
    if let Err(error)=schema::encoded_bytes(&result,256*1024) {
        if error.code=="limit_exceeded" {return Ok(unknown("analysis_result_exceeds_allowance"));}
        return Err(error);
    }
    Ok(result)
}
