//! One route + explicit action, potential inspection sequence, never a trace.
use crate::{error::{CoreError,Result},schema,store::Reader,route_actions,method_lookup,recorded_domain,
    model_brief::RequestWork,callback_effects,controller_filters};
use serde_json::{json,Value};
use std::cmp::Ordering;
#[path="passage_source.rs"]
mod source;

const SEMANTICS: &str="Selected-action evidence only. Registry order, lexical source order and unknown runtime order are distinct. Conditions, constant/model identity, binding, source/runtime coherence, invocation, persistence, job execution and delivery remain unknown. Stop at helper/association/async/binding boundaries. This is a potential inspection sequence, never an execution trace or INSERT claim.";
pub(crate) struct Query<'a> { id:&'a str, action:Option<&'a str>, family:&'a str, limit:usize, cursor:Option<&'a Value>, max_bytes:usize }
impl<'a> Query<'a> {
    pub(crate) fn parse(request:&'a Value)->Result<Self> {
        let number=|key:&str,default:usize,max:usize|->Result<usize>{
            request.get(key).map_or(Some(default as u64),Value::as_u64).filter(|n|*n>0 && *n<=max as u64)
                .map(|n|n as usize).ok_or_else(||CoreError::input(format!("Invalid passage {key}")))
        };
        let action=match request.get("action") {None|Some(Value::Null)=>None,Some(value)=>Some(schema::hash(value.as_str().ok_or_else(||CoreError::input("Action ID required"))?)?)};
        let family=request.get("family").filter(|v|!v.is_null()).map_or(Some("sequence"),Value::as_str)
            .filter(|s|matches!(*s,"sequence"|"export")).ok_or_else(||CoreError::input("Invalid passage family"))?;
        Ok(Self{id:schema::hash(schema::string(request,"id")?)?,action,family,limit:number("limit",8,16)?,cursor:request.get("cursor"),max_bytes:number("max_bytes",32768,65536)?})
    }
    pub(crate) fn scratch(&self)->usize {96*1024*1024}
}

struct Work { shared:RequestWork, visits:usize, comparisons:usize, bytes:usize, directories:Vec<Value> }
impl Work {
    fn new()->Self {Self{shared:RequestWork::default(),visits:0,comparisons:0,bytes:0,directories:Vec::new()}}
    fn metadata(&mut self,value:&impl serde::Serialize)->Result<()> {self.shared.metadata(value,3)?;Ok(())}
    fn charge_route(&mut self,route:&Value)->Result<()> {
        let visits=route["usage"]["candidate_visits"].as_u64().unwrap_or(0) as usize;
        let comparisons=route["usage"]["comparisons"].as_u64().unwrap_or(0) as usize;
        let bytes=route["usage"]["label_bytes"].as_u64().unwrap_or(0) as usize;
        if !self.shared.facts(visits) || !self.shared.label_bytes(bytes) {return Err(CoreError::limit("Passage route work allowance"));}
        for _ in 0..comparisons {if !self.shared.labels(0) {return Err(CoreError::limit("Passage comparison allowance"));}}
        self.visits+=visits;self.comparisons+=comparisons;self.bytes+=bytes;
        self.metadata(route)
    }
    fn unique<'r>(&mut self,reader:&'r Reader,name:&str,kind:&str)->Result<(Option<&'r Value>,usize)> {
        let (page,cost)=reader.recorded_candidates(name,Some(kind),0,1,self)?;
        self.directories.push(cost);
        Ok((if page.total==1 {page.positions.first().map(|i|&reader.facts[*i])} else {None},page.total))
    }
}
impl method_lookup::Work for Work {
    fn visit(&mut self)->bool {if !self.shared.facts(1){return false;}self.visits+=1;true}
    fn bytes(&mut self,n:usize)->bool {if !self.shared.label_bytes(n){return false;}self.bytes+=n;true}
    fn compare(&mut self,a:&str,b:&str)->Option<Ordering> {if !self.shared.labels(a.len()+b.len()){return None;}self.comparisons+=1;self.bytes+=a.len()+b.len();Some(a.cmp(b))}
    fn compare_digest(&mut self,a:&[u8;32],b:&[u8;32])->Option<Ordering> {if !self.shared.labels(64){return None;}self.comparisons+=1;self.bytes+=64;Some(a.cmp(b))}
}
impl recorded_domain::LabelWork for Work {
    fn compare(&mut self,a:&str,b:&str)->Result<Ordering> {method_lookup::Work::compare(self,a,b).ok_or_else(||CoreError::limit("Passage shared label allowance"))}
}
fn identity(fact:&Value,generation:&str,work:&mut Work)->Result<Value> {
    let mut out=serde_json::Map::new();
    for field in ["id","kind","name","evidence","path"] {work.metadata(&fact[field])?;out.insert(field.into(),fact[field].clone());}
    work.metadata(&fact["location"])?;
    out.insert("span".into(),fact["location"].clone());out.insert("generation".into(),json!(generation));Ok(Value::Object(out))
}
fn filter_row(reader:&Reader,entry:&Value,position:usize,registry:&Value,action:&str,work:&mut Work)->Result<Value> {
    schema::encoded_bytes(entry,16*1024)?;
    work.metadata(entry)?;
    // Charge action applicability comparisons too, including rejected rows.
    for field in ["if","unless"] {
        if let Some(conditions)=entry[field].as_array() {
            for condition in conditions {
                if !work.shared.facts(1) {return Err(CoreError::limit("Passage filter condition allowance"));}
                if let Some(names)=condition["actions"].as_array() {
                    for name in names {
                        if !work.shared.labels(action.len()+name.as_str().unwrap_or("").len()) {return Err(CoreError::limit("Passage filter action label allowance"));}
                    }
                }
            }
        }
    }
    let mut witness=Value::Null;
    let descriptor=&entry["filter"];
    if let (Some(owner),Some(name))=(descriptor["owner"].as_str(),descriptor["name"].as_str()) {
        let (found,cost)=reader.with_method_directory(crate::query::budget(),|directory,built| (directory.lookup(&reader.facts,owner,name,work),directory.stats(built).value()))?;
        work.directories.push(cost);
        if found.decided && found.matches==1 {
            if let Some(index)=found.candidate {
                let fact=&reader.facts[index];
                if descriptor["source"]["path"].is_string() && fact["path"]==descriptor["source"]["path"] &&
                    fact["location"]["start_line"]==descriptor["source"]["line"] {
                    witness=identity(fact,&reader.generation,work)?;
                }
            }
        }
    }
    Ok(json!({"kind":"controller_filter","ordinal":position,"registry_id":registry["id"],"registration":entry,
        "applicability":controller_filters::applicability(entry,action),"witness":witness,
        "order":"Framework registry position only; around/after execution chronology unknown","binding":"unknown"}))
}
const CALLBACK_SUMMARIES:usize=4;
fn compact_conditions(values:&Value,work:&mut Work)->Result<Value> {
    let Some(values)=values.as_array() else {return Ok(json!({"status":"unavailable","evaluation":"unknown"}));};
    let mut kinds=serde_json::Map::new();
    for value in values {
        let kind=value["kind"].as_str().unwrap_or("unavailable");
        if !work.shared.labels(kind.len()) {return Err(CoreError::limit("Passage condition summary allowance"));}
        let count=kinds.get(kind).and_then(Value::as_u64).unwrap_or(0)+1;
        kinds.insert(kind.into(),json!(count));
    }
    Ok(json!({"status":"recorded","count":values.len(),"kinds":kinds,"evaluation":"unknown"}))
}
fn callback_contribution(reader:&Reader,registry:&Value,answer:&Value,work:&mut Work)->Result<Value> {
    let callbacks=schema::array(answer,"callbacks")?;
    let mut summaries=Vec::new();
    for callback in callbacks.iter().take(CALLBACK_SUMMARIES) {
        work.metadata(callback)?;
        let explanation=&callback["explanation"];
        let mut witness=Value::Null;
        if explanation["binding"]=="descriptor_matched_captured_declaration" {
            if let Some(id)=explanation["method"]["id"].as_str() {
                if !work.shared.facts(1) {return Err(CoreError::limit("Passage callback projection allowance"));}
                witness=identity(reader.stored_fact(id)?,&reader.generation,work)?;
            }
        }
        let mut filter=serde_json::Map::new();
        for key in ["kind","name","owner"] {
            if let Some(value)=callback["filter"].get(key) {work.metadata(value)?;filter.insert(key.into(),value.clone());}
        }
        let mut effects=json!({"returned_count":explanation["effects"].as_array().map_or(0,Vec::len),
            "unit":"representative_potential_perform_later_call_groups",
            "search_complete":explanation["links_search_complete"]==true,"details":"not_projected","non_exhaustive":true});
        if let Some(omitted)=explanation.get("known_effects_omitted") {effects["known_omitted"]=omitted.clone();}
        summaries.push(json!({"callback_id":callback["callback_id"],"registry_id":callback["registry_id"],
            "position":callback["position"],"kind":callback["kind"],"filter":filter,"inherited":callback["inherited"],
            "registry_provenance":callback["registry_provenance"],"conditions":{"if":compact_conditions(&callback["if"],work)?,"unless":compact_conditions(&callback["unless"],work)?},
            "binding":explanation["binding"],"status":explanation["status"],"reason":explanation["reason"],"witness":witness,"effects":effects}));
    }
    let mut coverage=serde_json::Map::new();
    for key in ["capture_partial_or_unknown","declaration_scan_complete","candidate_ranges_complete","rows_attempted","rows_not_searched",
        "rows_metadata_omitted","rows_output_omitted","source_rows_not_searched","truncated","facts_visited","links_visited",
        "compared_label_bytes","source_files_attempted","source_bytes_charged"] {
        let value=&answer["coverage"][key];work.metadata(value)?;coverage.insert(key.into(),value.clone());
    }
    Ok(json!({"status":"potential_save_callback_contribution","model_binding":"unknown",
        "registry":identity(registry,&reader.generation,work)?,"registry_status":answer["registry_status"],
        "callbacks":summaries,"component_callbacks_returned":callbacks.len(),"summaries_omitted":callbacks.len().saturating_sub(CALLBACK_SUMMARIES),
        "summary_limit":CALLBACK_SUMMARIES,"coverage":coverage,
        "effect_absence":"No supported match does not prove that no effect is possible.",
        "scope":"Compact registered callback/source summaries only; effect bodies not projected. Source on this registry exposes existing full callback evidence. Conditions, model identity and execution remain unknown."}))
}
fn operation_row(reader:&Reader,operation:&Value,ordinal:usize,action:&Value,work:&mut Work)->Result<Value> {
    work.metadata(operation)?;
    let mut row=json!({"kind":"source_operation","ordinal":ordinal,"evidence":operation,
        "witness":identity(action,&reader.generation,work)?,"binding":"unknown"});
    if operation["kind"]=="save_operation" {
        let label=operation["receiver"].as_str().and_then(|s|s.strip_prefix("::")).unwrap_or("");
        let (model,matches)=work.unique(reader,label,"rails_model")?;
        row["model_candidates"]=json!(matches);
        row["save_contribution"]=json!({"status":"qualified_target_unavailable","reason":"Supported selected-action operation exists, but unique recorded model and callback registry label witnesses are required"});
        if let Some(model)=model {
            row["model"]=identity(model,&reader.generation,work)?;
            let (registry,matches)=work.unique(reader,label,"rails_save_callbacks")?;
            row["callback_registry_candidates"]=json!(matches);
            if let Some(registry)=registry {
                let request=json!({"id":registry["id"],"limit":CALLBACK_SUMMARIES});
                let answer=callback_effects::select_scoped(reader,&callback_effects::Query::parse(&request)?,crate::query::budget(),Some(&mut work.shared))?;
                // The unchanged component charges all its work before projection;
                // copying compact summaries never refunds discarded effect bodies.
                row["save_contribution"]=callback_contribution(reader,registry,&answer,work)?;
            }
        }
    } else if matches!(operation["kind"].as_str(),Some("async_boundary"|"constant_call_boundary")) {
        let receiver=operation["receiver"].as_str().and_then(|s|s.strip_prefix("::")).unwrap_or("");
        let target=if operation["kind"]=="async_boundary" {format!("{receiver}#perform")} else {format!("{receiver}#{}",operation["operation"].as_str().unwrap_or(""))};
        let (candidate,matches)=work.unique(reader,&target,"method")?;
        row["candidate_matches"]=json!(matches);
        row["receiver_framework_role"]=json!("unknown");
        if let Some(candidate)=candidate {
            row["related_candidate"]=identity(candidate,&reader.generation,work)?;
            row["followup"]=json!({"operation":"job_mail","generation":reader.generation,"id":candidate["id"],"family":"handoff"});
        }
        row["boundary"]=json!("Stop here. Related saved method syntax is a label candidate, not a continuous invocation pathway.");
    }
    Ok(row)
}
fn source_analysis(reader:&Reader,action:&Value,work:&mut Work)->Result<Value> {
    if action["path"].is_null() {return Ok(source::unknown("saved_action_has_no_physical_source"));}
    let path=schema::string(action,"path")?;
    if action["location"].is_null() {return Ok(source::unknown("saved_action_has_no_physical_source"));}
    let files=schema::array(&reader.manifest,"files")?;
    let mut found=None;
    for file in files {
        let label=schema::string(file,"path")?;
        let order=method_lookup::Work::compare(work,path,label).ok_or_else(||CoreError::limit("Passage file inventory comparison allowance"))?;
        if order==Ordering::Equal {found=Some(file);break;}
    }
    let file=found.ok_or_else(||CoreError::snapshot("Missing action source metadata"))?;
    let source_bytes=file["bytes"].as_u64().ok_or_else(||CoreError::snapshot("Invalid action source size"))?;
    if source_bytes>262144 {return Ok(source::unknown("saved_file_exceeds_source_allowance"));}
    if !work.shared.source_attempt() || !work.shared.source_bytes(source_bytes as usize) {return Err(CoreError::limit("Passage shared source allowance"));}
    let links=schema::array(action,"links")?.len();
    if !work.shared.facts(1) || !work.shared.links(links) {return Err(CoreError::limit("Passage source validation allowance"));}
    let mut saved=reader.source(schema::string(action,"id")?)?;
    let content=match saved["content"].take() {Value::String(content)=>content,_=>return Err(CoreError::snapshot("Missing saved action source"))};
    drop(saved);
    let declaration=json!({"kind":action["kind"],"location":action["location"]});
    // Busy, shared worker admission, unsafe storage and invalid snapshot errors
    // propagate. Only local analyzer size outcomes become source-unknown DTOs.
    crate::capture::parser_worker("thistle-passage",move||source::analyze(&declaration,&content))
}
#[derive(serde::Serialize)]
struct Envelope<'a>{ok:bool,result:&'a Value}
pub(crate) fn select(reader:&Reader,query:&Query<'_>)->Result<Value> {
    select_with_work(reader,query,Work::new())
}
fn select_with_work(reader:&Reader,query:&Query<'_>,mut work:Work)->Result<Value> {
    let scope=json!(["passage",query.id,query.action,query.family]);
    let (offset,secondary)=recorded_domain::position(query.cursor,&reader.generation,&scope)?;
    if secondary!=0 {return Err(CoreError::input("Invalid passage continuation position"));}
    let mut request=json!({"id":query.id,"limit":if query.action.is_some(){1}else{query.limit},
        "max_bytes":query.max_bytes.saturating_sub(4096).clamp(1,32768)});
    if query.action.is_none() && offset!=0 {
        request["cursor"]=recorded_domain::cursor(&reader.generation,&json!(["route_actions",query.id]),(offset,0))?;
    }
    let mut route=route_actions::select(reader,&route_actions::Query::parse(&request)?)?;
    work.charge_route(&route)?;
    let root=route["root"].take();
    let mut result=json!({"version":1,"generation":reader.generation,"root":root,"selected_action":null,
        "family":query.family,"selection_status":"choose_saved_action","route":route,"items":[],"offset":offset,
        "coverage":{"page_complete":true,"execution":"unavailable"},"next_cursor":null,"continuation":null,"semantics":SEMANTICS});
    let mut total=0;
    if let Some(id)=query.action {
        let action=reader.stored_fact(id)?;
        schema::encoded_bytes(action,512*1024)?;
        work.metadata(action)?;
        let labels=method_lookup::key(action);
        let expected=result["route"]["naming"]["owner"].as_str().zip(result["route"]["naming"]["action"].as_str());
        if labels.is_none() || labels!=expected || result["route"]["naming"]["status"]!="conventional_labels_only" {
            return Err(CoreError::input("Selected action is not a qualified candidate for this saved route"));
        }
        result["selected_action"]=identity(action,&reader.generation,&mut work)?;
        result["selection_status"]=json!("selected_syntax_binding_unknown");
        let owner=labels.unwrap().0;let action_name=labels.unwrap().1;
        let (registry,registry_count)=work.unique(reader,owner,"rails_controller_filters")?;
        let filter_status=if registry_count==0 {"not_captured"}else if registry_count>1 {"ambiguous_registry_candidates"}
            else if registry.unwrap()["attributes"]["controller_filters"]["controller"]["status"]=="observed" {"captured"}else{"unavailable"};
        result["filters"]=json!({"registry_candidates":registry_count,"status":filter_status,"binding":"unknown"});
        let filters=registry.and_then(|f|f["attributes"]["controller_filters"]["controller"]["entries"].as_array());
        let filter_count=filters.map_or(0,Vec::len);
        let analysis=source_analysis(reader,action,&mut work)?;
        work.metadata(&analysis)?;
        let operations=schema::array(&analysis,"rows")?;
        total=filter_count+operations.len();
        if offset>total {return Err(CoreError::input("Passage continuation outside selected evidence"));}
        result["coverage"]["source_scan_complete"]=analysis["scan_complete"].clone();
        result["coverage"]["analysis_status"]=analysis["status"].clone();
        if let Some(value)=analysis.get("reason") {result["coverage"]["reason"]=value.clone();}
        if let Some(value)=analysis.get("unsearched") {result["coverage"]["unsearched"]=value.clone();}
        for field in ["unsearched_from_byte","stop_region"] {if let Some(value)=analysis.get(field) {result["coverage"][field]=value.clone();}}
        let mut items=Vec::new();
        for index in offset..total.min(offset.saturating_add(query.limit)) {
            let row=if index<filter_count {filter_row(reader,&filters.unwrap()[index],index,registry.unwrap(),action_name,&mut work)?}
                else {operation_row(reader,&operations[index-filter_count],index,action,&mut work)?};
            work.metadata(&row)?;items.push(row);
        }
        result["items"]=json!(items);
    }
    // No full-fact fallback or source bodies in the DTO. Export is generated from
    // the identical typed items on this page; the same cursor preserves meaning.
    loop {
        let count=if query.action.is_some() {result["items"].as_array().unwrap().len()} else {result["route"]["candidates"].as_array().unwrap().len()};
        let complete=if query.action.is_some() {offset+count==total} else {result["route"]["coverage"]["page_complete"]==true};
        result["coverage"]["page_complete"]=json!(complete);
        if !complete {
            if count==0 {return Err(CoreError::limit("Passage page made no progress"));}
            let cursor=recorded_domain::cursor(&reader.generation,&scope,(offset+count,0))?;
            result["next_cursor"]=cursor.clone();
            result["continuation"]=json!({"operation":"passage","generation":reader.generation,"id":query.id,"action":query.action,"family":query.family,"cursor":cursor});
        }
        result["usage"]=json!({"selection_fact_visits":work.visits,"selection_comparisons":work.comparisons,"selection_label_bytes":work.bytes,
            "directories":work.directories,"reader_open":reader.method_lookup_baseline(),"scratch_reservation":query.scratch(),
            "scope":"All route work is charged before subsequent shared RequestWork selection. Callback usage is additionally shown in each contribution. Source, parsing, filtering and prefix projection repeat and are charged per page. No CPU/RSS/latency claim."});
        if query.family=="export" {result["report"]=json!(format!("{}\nGeneration: {}\nSelected action: {}\n{}\n",SEMANTICS,reader.generation,query.action.unwrap_or("none"),serde_json::to_string(&result["items"])?));}
        match schema::encoded_bytes(&Envelope{ok:true,result:&result},query.max_bytes.saturating_sub(1)) {
            Ok(_)=>{work.metadata(&result)?;return Ok(result);},
            Err(error)=>{
                let items=result["items"].as_array_mut().unwrap();
                if items.len()<=1 {return Err(error);}items.pop();
            }
        }
    }
}

#[cfg(test)]
#[path="passage_tests.rs"]
mod tests;
