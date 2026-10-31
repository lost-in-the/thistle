//! LOS-148 registration admission and bounded public saved-evidence answers.
//! Shared dispatcher/schema/capture/Reader wiring is deliberately Root-owned.
use crate::{error::{CoreError, Result}, schema, store::Reader, recorded_domain};
use serde_json::{json, Value};
use std::{cmp::Ordering, path::Path};

const SEMANTICS: &str = "Framework registrations, source declarations, call-site candidates and execution are separate. Registered positions are not execution chronology. Retry/discard options are source syntax, never recovered from opaque handlers. Constant binding, condition satisfaction, runtime dispatch, invocation and delivery are unknown. ERB source is never evaluated.";

fn handler(value: &Value, normalized: bool) -> Result<()> {
    match value["kind"].as_str() {
        Some("opaque") => return schema::model_object(value, &["kind"]),
        Some("method") => {
            schema::model_object(value, &["kind","name","owner","source"])?;
            schema::string(value,"name")?;
            schema::model_label(&value["name"])?;
            schema::model_label(&value["owner"])?;
        },
        Some("proc") => schema::model_object(value, &["kind","source"] )?,
        _ => return Err(CoreError::input("Invalid job/mail handler")),
    }
    if !value["source"].is_null() {
        schema::model_object(&value["source"], &["path","line"])?;
        let path = schema::string(&value["source"],"path")?;
        schema::model_label(&value["source"]["path"])?;
        if normalized { schema::path(path)?; }
        if !value["source"]["line"].as_u64().is_some_and(|n| n > 0 && n <= u32::MAX as u64) {
            return Err(CoreError::input("Invalid handler source hint"));
        }
    }
    Ok(())
}

fn class(value: &Value, normalized: bool) -> Result<usize> {
    schema::model_object(value, &["kind","name","superclass","rescue_handlers"])?;
    if !matches!(value["kind"].as_str(),Some("job"|"mailer")) { return Err(CoreError::input("Invalid job/mail role")); }
    schema::model_label(&value["name"])?;
    schema::model_label(&value["superclass"])?;
    let family = &value["rescue_handlers"];
    schema::model_object(family, &["status","entries"])?;
    let entries = schema::array(family,"entries")?;
    if entries.len() > 100_000 { return Err(CoreError::limit("Job/mail registry entry limit")); }
    if !matches!(family["status"].as_str(),Some("observed"|"unavailable")) || family["status"] == "unavailable" && !entries.is_empty() {
        return Err(CoreError::input("Invalid registry coverage"));
    }
    for entry in entries {
        schema::model_object(entry, &["exception","handler","shared_with_superclass"])?;
        schema::model_label(&entry["exception"])?;
        if !(entry["shared_with_superclass"].is_null() || entry["shared_with_superclass"].is_boolean()) {
            return Err(CoreError::input("Invalid registry inheritance evidence"));
        }
        handler(&entry["handler"],normalized)?;
    }
    Ok(entries.len())
}

fn registration_identity(data: &Value) -> Result<(String,String)> {
    let name = data["class"]["name"].as_str().map(str::to_owned)
        .unwrap_or_else(|| format!("Anonymous {} {}",data["class"]["kind"].as_str().unwrap_or("class"),data["ordinal"]));
    Ok((schema::digest(&schema::canonical(&json!(["rails_job_mail",1,data["ordinal"],data["class"]["kind"],data["class"]["name"]]))?),name))
}

fn normalize_source(reference: &mut Value, root: &str) {
    if reference.get("source").is_none_or(Value::is_null) { return; }
    let normalized = reference["source"]["path"].as_str().and_then(|text| {
        let path = Path::new(text);
        if !Path::new(root).is_absolute() || !path.is_absolute() || path.components().any(|c| matches!(c,std::path::Component::CurDir|std::path::Component::ParentDir)) { return None; }
        let relative = path.strip_prefix(root).ok()?.to_str()?;
        schema::path(relative).ok().map(str::to_owned)
    });
    if let Some(path) = normalized { reference["source"]["path"] = json!(path); }
    else { reference["source"] = Value::Null; }
}

pub(crate) fn batch(context: &Value, observation: &Value) -> Result<Value> {
    schema::depth(observation)?;
    schema::model_object(observation, &["version","framework_version","root","boundary","status","classes"])?;
    schema::model_label(&observation["framework_version"])?;
    let root = schema::string(observation,"root")?;
    let classes = schema::array(observation,"classes")?;
    if observation["version"] != 1 || observation["boundary"] != "explicit_loaded_app" ||
        !matches!(observation["status"].as_str(),Some("observed"|"unavailable")) ||
        observation["status"] == "unavailable" && !classes.is_empty() ||
        observation["status"] == "observed" && !matches!(observation["framework_version"].as_str(),Some("7.1.6"|"8.1.4")) {
        return Err(CoreError::input("Invalid job/mail observation provenance"));
    }
    schema::encoded_bytes(observation,schema::MAX_FACTS_BYTES)?;
    let mut admission = schema::ObservationAdmission::new(context)?;
    admission.ensure_facts(classes.len())?;
    let mut facts = Vec::with_capacity(classes.len());
    for (ordinal,observed) in classes.iter().enumerate() {
        let count = class(observed,false)?;
        let mut observed = observed.clone();
        for entry in observed["rescue_handlers"]["entries"].as_array_mut().unwrap() {
            normalize_source(&mut entry["handler"],root);
        }
        let data = json!({"version":1,"ordinal":ordinal,"framework_version":observation["framework_version"],
            "boundary":"explicit_loaded_app","coherence":"unknown","class":observed});
        let (id,name) = registration_identity(&data)?;
        let fact = json!({"id":id,"kind":"rails_job_mail","name":name,"path":null,"location":null,
            "evidence":"runtime","attributes":{"job_mail":data},"links":[]});
        validate_fact(&fact)?;
        admission.admit(&fact,count + 1)?;
        facts.push(fact);
    }
    Ok(json!({"facts":facts,"appended":admission.appended(),"coverage":[
        {"family":"rails_job_mail","status":if observation["status"] == "observed" {"partial"} else {"unavailable"},
        "scope":"Explicit supplied loaded jobs and mailers; guarded rescue registry only",
        "reason":"Registry order and shared superclass rows observed; retry/discard semantics require separate source evidence. No execution or loaded-code coherence proof."},
        {"family":"job_mail_execution","status":"unavailable","scope":"Job/handler/mailer/template execution and delivery","reason":"Never invoked"}],
        "job_mail_observer":{"version":1,"framework_version":observation["framework_version"],"boundary":"explicit_loaded_app"}}))
}

pub(crate) fn validate_fact(fact: &Value) -> Result<()> {
    schema::model_object(&fact["attributes"], &["job_mail"])?;
    let data = &fact["attributes"]["job_mail"];
    schema::model_object(data, &["version","ordinal","framework_version","boundary","coherence","class"])?;
    if data["version"] != 1 || data["ordinal"].as_u64().is_none() ||
        !matches!(data["framework_version"].as_str(),Some("7.1.6"|"8.1.4")) || data["boundary"] != "explicit_loaded_app" ||
        data["coherence"] != "unknown" || fact["evidence"] != "runtime" || fact["kind"] != "rails_job_mail" ||
        !fact["path"].is_null() || !fact["location"].is_null() || fact["links"] != json!([]) {
        return Err(CoreError::input("Invalid job/mail saved provenance"));
    }
    class(&data["class"],true)?;
    let (id,name) = registration_identity(data)?;
    if fact["id"] != id || fact["name"] != name { return Err(CoreError::input("Invalid job/mail identity")); }
    Ok(())
}

pub(crate) struct Query<'a> { id: &'a str, family: &'a str, limit: usize, cursor: Option<&'a Value>, max_bytes: usize }
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let id = schema::hash(schema::string(request,"id")?)?;
        let limit = request.get("limit").map_or(Some(8),Value::as_u64)
            .filter(|n| (1..=16).contains(n)).ok_or_else(|| CoreError::input("Job/mail limit must be 1..16"))? as usize;
        let family = request.get("family").filter(|v| !v.is_null()).map_or(Some("overview"),Value::as_str)
            .filter(|s| matches!(*s,"overview"|"registrations"|"declarations"|"policy"|"handoff"|"template_references"))
            .ok_or_else(|| CoreError::input("Unsupported job/mail family"))?;
        let max_bytes = request.get("max_bytes").map_or(Some(32768),Value::as_u64)
            .filter(|n| (1024..=65536).contains(n)).ok_or_else(|| CoreError::input("Job/mail max_bytes must be 1024..65536"))? as usize;
        Ok(Self {id,family,limit,cursor:request.get("cursor"),max_bytes})
    }
    // Includes the 64 MiB parser-worker stack, bounded source/AST and response
    // copies. This provisional admission budget is not a measured RSS claim.
    pub(crate) fn scratch(&self) -> usize {
        if matches!(self.family,"policy"|"handoff"|"template_references") {96*1024*1024} else {32*1024*1024}
    }
}

struct Work { comparisons: usize, bytes: usize }
impl recorded_domain::LabelWork for Work {
    fn compare(&mut self, a: &str, b: &str) -> Result<Ordering> {
        self.comparisons += 1;
        self.bytes = self.bytes.saturating_add(a.len()).saturating_add(b.len());
        if self.comparisons > 20_000 || self.bytes > 1024*1024 { return Err(CoreError::limit("Job/mail candidate lookup allowance")); }
        Ok(a.cmp(b))
    }
}

fn descriptor(reader: &Reader, id: &str, family: &str, cursor: Value) -> Value {
    json!({"operation":"job_mail","generation":reader.generation,"id":id,"family":family,"cursor":cursor})
}
fn saved_identity(reader: &Reader, fact: &Value) -> Value {
    json!({"generation":reader.generation,"id":fact["id"],"kind":fact["kind"],"name":fact["name"],
        "evidence":fact["evidence"],"path":fact["path"],"span":fact["location"]})
}
fn response(reader: &Reader, query: &Query<'_>, root: &Value, items: Vec<Value>, coverage: Value, position: (usize,usize), complete: bool, cost: Value) -> Result<Value> {
    let next = if complete { Value::Null } else {
        recorded_domain::cursor(&reader.generation,&json!(["job_mail",query.id,query.family]),position)?
    };
    let result = json!({"version":1,"generation":reader.generation,"root":saved_identity(reader,root),
        "family":query.family,"items":items,"coverage":coverage,"provenance":"saved_evidence",
        "unknowns":{"coherence":"unknown","binding":"unknown","execution":"unknown","delivery":"unknown"},
        "next_cursor":next,"continuation":if complete {Value::Null} else {descriptor(reader,query.id,query.family,next.clone())},
        "page_complete":complete,"semantics":SEMANTICS,"cost":cost});
    schema::encoded_bytes(&result,query.max_bytes)?;
    Ok(result)
}

/// One operation, explicit selected family; overview never parses source or
/// traverses every family. Every continuation is scoped to generation/id/family.
pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    let fact = reader.stored_fact(query.id)?;
    schema::encoded_bytes(&saved_identity(reader,fact),16*1024)?;
    let registry = fact["kind"] == "rails_job_mail";
    let erb = fact["kind"] == "file" && fact["path"].as_str().is_some_and(|p| p.ends_with(".erb"));
    let families: &[&str] = if registry { &["registrations","declarations"] }
        else if matches!(fact["kind"].as_str(),Some("class"|"module")) { &["policy"] }
        else if fact["kind"] == "method" { &["handoff"] }
        else if erb { &["template_references"] }
        else { return Err(CoreError::input("Unsupported job/mail anchor kind")); };
    let position = recorded_domain::position(query.cursor,&reader.generation,&json!(["job_mail",query.id,query.family]))?;
    if registry { validate_fact(fact)?; }
    if query.family == "overview" {
        if position != (0,0) { return Err(CoreError::input("Overview has no continuation position")); }
        let items = families.iter().map(|family| json!({"kind":"family","family":family,
            "request":descriptor(reader,query.id,family,Value::Null)})).collect();
        return response(reader,query,fact,items,json!({"scope":"Selected anchor overview only","execution":"unavailable"}),(0,0),true,json!({"source_bytes":0,"directory":"not_requested"}));
    }
    if !families.contains(&query.family) { return Err(CoreError::input("Job/mail family does not support this anchor kind")); }
    if !registry { return select_source(reader,query,fact,position); }
    let class = &fact["attributes"]["job_mail"]["class"];
    let entries = schema::array(&class["rescue_handlers"],"entries")?;
    let mut work = Work {comparisons:0,bytes:0};
    let mut items = Vec::new(); let mut next = position;
    let mut directories = Vec::new();
    let complete;
    if query.family == "registrations" {
        if position.0 > entries.len() || position.1 != 0 { return Err(CoreError::input("Registry cursor outside rows")); }
        while next.0 < entries.len() && items.len() < query.limit {
            let item = json!({"kind":"registration","root":saved_identity(reader,fact),"position":next.0,
                "provenance":"registered_metadata","registration":entries[next.0],"declaration_match":"unknown"});
            if !fits(&items,&item,query.max_bytes)? { break; }
            items.push(item); next.0 += 1;
        }
        complete = next.0 == entries.len();
    } else {
        let mut labels = Vec::new();
        if let Some(name) = class["name"].as_str() {
            labels.push(("local_class",name.to_owned(),"class"));
            if class["kind"] == "job" { labels.push(("perform",format!("{name}#perform"),"method")); }
        }
        if let Some(name) = class["superclass"].as_str() { labels.push(("superclass",name.to_owned(),"class")); }
        if next.0 > labels.len() || next.0 == labels.len() && next.1 != 0 { return Err(CoreError::input("Declaration cursor outside labels")); }
        while next.0 < labels.len() && items.len() < query.limit {
            let (role,label,kind) = &labels[next.0];
            let (page,stats) = reader.recorded_candidates(label,Some(kind),next.1,1,&mut work)?;
            directories.push(stats);
            let item = json!({"kind":"declaration_candidate","role":role,"label":label,"candidate_matches":page.total,
                "candidate_search_complete":true,"candidate_status":candidate_status(page.total),
                "candidate":page.positions.first().map(|i| saved_identity(reader,&reader.facts[*i])),
                "request":page.positions.first().map(|i| descriptor(reader,reader.facts[*i]["id"].as_str().unwrap(),"overview",Value::Null)),
                "provenance":"saved_label_candidate","binding":"unknown"});
            if !fits(&items,&item,query.max_bytes)? { break; }
            items.push(item);
            next.1 += page.positions.len();
            if next.1 == page.total { next = (next.0+1,0); }
        }
        complete = next.0 == labels.len();
    }
    if next == position && !complete { return Err(CoreError::limit("Job/mail page cannot fit one item")); }
    response(reader,query,fact,items,json!({"scope":"Explicit loaded class registry; source association and inherited effective dispatch unknown",
        "registry_status":class["rescue_handlers"]["status"],"execution":"unavailable"}),next,complete,
        json!({"label_bytes":work.bytes,"label_comparisons":work.comparisons,"directories":directories}))
}
fn candidate_status(total: usize) -> &'static str {
    if total>1 {"ambiguous"} else if total==1 {"unique_label_binding_unknown"} else {"no_recorded_match_binding_or_capture_unknown"}
}
fn fits(items: &[Value], item: &Value, max_bytes: usize) -> Result<bool> {
    // Reserve half the requested output budget for root/coverage/cost/cursor.
    let bytes = schema::encoded_bytes(items,max_bytes)?;
    match schema::encoded_bytes(item,max_bytes/2) {
        Ok(size) => Ok(bytes + size + 1 <= max_bytes/2),
        Err(error) if error.code == "limit_exceeded" => Ok(false),
        Err(error) => Err(error),
    }
}

fn parse_source(fact: &Value, path: &str, content: &str) -> Result<Value> {
    schema::encoded_bytes(fact,512*1024)?;
    let fact = fact.clone(); let path = path.to_owned(); let content = content.to_owned();
    // Same process permit/large-stack worker as capture, immediate busy
    // refusal, no second concurrency authority.
    crate::capture::parser_worker("thistle-job-mail-source",move || if path.ends_with(".erb") {
            crate::erb_template::analyze(&path,&content)
        } else { crate::job_mail_source::analyze(&fact,&content) })
}

fn candidate_key(row: &Value) -> Option<(String,&'static str)> {
    match row["kind"].as_str()? {
        "mailer_action_candidate" => Some((format!("{}#{}",recorded_domain::constant_label(row["receiver"].as_str()?),row["action"].as_str()?),"method")),
        "partial_candidate" => {
            let target = row["target"].as_str()?;
            // First child supports explicit slash-qualified partial paths only.
            // No implicit view-prefix, locale, format, variant or resolver claim.
            let (directory,name) = target.rsplit_once('/')?;
            schema::path(target).ok()?;
            Some((format!("app/views/{directory}/_{name}.html.erb"),"file"))
        },
        "template_selection" if row["status"] == "literal_candidate" => {
            let directory = row["template_path"].as_str()?;
            let template = row["template"].as_str()?;
            schema::path(directory).ok()?; schema::path(template).ok()?;
            Some((format!("app/views/{directory}/{template}.html.erb"),"file"))
        },
        _ => None,
    }
}

fn select_source(reader: &Reader, query: &Query<'_>, fact: &Value, position: (usize,usize)) -> Result<Value> {
    let path = schema::string(fact,"path")?;
    let file = schema::array(&reader.manifest,"files")?.iter().find(|f| f["path"] == path)
        .ok_or_else(|| CoreError::snapshot("Missing job/mail source metadata"))?;
    if !file["bytes"].as_u64().is_some_and(|n| n <= crate::job_mail_source::MAX_BYTES as u64) {
        return source_unknown(reader,query,fact,"saved_file_exceeds_source_allowance");
    }
    let saved = reader.source(query.id)?; // Digest AND canonical coordinates checked before parsing.
    let analysis = match parse_source(fact,path,schema::string(&saved,"content")?) {
        Ok(analysis) => analysis,
        Err(error) if error.code == "limit_exceeded" => return source_unknown(reader,query,fact,"source_analysis_operational_limit"),
        Err(error) => return Err(error),
    };
    let rows = analysis.get("rows").or_else(|| analysis.get("references")).and_then(Value::as_array)
        .ok_or_else(|| CoreError::snapshot("Missing job/mail analysis rows"))?;
    if position.0 > rows.len() || position.0 == rows.len() && position.1 != 0 {
        return Err(CoreError::input("Source continuation outside rows"));
    }
    let mut work = Work {comparisons:0,bytes:0}; let mut items = Vec::new();
    let mut next = position; let mut directories = Vec::new();
    while next.0 < rows.len() && items.len() < query.limit {
        let row = &rows[next.0];
        let (page,stats) = if let Some((key,kind)) = candidate_key(row) {
            reader.recorded_candidates(&key,Some(kind),next.1,1,&mut work)?
        } else {
            if next.1 != 0 { return Err(CoreError::input("Unsupported row has no candidate offset")); }
            (recorded_domain::Page {positions:Vec::new(),total:0},json!({"status":"not_requested"}))
        };
        directories.push(stats);
        let item = json!({"kind":"source_evidence","root":saved_identity(reader,fact),"ordinal":next.0,
            "provenance":if path.ends_with(".erb") {"inert_source"} else {"source_potential"},
            "evidence":row,"sha256":saved["sha256"],"candidate_matches":page.total,
            "candidate_search_complete":true,"candidate_status":if candidate_key(row).is_some() {candidate_status(page.total)} else {"unsupported_selection_unknown"},
            "candidate":page.positions.first().map(|i| saved_identity(reader,&reader.facts[*i])),
            "request":page.positions.first().map(|i| descriptor(reader,reader.facts[*i]["id"].as_str().unwrap(),"overview",Value::Null))});
        if !fits(&items,&item,query.max_bytes)? { break; }
        items.push(item); next.1 += page.positions.len();
        if next.1 == page.total { next = (next.0+1,0); }
    }
    let complete = next.0 == rows.len();
    if next == position && !complete { return Err(CoreError::limit("Job/mail source page cannot fit one item")); }
    let mut coverage = json!({"analysis_status":analysis["status"],"reason":analysis["reason"],
        "source_scan_complete":analysis.get("scan_complete").cloned().unwrap_or(json!(analysis["status"]=="partial")),
        "capture":capture_coverage(reader)?,"execution":"unavailable",
        "scope":"Selected saved declaration or ERB source only; inherited declarations require their selected source. No effective dispatch or complete mail resolver claim."});
    if let Some(unsearched) = analysis.get("unsearched").filter(|value| !value.is_null()) {
        coverage["unsearched"] = unsearched.clone();
    }
    response(reader,query,fact,items,coverage,next,complete,
        json!({"source_bytes":file["bytes"],"parser_stack_bytes":64*1024*1024,"label_bytes":work.bytes,"label_comparisons":work.comparisons,"directories":directories}))
}

fn source_unknown(reader: &Reader, query: &Query<'_>, fact: &Value, reason: &str) -> Result<Value> {
    response(reader,query,fact,Vec::new(),json!({"analysis_status":"unknown","reason":reason,
        "source_scan_complete":false,"execution":"unavailable","scope":"Selected source could not be analyzed; no conclusion about absence"}),
        (0,0),true,json!({"source_analysis":"unavailable"}))
}

fn capture_coverage(reader: &Reader) -> Result<Value> {
    let families = schema::array(&reader.manifest,"coverage")?;
    let complete = families.len() <= 32;
    Ok(json!({"families":families.len(),"scan_complete":complete,
        "partial_or_unknown":!complete || families.is_empty() || families.iter().take(32).any(|f| f["status"] != "complete")}))
}

#[cfg(test)]
#[path = "job_mail_tests.rs"]
mod tests;
