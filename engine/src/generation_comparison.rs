//! Two explicit borrowed saved generations. Native dispatch owns the paired
//! lifetime and scratch admission. No Git, runtime binding or retained cache.
use crate::{error::{CoreError, Result}, link_encoding::SemanticLinkView,
    model_brief::RequestWork, schema, store::Reader};
use serde::Serialize;
use serde_json::{json, Value};

const VERSION: u64 = 1;
const MAX_ITEM: usize = 128 * 1024;
const FIELD_VALUE_BYTES: usize = 2048;
const SOURCE_WINDOW_BYTES: usize = 512;
const SEMANTICS: &str = "Saved representations matched by exact typed semantic label, not runtime definitions or binding. Source is captured/extracted; physical lines are original, presentation lines are unavailable. Nearby references are potential inspection witnesses, not execution, causality or exhaustive impact. Root IDs are provenance only. Git/branch/history/co-change/test evidence is unavailable in this operation.";

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
enum Kind { File, Class, Module, Method, RailsModel, RailsSaveCallbacks, RailsJobMail }
impl Kind {
    fn parse(s: &str) -> Result<Self> { match s {
        "file" => Ok(Self::File), "class" => Ok(Self::Class), "module" => Ok(Self::Module),
        "method" => Ok(Self::Method), "rails_model" => Ok(Self::RailsModel),
        "rails_save_callbacks" => Ok(Self::RailsSaveCallbacks), "rails_job_mail" => Ok(Self::RailsJobMail),
        _ => Err(CoreError::input("Unsupported comparison kind")),
    }}
    fn name(self) -> &'static str { match self {
        Self::File => "file", Self::Class => "class", Self::Module => "module", Self::Method => "method",
        Self::RailsModel => "rails_model", Self::RailsSaveCallbacks => "rails_save_callbacks", Self::RailsJobMail => "rails_job_mail",
    }}
    fn source(self) -> bool { matches!(self, Self::File | Self::Class | Self::Module | Self::Method) }
}

#[derive(Clone, Copy, Serialize)]
struct LogicalKey<'a> { kind: Kind, name: &'a str, role: Option<&'a str> }

pub(crate) struct Query<'a> {
    key: LogicalKey<'a>, family: &'a str, direction: &'a str,
    limit: usize, max_bytes: usize, cursor: Option<&'a Value>,
}
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let selection = &request["selection"];
        let fields = selection.as_object().ok_or_else(|| CoreError::input("Typed selection is required"))?;
        if fields.keys().any(|k| !["kind", "name", "role"].contains(&k.as_str())) {
            return Err(CoreError::input("Unknown selection field"));
        }
        let kind = Kind::parse(schema::string(selection, "kind")?)?;
        let name = schema::string(selection, "name")?;
        if name.is_empty() || name.len() > 4096 || name.contains('\0') {
            return Err(CoreError::input("Selection name must contain 1 to 4096 bytes"));
        }
        let role = match selection.get("role") { None | Some(Value::Null) => None,
            Some(v) => Some(v.as_str().ok_or_else(|| CoreError::input("Role must be job or mailer"))?) };
        if kind == Kind::RailsJobMail {
            if !matches!(role, Some("job" | "mailer")) { return Err(CoreError::input("Job/mail selection requires job or mailer role")); }
        } else if role.is_some() { return Err(CoreError::input("Only job/mail selections have a role")); }
        let family = match request.get("family") { None => "entity", Some(v) => v.as_str()
            .filter(|s| ["entity", "references"].contains(s)).ok_or_else(|| CoreError::input("Family must be entity or references"))? };
        let direction = match request.get("direction") { None => "incoming", Some(v) => v.as_str()
            .filter(|s| ["incoming", "outgoing"].contains(s)).ok_or_else(|| CoreError::input("Direction must be incoming or outgoing"))? };
        if family == "entity" && request.get("cursor").is_some_and(|v| !v.is_null()) {
            return Err(CoreError::input("Entity comparison has no continuation"));
        }
        fn integer(v: &Value, key: &str, default: usize, max: usize) -> Result<usize> {
            match v.get(key) { None => Ok(default), Some(v) => v.as_u64()
                .filter(|n| *n > 0 && *n <= max as u64).map(|n| n as usize)
                .ok_or_else(|| CoreError::input(format!("{key} must be between 1 and {max}"))) }
        }
        Ok(Self { key: LogicalKey { kind, name, role }, family, direction,
            limit: integer(request, "limit", 8, 16)?, max_bytes: integer(request, "max_bytes", 32768, 65536)?, cursor: request.get("cursor") })
    }
    // One admission remains held by native dispatch through envelope serialization.
    // No retained allocations or index; include both bounded source buffers,
    // projection/normalization, output Values, escaped JSON and C/Ruby copies.
    pub(crate) fn scratch(&self) -> usize { 32 * 1024 * 1024 }
    fn scope(&self) -> Value { json!([VERSION, self.key, self.family, self.direction, self.limit, self.max_bytes]) }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
enum Status { Added, Removed, Changed, Unchanged, Ambiguous, Uncomparable }

#[derive(Default)]
struct Matches<'a> { count: usize, preview: Vec<&'a Value>, unsupported: bool }
impl<'a> Matches<'a> {
    fn unique(&self) -> Option<&'a Value> { (self.count == 1 && !self.unsupported).then(|| self.preview[0]) }
}

fn charge_label(a: &str, b: &str, work: &mut RequestWork) -> Result<bool> {
    if !work.labels(a.len().saturating_add(b.len())) { return Err(CoreError::limit("Shared comparison label allowance exhausted")); }
    Ok(a == b)
}
// Actual schema names, with anonymous registry labels deliberately excluded.
// No leading-:: stripping, suffix/prefix matching, case folding or renaming.
fn semantic_name(fact: &Value, kind: Kind) -> Option<&str> { match kind {
    Kind::RailsModel => fact["attributes"]["model"]["name"].as_str(),
    Kind::RailsSaveCallbacks => fact["attributes"]["callbacks"]["name"].as_str(),
    Kind::RailsJobMail => fact["attributes"]["job_mail"]["class"]["name"].as_str(),
    _ => fact["name"].as_str(),
}}
fn supported(fact: &Value, kind: Kind) -> bool {
    if matches!(kind, Kind::Class | Kind::Module | Kind::Method) {
        return fact["evidence"]=="static" && matches!(fact["attributes"]["name_resolution"].as_str(), Some("lexical" | "absolute_lexical"));
    }
    if kind==Kind::File {return fact["evidence"]=="static" && fact["path"].as_str().is_some_and(|p|fact["name"]==p) && !fact["location"].is_null();}
    true
}
fn matching<'a>(reader: &'a Reader, key: LogicalKey<'_>, work: &mut RequestWork) -> Result<Matches<'a>> {
    let mut found = Matches::default();
    for fact in &reader.facts {
        if !work.facts(1) { return Err(CoreError::limit("Complete two-generation uniqueness scan exceeds shared fact allowance")); }
        if !charge_label(fact["kind"].as_str().unwrap(), key.kind.name(), work)? { continue; }
        let Some(name) = semantic_name(fact, key.kind) else { continue; };
        if !charge_label(name, key.name, work)? { continue; }
        if let Some(role) = key.role {
            if !charge_label(fact["attributes"]["job_mail"]["class"]["kind"].as_str().unwrap(), role, work)? { continue; }
        }
        found.count += 1; found.unsupported |= !supported(fact, key.kind);
        if found.preview.len() < 2 { found.preview.push(fact); }
    }
    Ok(found)
}

fn copy(value: &Value, work: &mut RequestWork) -> Result<Value> {
    work.metadata(value, 2)?;
    schema::encoded_bytes(value, MAX_ITEM)?;
    Ok(value.clone())
}
fn identity(reader: &Reader, fact: &Value, work: &mut RequestWork) -> Result<Value> {
    let mut out = serde_json::Map::new();
    for key in ["id", "kind", "name", "path", "evidence"] {
        out.insert(key.into(), copy(&fact[key], work)?);
    }
    let mut location=Value::Null;
    if !fact["location"].is_null() {
        location=json!({});
        for key in ["start_byte","end_byte","start_line","end_line"] {
            location[key]=copy(&fact["location"][key],work)?;
        }
    }
    out.insert("location".into(),location);
    out.insert("generation".into(), json!(reader.generation));
    out.insert("source_label".into(), json!("captured/extracted"));
    out.insert("presentation_lines".into(), Value::Null);
    if let Some(path) = fact["path"].as_str() {
        let file = reader.selected_file_metadata(path)?;
        out.insert("payload_sha256".into(), copy(&file["sha256"], work)?);
        out.insert("payload_bytes".into(), copy(&file["bytes"], work)?);
    }
    Ok(Value::Object(out))
}
fn match_dto(reader: &Reader, found: &Matches<'_>, work: &mut RequestWork) -> Result<Value> {
    let mut items = Vec::new();
    for fact in &found.preview { items.push(identity(reader, fact, work)?); }
    Ok(json!({"count":found.count, "scan":"complete", "identities":items,
        "known_omitted":found.count.saturating_sub(found.preview.len()), "unsupported_name_resolution":found.unsupported}))
}

// Bounded allowlist, deliberately no arbitrary producer/manifest cloning. No
// Git claim is synthesized from root_id, generation or a publisher's label.
fn provenance(reader: &Reader, work: &mut RequestWork) -> Result<Value> {
    Ok(json!({"generation":reader.generation, "root_id":copy(&reader.manifest["root_id"],work)?,
        "schema_version":reader.schema_version(), "source":"captured/extracted",
        "root_id_binding":"unvalidated_repository_ref_commit_tree",
        "commit_provenance":"unavailable", "loaded_code_coherence":"unknown"}))
}

fn coverage<'a>(reader: &'a Reader, family: &str, work: &mut RequestWork) -> Result<Option<&'a Value>> {
    let mut found = None;
    for row in reader.manifest["coverage"].as_array().unwrap() {
        if !work.facts(1) { return Err(CoreError::limit("Shared coverage allowance exhausted")); }
        if charge_label(row["family"].as_str().unwrap(),family,work)? {
            // Duplicate or contradictory coverage never proves absence.
            if found.is_some() { return Ok(None); }
            work.metadata(row,1)?; found=Some(row);
        }
    }
    Ok(found)
}
fn absence_coverage(left: &Reader, right: &Reader, kind: Kind, work: &mut RequestWork) -> Result<Value> {
    if !kind.source() { return Ok(json!({"sufficient":false,"reason":"loaded_registry_inventory_is_not_exhaustive"})); }
    let families: &[&str] = if kind == Kind::File { &["source_inventory"] } else { &["source_inventory","ruby_declarations"] };
    let mut sufficient = true; let mut rows = Vec::new();
    for family in families {
        let a=coverage(left,family,work)?; let b=coverage(right,family,work)?;
        let comparable = match (a,b) {
            (Some(a),Some(b)) => coverage_policy_known(a) && coverage_policy_known(b)
                && a["status"] == "complete" && b["status"] == "complete"
                && charge_label(a["scope"].as_str().unwrap(), b["scope"].as_str().unwrap(), work)?
                && ["prism_version","ruby_syntax_version","parser_policy"].iter().all(|key| a.get(*key)==b.get(*key)),
            _ => false,
        };
        sufficient &= comparable;
        rows.push(json!({"family":family,"comparable_complete_scope":comparable,
            "left":coverage_dto(a,work)?,"right":coverage_dto(b,work)? }));
    }
    Ok(json!({"sufficient":sufficient,"families":rows,"meaning":"absence only within the recorded matching capture scopes, never runtime deletion"}))
}
const COVERAGE_FIELDS: &[&str]=&["family","status","scope","reason","prism_version","ruby_syntax_version","parser_policy"];
fn coverage_policy_known(row:&Value)->bool{
    row.as_object().unwrap().keys().all(|k|COVERAGE_FIELDS.contains(&k.as_str()))
        && ["prism_version","ruby_syntax_version","parser_policy"].iter().all(|k|
            row.get(*k).is_none_or(|v|v.as_str().is_some_and(|s|!s.trim().is_empty())))
}
fn coverage_dto(row:Option<&Value>,work:&mut RequestWork)->Result<Value>{
    let Some(row)=row else{return Ok(Value::Null);};
    let mut out=serde_json::Map::new();
    for key in COVERAGE_FIELDS {
        if let Some(value)=row.get(*key){out.insert((*key).into(),copy(value,work)?);}
    }
    out.insert("policy_fields_recognized".into(),json!(coverage_policy_known(row)));
    Ok(Value::Object(out))
}

// Borrowed projection removes only the registry's own local ordinal. Nested
// callback ordinal/position and every array order, missing field and null remain.
struct Metadata<'a> { fact: &'a Value, kind: Kind }
impl Serialize for Metadata<'_> {
    fn serialize<S: serde::Serializer>(&self, serializer: S) -> std::result::Result<S::Ok,S::Error> {
        use serde::ser::SerializeMap;
        struct WithoutOrdinal<'a>(&'a Value);
        impl Serialize for WithoutOrdinal<'_> {
            fn serialize<S: serde::Serializer>(&self,s:S)->std::result::Result<S::Ok,S::Error> {
                let mut map=s.serialize_map(None)?;
                for (k,v) in self.0.as_object().expect("validated registry metadata") {
                    if k!="ordinal" { map.serialize_entry(k,v)?; }
                }
                map.end()
            }
        }
        let mut map=serializer.serialize_map(None)?;
        for (k,v) in self.fact["attributes"].as_object().unwrap() {
            if matches!((self.kind,k.as_str()),(Kind::RailsModel,"model")|(Kind::RailsSaveCallbacks,"callbacks")|(Kind::RailsJobMail,"job_mail")) {
                map.serialize_entry(k,&WithoutOrdinal(v))?;
            } else { map.serialize_entry(k,v)?; }
        }
        map.end()
    }
}
fn metadata_digest(fact: &Value, kind: Kind, work: &mut RequestWork) -> Result<String> {
    let value=Metadata{fact,kind}; work.metadata(&value,2)?;
    schema::encoded_bytes(&value,MAX_ITEM)?;
    Ok(schema::digest(&serde_json::to_vec(&value)?))
}

fn semantic_link(reader: &Reader, fact: &Value, raw: &Value, work: &mut RequestWork) -> Result<Value> {
    // Admission precedes materialization. Only one already selected link.
    let view=SemanticLinkView::from_wire(raw,reader.schema_version(),fact["evidence"].as_str().unwrap())?;
    work.metadata(&view,3)?; schema::encoded_bytes(&view,MAX_ITEM)?;
    let mut value=view.materialize()?;
    // Physical coordinates have their own witnesses. Only recognized schema
    // extensions can be normalized; unknown extensions retain all their bytes.
    if view.call_metadata().is_some() {
        let call=view.call_metadata().unwrap();
        let mut extra=value["attributes"]["thistle_call"].as_object().unwrap().clone();
        let fields:&[&str]=if extra["version"]==2 {&["version","data"]}
            else {&["version","receiver","safe_navigation","call_location","receiver_location"]};
        for key in fields{extra.remove(*key);}
        // v1 named and v2 compact storage share the same semantic projection.
        // Keep unknown extra extension fields separate, without key collisions.
        value["attributes"]["thistle_call"]=json!({"semantic":{"receiver_kind":call.kind,
            "receiver_name":call.name,"omitted_limit":call.omitted,"safe_navigation":call.safe_navigation},"extra":extra});
    }
    if view.constant_metadata().is_some() { value["attributes"]["thistle_constant"].as_object_mut().unwrap().remove("location"); }
    Ok(value)
}
fn relationship_digest(reader: &Reader, fact: &Value, work: &mut RequestWork) -> Result<Option<String>> {
    let mut hashes=Vec::new();
    for raw in fact["links"].as_array().unwrap() {
        if !work.links(1) { return Err(CoreError::limit("Shared relationship allowance exhausted")); }
        let value=semantic_link(reader,fact,raw,work)?;
        // Resolved local targets need a separate cross-generation target map.
        // Do not compare generation-local target IDs as semantic identities.
        if value["resolution"] != "unresolved" { return Ok(None); }
        hashes.push(schema::digest(&schema::canonical(&value)?));
        if hashes.len()>1024 { return Err(CoreError::limit("Selected relationship digest exceeds 1024 entries")); }
    }
    // Preserve declared order and multiplicity. This is a saved-list comparison.
    work.metadata(&hashes,1)?;
    Ok(Some(schema::digest(&serde_json::to_vec(&hashes)?)))
}

struct SourceSpan { file: Value, start: usize, end: usize, start_line: usize }
impl SourceSpan {
    fn text(&self)->&str { &self.file["content"].as_str().unwrap()[self.start..self.end] }
    fn digest(&self)->String { schema::digest(self.text().as_bytes()) }
}
fn source_span(reader: &Reader, fact: &Value, work: &mut RequestWork) -> Result<Option<SourceSpan>> {
    let (Some(path),Some(location))=(fact["path"].as_str(),fact["location"].as_object()) else { return Ok(None); };
    let file=reader.selected_file_metadata(path)?;
    let bytes=file["bytes"].as_u64().unwrap() as usize;
    if !work.source_attempt() || !work.source_bytes(bytes) { return Err(CoreError::limit("Shared selected-source allowance exhausted")); }
    // Bound and account validation's fact/link walk before touching the blob.
    if !work.links(fact["links"].as_array().unwrap().len()) { return Err(CoreError::limit("Source validation link allowance exhausted")); }
    work.metadata(fact,2)?; work.metadata(file,2)?;
    let content=reader.source_bytes(file)?;
    let mut expanded=file.clone(); expanded["content"]=Value::String(content);
    schema::stored_facts(std::iter::once(fact),std::slice::from_ref(&expanded),reader.schema_version())
        .map_err(|_| CoreError::snapshot("Selected physical source coordinates disagree with captured bytes"))?;
    let start=location["start_byte"].as_u64().unwrap() as usize;
    let end=location["end_byte"].as_u64().unwrap() as usize;
    Ok(Some(SourceSpan{file:expanded,start,end,start_line:location["start_line"].as_u64().unwrap() as usize}))
}

fn digest_status(left: Option<String>, right: Option<String>) -> Value {
    let status=match (&left,&right) { (Some(a),Some(b)) if a==b=>Status::Unchanged,
        (Some(_),Some(_))=>Status::Changed,_=>Status::Uncomparable };
    json!({"status":status,"left_digest":left,"right_digest":right})
}
struct Entity { value:Value, left_source:Option<SourceSpan>, right_source:Option<SourceSpan> }
fn entity(left: &Reader, right: &Reader, q: &Query<'_>, a: &Matches<'_>, b: &Matches<'_>, work: &mut RequestWork) -> Result<Entity> {
    let coverage=absence_coverage(left,right,q.key.kind,work)?;
    let status=if a.count>1 || b.count>1 { Status::Ambiguous }
        else if a.unsupported || b.unsupported { Status::Uncomparable }
        else if a.count==0 && b.count==1 && coverage["sufficient"]==true { Status::Added }
        else if a.count==1 && b.count==0 && coverage["sufficient"]==true { Status::Removed }
        else { Status::Uncomparable };
    let mut out=json!({"status":status,"presence":{"left":a.count,"right":b.count},"absence_coverage":coverage,
        "source":{"status":"uncomparable"},"metadata":{"status":"uncomparable"},"relationships":{"status":"uncomparable"},
        "line_diff":{"status":"unavailable","reason":"no_line_diff_computed"},"change_kind":"unknown"});
    let (mut left_source,mut right_source)=(None,None);
    if let (Some(af),Some(bf))=(a.unique(),b.unique()) {
        left_source=source_span(left,af,work)?;right_source=source_span(right,bf,work)?;
        out["source"]=digest_status(left_source.as_ref().map(SourceSpan::digest),right_source.as_ref().map(SourceSpan::digest));
        out["source"]["meaning"]=json!("validated captured physical span bytes, not loaded code or line mapping");
        out["metadata"]=digest_status(Some(metadata_digest(af,q.key.kind,work)?),Some(metadata_digest(bf,q.key.kind,work)?));
        out["relationships"]=digest_status(relationship_digest(left,af,work)?,relationship_digest(right,bf,work)?);
        let src=out["source"]["status"].as_str().unwrap();
        let meta=out["metadata"]["status"].as_str().unwrap();
        let rel=out["relationships"]["status"].as_str().unwrap();
        let changed=src=="changed" || meta=="changed" || rel=="changed";
        let known=src=="unchanged" && meta=="unchanged" && rel=="unchanged";
        let change_kind=if src=="changed" {"source"} else if src=="unchanged" && meta=="changed" && rel=="unchanged" {"metadata_only"}
            else if meta=="changed" && src=="uncomparable" {"metadata_changed_source_unknown"}
            else if rel=="changed" {"relationships"} else if known {"unchanged"} else {"unknown"};
        out["status"]=json!(if changed {Status::Changed} else if known {Status::Unchanged} else {Status::Uncomparable});
        out["change_kind"]=json!(change_kind);
    } else if status==Status::Added || status==Status::Removed {
        let present=if let Some(f)=a.unique(){source_span(left,f,work)?}else{source_span(right,b.unique().unwrap(),work)?};
        let digest=present.as_ref().map(SourceSpan::digest);
        out["source"]=json!({"status":status,"present_span_digest":digest,
            "absent_side":if status==Status::Added{"left"}else{"right"},"line_mapping":"unavailable"});
        if status==Status::Added{out["source"]["previous_lines"]=Value::Null;}
    }
    Ok(Entity{value:out,left_source,right_source})
}

fn saved_ref(reader:&Reader,fact:&Value)->Value {
    json!({"generation":reader.generation,"fact_id":fact["id"]})
}
fn followup(reader:&Reader,fact:&Value,operation:&str)->Value {
    json!({"operation":operation,"generation":reader.generation,"id":fact["id"]})
}
fn value_type(value:&Value)->&'static str {match value {
    Value::Null=>"null",Value::Bool(_)=>"boolean",Value::Number(_)=>"number",
    Value::String(_)=>"string",Value::Array(_)=>"array",Value::Object(_)=>"object",
}}
fn omitted_value(value:Option<&Value>,reason:&str)->Value {match value {
    None=>json!({"present":false,"value_status":"missing"}),
    Some(v)=>json!({"present":true,"value_status":"omitted","value_type":value_type(v),"reason":reason}),
}}
fn field_value(value:Option<&Value>,work:&mut RequestWork)->Result<Value>{
    let Some(value)=value else{return Ok(omitted_value(None,"missing"));};
    // Measure the borrowed value before any clone, including escaped bytes.
    work.metadata(value,2)?;
    match schema::encoded_bytes(value,FIELD_VALUE_BYTES) {
        Ok(_)=>Ok(json!({"present":true,"value_status":"shown","value":value})),
        Err(e) if e.code=="limit_exceeded"=>Ok(omitted_value(Some(value),"value_byte_limit")),
        Err(e)=>Err(e),
    }
}

// The two buffers are the files just validated by source_span, not new reads or
// copied whole source domains. One linear first-difference pass and at most two
// prefix line counts per side; charge their full prospective byte work first.
fn source_region(reader:&Reader,fact:&Value,source:&SourceSpan,start:usize,work:&mut RequestWork)->Result<Value>{
    let text=source.text();let mut end=(start+SOURCE_WINDOW_BYTES).min(text.len());
    while !text.is_char_boundary(end){end-=1;}
    let window=&text[start..end];work.metadata(&window,2)?;
    Ok(json!({"generation":reader.generation,"fact_id":fact["id"],"path":copy(&fact["path"],work)?,
        "payload_sha256":source.file["sha256"],"span_sha256":source.digest(),
        "region":{"start_byte":source.start+start,"end_byte":source.start+end,
            "start_line":source.start_line+text.as_bytes()[..start].iter().filter(|b|**b==b'\n').count(),
            "end_line":source.start_line+text.as_bytes()[..end].iter().filter(|b|**b==b'\n').count(),
            "text":window,"sha256":schema::digest(window.as_bytes())},
        "selected_span_bytes_omitted_before":start,"selected_span_bytes_omitted_after":text.len()-end}))
}
fn source_witness(left:&Reader,right:&Reader,af:&Value,bf:&Value,a:&SourceSpan,b:&SourceSpan,
    out:&mut Value,q:&Query<'_>,work:&mut RequestWork)->Result<()> {
    if out["comparison"]["source"]["status"]!="changed" {
        out["comparison"]["source"]["witness"]["status"]=json!("not_applicable");
        out["comparison"]["source"]["witness"]["reason"]=json!("validated_selected_spans_equal");return Ok(());
    }
    out["comparison"]["source"]["witness"]["status"]=json!("omitted");
    let bytes=a.text().len().saturating_add(b.text().len()).saturating_mul(5);
    if !work.labels(bytes){out["comparison"]["source"]["witness"]["reason"]=json!("shared_work");return Ok(());}
    let prefix=a.text().bytes().zip(b.text().bytes()).take_while(|(a,b)|a==b).count();
    let mut start=prefix.saturating_sub(64);
    while !a.text().is_char_boundary(start) || !b.text().is_char_boundary(start){start-=1;}
    let candidate=(||->Result<Value>{Ok(json!({"status":"shown","kind":"first_difference_window",
        "first_differing_span_byte":prefix,"complete_hunks":false,"line_mapping":"unavailable",
        "left":source_region(left,af,a,start,work)?,"right":source_region(right,bf,b,start,work)?,
        "meaning":"Exact captured text around the first differing byte; further changes may be outside these windows"}))})();
    let candidate=match candidate {Ok(v)=>v,Err(e) if e.code=="limit_exceeded"=>{
        out["comparison"]["source"]["witness"]["reason"]=json!("shared_work");return Ok(());},Err(e)=>return Err(e)};
    let old=std::mem::replace(&mut out["comparison"]["source"]["witness"],candidate);
    let admitted=match work.metadata(out,2){Ok(_)=>fits(out,q.max_bytes.saturating_sub(512))?,
        Err(e) if e.code=="limit_exceeded"=>false,Err(e)=>return Err(e)};
    if !admitted {
        out["comparison"]["source"]["witness"]=old;
        out["comparison"]["source"]["witness"]["reason"]=json!("output_or_shared_work_budget");
    }
    Ok(())
}

struct FieldWriter<'a> { out:&'a mut Value, work:&'a mut RequestWork, kind:Kind, limit:usize, max_bytes:usize }
impl FieldWriter<'_> {
    fn count(&self)->usize{self.out["comparison"]["metadata"]["evidence"]["items"].as_array().unwrap().len()}
    fn admit(&mut self)->Result<bool>{match self.work.metadata(self.out,2){
        Ok(_)=>fits(self.out,self.max_bytes.saturating_sub(512)),
        Err(e) if e.code=="limit_exceeded"=>Ok(false),Err(e)=>Err(e),
    }}
    fn emit(&mut self,a:Option<&Value>,b:Option<&Value>,path:&str)->Result<Option<&'static str>>{
        if !self.work.label_bytes(path.len()){return Ok(Some("shared_work"));}
        let row=(||->Result<Value>{Ok(json!({"path":path,"before":field_value(a,self.work)?,"after":field_value(b,self.work)?}))})();
        let row=match row{Ok(v)=>v,Err(e) if e.code=="limit_exceeded"=>return Ok(Some("shared_work")),Err(e)=>return Err(e)};
        self.out["comparison"]["metadata"]["evidence"]["items"].as_array_mut().unwrap().push(row);
        if self.admit()?{return Ok(None);}
        // Whole typed values cannot fit: keep the exact named path/presence and
        // make omission explicit, with pinned fact followups on the family.
        let last=self.out["comparison"]["metadata"]["evidence"]["items"].as_array_mut().unwrap().last_mut().unwrap();
        last["before"]=omitted_value(a,"output_or_shared_work_budget");
        last["after"]=omitted_value(b,"output_or_shared_work_budget");
        if self.admit()?{return Ok(None);}
        self.out["comparison"]["metadata"]["evidence"]["items"].as_array_mut().unwrap().pop();
        if self.count()==0{return Err(CoreError::limit("First changed-field row cannot fit the comparison envelope"));}
        Ok(Some("output_or_shared_work_budget"))
    }
    fn child(&mut self,a:Option<&Value>,b:Option<&Value>,path:&mut String,key:&str,depth:usize)->Result<Option<&'static str>>{
        if key=="ordinal" && matches!((self.kind,path.as_str()),(Kind::RailsModel,"/model")|
            (Kind::RailsSaveCallbacks,"/callbacks")|(Kind::RailsJobMail,"/job_mail")){return Ok(None);}
        if !self.work.label_bytes(key.len().saturating_mul(2)){return Ok(Some("shared_work"));}
        let escaped_bytes=key.bytes().map(|b|if b==b'/' || b==b'~'{2}else{1}).sum::<usize>();
        if path.len()+escaped_bytes+1>4096{return Ok(Some("field_path_limit"));}
        let len=path.len();path.push('/');
        for c in key.chars(){match c{'~'=>path.push_str("~0"),'/'=>path.push_str("~1"),_=>path.push(c)}}
        let result=self.walk(a,b,path,depth+1);path.truncate(len);result
    }
    fn walk(&mut self,a:Option<&Value>,b:Option<&Value>,path:&mut String,depth:usize)->Result<Option<&'static str>>{
        if self.count()==self.limit{return Ok(Some("row_limit"));}
        if depth>64{return Ok(Some("field_depth_limit"));}
        let visits=(if a.is_some(){1}else{0})+(if b.is_some(){1}else{0});
        if !self.work.facts(visits){return Ok(Some("shared_work"));}
        match(a,b){
            (Some(Value::Object(a)),Some(Value::Object(b)))=>{
                // serde_json's current canonical (BTreeMap) object order. Merge
                // keys once; no repeated subtree equality or copied key domain.
                let(mut ai,mut bi)=(a.iter(),b.iter());let(mut av,mut bv)=(ai.next(),bi.next());
                while av.is_some() || bv.is_some(){
                    let(key,left,right)=match(av,bv){
                        (Some((ak,a)),Some((bk,b)))=>{
                            if !self.work.labels(ak.len().saturating_add(bk.len())){return Ok(Some("shared_work"));}
                            match ak.cmp(bk){
                                std::cmp::Ordering::Less=>{av=ai.next();(ak,Some(a),None)},
                                std::cmp::Ordering::Greater=>{bv=bi.next();(bk,None,Some(b))},
                                std::cmp::Ordering::Equal=>{av=ai.next();bv=bi.next();(ak,Some(a),Some(b))},
                            }
                        },
                        (Some((key,a)),None)=>{av=ai.next();(key,Some(a),None)},
                        (None,Some((key,b)))=>{bv=bi.next();(key,None,Some(b))},_=>unreachable!(),
                    };
                    if let Some(reason)=self.child(left,right,path,key,depth)?{return Ok(Some(reason));}
                }
                Ok(None)
            },
            (Some(Value::Array(a)),Some(Value::Array(b)))=>{
                for i in 0..a.len().max(b.len()){
                    if let Some(reason)=self.child(a.get(i),b.get(i),path,&i.to_string(),depth)?{return Ok(Some(reason));}
                }
                Ok(None)
            },
            _=>{
                for v in [a,b].into_iter().flatten(){if let Err(e)=self.work.metadata(v,1){
                    if e.code=="limit_exceeded"{return Ok(Some("shared_work"));}return Err(e);
                }}
                if a==b{Ok(None)}else{self.emit(a,b,path)}
            },
        }
    }
}

fn content_evidence(left:&Reader,right:&Reader,q:&Query<'_>,a:&Matches<'_>,b:&Matches<'_>,
    sources:&Entity,out:&mut Value,work:&mut RequestWork)->Result<()> {
    let (Some(af),Some(bf))=(a.unique(),b.unique()) else{
        out["comparison"]["metadata"]["evidence"]=json!({"status":"unavailable","reason":"no_supported_unique_pair"});
        out["comparison"]["source"]["witness"]=json!({"status":"unavailable","reason":"no_supported_unique_source_pair"});
        out["scan"]["content_evidence_complete"]=json!(false);
        return Ok(());
    };
    out["comparison"]["source"]["followups"]=json!({"left":if af["path"].is_null(){Value::Null}else{followup(left,af,"source")},
        "right":if bf["path"].is_null(){Value::Null}else{followup(right,bf,"source")}});
    out["comparison"]["source"]["witness"]=json!({"status":"unavailable","reason":"source_pair_unavailable"});
    out["comparison"]["metadata"]["evidence"]=json!({"status":"unavailable",
        "context":{"left":saved_ref(left,af),"right":saved_ref(right,bf)},"items":[],
        "scan_complete":false,"unsearched":true,"reason":"not_admitted",
        "path_root":"attributes","array_semantics":"positional_saved_order",
        "followups":{"left":followup(left,af,"fact"),"right":followup(right,bf,"fact")}});
    work.metadata(out,2)?;
    if !fits(out,q.max_bytes)?{return Err(CoreError::limit("Mandatory changed-content context cannot fit the native envelope"));}
    if let(Some(a),Some(b))=(&sources.left_source,&sources.right_source){source_witness(left,right,af,bf,a,b,out,q,work)?;}
    let changed=out["comparison"]["metadata"]["status"]=="changed";
    let unchanged=out["comparison"]["metadata"]["status"]=="unchanged";
    let stopped=if changed{
        FieldWriter{out:&mut *out,work:&mut *work,kind:q.key.kind,limit:q.limit,max_bytes:q.max_bytes}
            .walk(Some(&af["attributes"]),Some(&bf["attributes"]),&mut String::new(),0)?
    }else if unchanged{None}else{Some("metadata_uncomparable")};
    let evidence=&mut out["comparison"]["metadata"]["evidence"];
    let omitted=evidence["items"].as_array().unwrap().iter().any(|row|
        row["before"]["value_status"]=="omitted" || row["after"]["value_status"]=="omitted");
    evidence["status"]=json!(if stopped.is_some() || omitted{"partial"}else{"complete"});
    evidence["scan_complete"]=json!(stopped.is_none());evidence["unsearched"]=json!(stopped.is_some());
    evidence["reason"]=json!(stopped.unwrap_or(if omitted{"values_omitted"}else{"selected_metadata_end"}));
    let fields_complete=stopped.is_none() && !omitted;
    let source_complete=matches!(out["comparison"]["source"]["witness"]["status"].as_str(),Some("shown"|"not_applicable"));
    out["scan"]["complete"]=json!(stopped.is_none());
    out["scan"]["reason"]=json!(stopped.unwrap_or("entity_content_evidence"));
    out["scan"]["content_evidence_complete"]=json!(fields_complete && source_complete);
    out["scan"]["followup_kind"]=json!("pinned_fact_or_source; no changed-field cursor");
    Ok(())
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
struct Position { side: usize, fact: usize, link: usize }
impl Position { fn start()->Self {Self{side:0,fact:0,link:0}} }
fn scope_hash(q:&Query<'_>)->Result<String>{Ok(schema::digest(&schema::canonical(&q.scope())?))}
fn token(left:&Reader,right:&Reader,q:&Query<'_>,p:Position)->Result<Value>{
    Ok(Value::String(serde_json::to_string(&json!(["comparison-v1",left.generation,right.generation,scope_hash(q)?,p.side,p.fact,p.link]))?))
}
fn position(left:&Reader,right:&Reader,q:&Query<'_>)->Result<Position>{
    let Some(v)=q.cursor.filter(|v|!v.is_null()) else {return Ok(Position::start());};
    let text=v.as_str().filter(|s|s.len()<=512).ok_or_else(||CoreError::input("Invalid paired cursor"))?;
    let value:Value=serde_json::from_str(text).map_err(|_|CoreError::input("Invalid paired cursor JSON"))?;
    let v=value.as_array().filter(|v|v.len()==7).ok_or_else(||CoreError::input("Invalid paired cursor shape"))?;
    if v[0]!="comparison-v1" || v[1]!=left.generation || v[2]!=right.generation || v[3]!=scope_hash(q)? {
        return Err(CoreError::input("Cursor belongs to another ordered generation pair or selection/filter/version"));
    }
    let integer=|i:usize|v[i].as_u64().and_then(|n|usize::try_from(n).ok()).ok_or_else(||CoreError::input("Invalid cursor position"));
    let p=Position{side:integer(4)?,fact:integer(5)?,link:integer(6)?};
    if p.side>1 {return Err(CoreError::input("Cursor side is out of range"));}
    let r=if p.side==0{left}else{right};
    if p.fact>r.facts.len() || (p.fact==r.facts.len() && p.link!=0)
        || (p.fact<r.facts.len() && p.link>r.facts[p.fact]["links"].as_array().unwrap().len()) {
        return Err(CoreError::input("Cursor work position is out of range"));
    }
    Ok(p)
}

fn witness_label<'a>(view:&SemanticLinkView<'a>)->Option<&'a str>{
    if let Some(call)=view.call_metadata() {
        return if call.kind=="constant" && !call.omitted {call.name}else{None};
    }
    // Precisely recorded label witnesses, never an inferred target binding.
    if view.constant_metadata().is_some() || ["inherits","includes","extends","prepends","association_target_label","model_base_label"].contains(&view.relation()) {
        return Some(view.target());
    }
    None
}
fn fits(out:&Value,max:usize)->Result<bool>{
    // Match actual native envelope bytes; CString's terminator is not JSON and
    // no newline is assumed. The global dispatch reservation owns serialization.
    #[derive(Serialize)]struct Envelope<'a>{ok:bool,result:&'a Value}
    match schema::encoded_bytes(&Envelope{ok:true,result:out},max) {
        Ok(_)=>Ok(true),Err(e) if e.code=="limit_exceeded"=>Ok(false),Err(e)=>Err(e),
    }
}
fn reference_row(r:&Reader,fact:&Value,raw:&Value,q:&Query<'_>,p:Position,work:&mut RequestWork)->Result<Option<Value>> {
    let view=SemanticLinkView::from_wire(raw,r.schema_version(),fact["evidence"].as_str().unwrap())?;
    let relevant=if q.direction=="outgoing"{true}else{match witness_label(&view){
        Some(label)=>charge_label(label,q.key.name,work)?,None=>false,
    }};
    if !relevant{return Ok(None);}
    work.metadata(&view,2)?;schema::encoded_bytes(&view,MAX_ITEM)?;
    let mut row=json!({"side":if p.side==0{"left"}else{"right"},"generation":r.generation,
        "direction":q.direction,"origin":identity(r,fact,work)?,"link_index":p.link,
        "relation":view.relation(),"target_label":view.target(),"resolution":view.resolution(),
        "meaning":"recorded direct witness; target binding and execution unknown"});
    row["recorded_link"]=view.materialize()?;Ok(Some(row))
}
fn references(left:&Reader,right:&Reader,q:&Query<'_>,a:&Matches<'_>,b:&Matches<'_>,out:&mut Value,work:&mut RequestWork)->Result<()> {
    let mut p=position(left,right,q)?;let initial=p;
    let mut items=Vec::new();
    let mut stop=None;
    let (mut facts_visited,mut links_visited)=(0usize,0usize);
    'scan: while p.side<2 {
        let r=if p.side==0{left}else{right};let m=if p.side==0{a}else{b};
        if p.fact==r.facts.len(){p=Position{side:p.side+1,fact:0,link:0};continue;}
        if !work.facts(1){stop=Some("shared_work");break;}
        facts_visited+=1;
        let fact=&r.facts[p.fact];let links=fact["links"].as_array().unwrap();
        if q.direction=="outgoing" && !m.unique().is_some_and(|f|std::ptr::eq(f,fact)) {
            p.fact+=1;p.link=0;continue;
        }
        while p.link<links.len() {
            let before=p;
            if !work.links(1){stop=Some("shared_work");break 'scan;}
            links_visited+=1;
            let raw=&links[p.link];
            let row=match reference_row(r,fact,raw,q,p,work) {
                Ok(row)=>row,Err(e) if e.code=="limit_exceeded"=>{stop=Some("shared_work");break 'scan;},Err(e)=>return Err(e),
            };
            if let Some(row)=row {
                if items.len()==q.limit{stop=Some("row_limit");break 'scan;}
                // Stage exactly one candidate. Byte cuts leave its position
                // unconsumed; admitted prefix and spent work are never reset.
                items.push(row);p.link+=1;
                out["items"]=Value::Array(std::mem::take(&mut items));
                out["next_cursor"]=token(left,right,q,p)?;
                out["scan"]=json!({"complete":false,"reason":"byte_limit","zero_progress":false});
                // 512 encoded bytes cover the final scan fields and every
                // usize-position digit/cursor growth (three <=20-digit fields),
                // including after scanning nonmatching rows beyond this item.
                let admitted=match work.metadata(out,2) {
                    Ok(_)=>fits(out,q.max_bytes.saturating_sub(512))?,
                    Err(e) if e.code=="limit_exceeded"=>false,
                    Err(e)=>return Err(e),
                };
                items=std::mem::take(out["items"].as_array_mut().unwrap());
                if !admitted {
                    items.pop();p=before;
                    if items.is_empty(){return Err(CoreError::limit("First comparison witness cannot fit the requested native envelope"));}
                    stop=Some("byte_limit");break 'scan;
                }
            }else{p.link+=1;}
        }
        p.fact+=1;p.link=0;
    }
    let complete=p.side==2;
    if !complete && p==initial && items.is_empty(){return Err(CoreError::limit("Comparison continuation made zero progress"));}
    out["items"]=Value::Array(items);
    out["next_cursor"]=if complete{Value::Null}else{token(left,right,q,p)?};
    out["scan"]=json!({"complete":complete,"reason":stop.unwrap_or("domain_end"),"zero_progress":false,
        "capture_completeness":"independent_of_scan_completion","position":[p.side,p.fact,p.link]});
    out["cost"]["reference_fact_visits"]=json!(facts_visited);
    out["cost"]["reference_link_visits"]=json!(links_visited);
    Ok(())
}

pub(crate) fn select(left:&Reader,right:&Reader,q:&Query<'_>)->Result<Value>{
    select_with_work(left,right,q,&mut RequestWork::default())
}
fn select_with_work(left:&Reader,right:&Reader,q:&Query<'_>,work:&mut RequestWork)->Result<Value>{
    // Whole-domain proof repeats per request and shares the allowance with both
    // sides' source/metadata/relationship/reference/finalization work.
    let a=matching(left,q.key,work)?;let b=matching(right,q.key,work)?;
    let mut out=json!({"version":VERSION,"pair":{"left":provenance(left,work)?,"right":provenance(right,work)?},
        "selection":q.key,"family":q.family,"direction":q.direction,
        "matching":{"left":match_dto(left,&a,work)?,"right":match_dto(right,&b,work)?,
            "rule":"exact kind + qualified saved semantic name + job/mail role; no runtime binding"},
        "semantics":SEMANTICS,"items":[],"next_cursor":null,
        "scan":{"complete":true,"reason":"entity","zero_progress":false},
        "unavailable":["git_commit_comparison","branch_comparison","history","co_change","test_relevance","execution","line_diff"],
        "cost":{"root_lookup":"complete borrowed left+right fact scan every request; no optional directory/index",
            "root_fact_visits":left.facts.len()+right.facts.len(),
            "reader_open":"existing Reader admission/validation/cache cost precedes this operation",
            "work":"one model_brief::RequestWork across both sides; fixed global reservation through native serialization"}});
    // Mandatory identity/provenance must fit before evidence materialization.
    work.metadata(&out,2)?;
    if !fits(&out,q.max_bytes)?{return Err(CoreError::limit("Mandatory comparison identity envelope cannot fit"));}
    if q.family=="entity" {
        let mut result=entity(left,right,q,&a,&b,work)?;
        out["comparison"]=std::mem::take(&mut result.value);
        content_evidence(left,right,q,&a,&b,&result,&mut out,work)?;
    }
    else {
        if a.count>1 || b.count>1 || a.unsupported || b.unsupported {
            return Err(CoreError::new("ambiguous_comparison","Reference selection requires supported unique logical identity on each present side"));
        }
        if a.count==0 && b.count==0 {return Err(CoreError::new("not_found","Logical selection is absent in both saved generations"));}
        references(left,right,q,&a,&b,&mut out,work)?;
    }
    work.finish_metadata();work.metadata(&out,3)?;
    if !fits(&out,q.max_bytes)?{return Err(CoreError::limit("Comparison native envelope cannot fit"));}
    Ok(out)
}

#[cfg(test)]
#[path = "generation_comparison_tests.rs"]
mod tests;
