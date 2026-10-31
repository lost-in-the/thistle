//! LOS-147: saved definitions and builtin ownership observations are separate.
//! Root wires admission/index lifetime/public Reader; no source/runtime binding.
use crate::{error::{CoreError, Result}, method_lookup, query, recorded_domain, schema, store::Reader};
use serde_json::{json, Value};
use std::{cmp::Ordering, collections::{HashMap, HashSet}};

pub(crate) const MAX_OWNERS: usize = 64;
pub(crate) const MAX_METHODS: usize = 2048;
pub(crate) const MAX_PAGE: usize = 16;
const MAX_INPUT: usize = 2 * 1024 * 1024;
const MAX_OUTPUT: usize = 64 * 1024;
const WORK_VISITS: usize = 20_000;
const WORK_BYTES: usize = 32 * 1024 * 1024;
// Candidate traversal cannot spend the compact projection's worst-case reserve:
// at most 16 shrinking encodings of at most 16 row/candidate slots.
const PROJECTION_VISITS: usize = 1024;
const PROJECTION_BYTES: usize = 8 * 1024 * 1024;

pub(crate) struct Query<'a> {
    pub id: &'a str, pub family: &'a str, pub limit: usize, pub cursor: Option<&'a Value>, pub max_bytes: usize,
}
impl<'a> Query<'a> {
    pub(crate) fn parse(request: &'a Value) -> Result<Self> {
        let id = schema::hash(schema::string(request,"id")?)?;
        let family = match request.get("family") {
            None | Some(Value::Null) => "contributions",
            Some(value) => value.as_str().filter(|s| ["contributions","methods"].contains(s))
                .ok_or_else(|| CoreError::input("Unknown source comprehension family"))?,
        };
        let limit = match request.get("limit") {
            None => 8,
            Some(value) => value.as_u64().filter(|n| *n>0 && *n<=MAX_PAGE as u64)
                .ok_or_else(|| CoreError::input("Invalid source comprehension page limit"))? as usize,
        };
        let max_bytes = match request.get("max_bytes") {
            None => 32768,
            Some(value) => value.as_u64().filter(|n| *n>0 && *n<=MAX_OUTPUT as u64)
                .ok_or_else(|| CoreError::input("Invalid source comprehension byte limit"))? as usize,
        };
        Ok(Self { id,family,limit,cursor:request.get("cursor"),max_bytes })
    }
    pub(crate) fn scratch(&self) -> usize { 8 * 1024 * 1024 }
    pub(crate) fn position(&self, generation: &str) -> Result<(usize,usize)> {
        recorded_domain::position(self.cursor,generation,&json!(["source_comprehension",self.id,self.family]))
    }
}

fn label(value: &Value, nullable: bool) -> Result<()> {
    if nullable && value.is_null() { return Ok(()); }
    match value.as_str() {
        Some(s) if !s.is_empty() && s.len() <= 4096 => Ok(()),
        _ => Err(CoreError::input("Invalid ownership label")),
    }
}
fn hint(value: &Value) -> Result<()> {
    if value.is_null() { return Ok(()); }
    schema::model_object(value, &["path", "line"])?;
    label(&value["path"], false)?;
    if !value["line"].as_u64().is_some_and(|n| n > 0 && n <= u32::MAX as u64) {
        return Err(CoreError::input("Invalid ownership source hint line"));
    }
    Ok(())
}

/// Validates raw descriptors, including anonymous owners and explicit undef gaps.
/// Order is observed Ruby ancestry, never an inferred source include order.
pub(crate) fn validate_observation(data: &Value) -> Result<usize> {
    schema::depth(data)?;
    schema::encoded_bytes(data, MAX_INPUT)?;
    schema::model_object(data, &["name", "status", "superclass", "stop_before", "ancestors", "effective_methods"])?;
    for key in ["name", "superclass", "stop_before"] { label(&data[key], true)?; }
    if data["status"] != "observed" { return Err(CoreError::input("Invalid ownership status")); }
    let owners = schema::array(data, "ancestors")?;
    let methods = schema::array(data, "effective_methods")?;
    if owners.len() > MAX_OWNERS || methods.len() > MAX_METHODS { return Err(CoreError::limit("Ownership inventory exceeds allowance")); }
    let mut entries = owners.len();
    let mut names = HashSet::new();
    let mut direct_sources = Vec::with_capacity(owners.len());
    for (index, owner) in owners.iter().enumerate() {
        schema::model_object(owner, &["index", "name", "kind", "methods"])?;
        label(&owner["name"], true)?;
        if owner["index"].as_u64() != Some(index as u64) || !matches!(owner["kind"].as_str(), Some("class" | "module")) {
            return Err(CoreError::input("Invalid ownership ancestor"));
        }
        let mut direct = HashMap::new();
        let rows = schema::array(owner, "methods")?;
        entries = entries.checked_add(rows.len()).filter(|n| *n <= 100_000)
            .ok_or_else(|| CoreError::limit("Ownership entries exceed allowance"))?;
        for method in rows {
            schema::model_object(method, &["name", "visibility", "source"])?;
            label(&method["name"], false)?;
            let name = method["name"].as_str().unwrap();
            if direct.insert(name, &method["source"]).is_some() || !matches!(method["visibility"].as_str(), Some("public" | "protected" | "private")) {
                return Err(CoreError::input("Duplicate or invalid ownership method"));
            }
            names.insert(name);
            if names.len() > MAX_METHODS { return Err(CoreError::limit("Ownership names exceed allowance")); }
            hint(&method["source"])?;
        }
        direct_sources.push(direct);
    }
    let mut seen = HashSet::new();
    for method in methods {
        schema::model_object(method, &["name", "owner_index", "source"])?;
        label(&method["name"], false)?;
        let name = method["name"].as_str().unwrap();
        if !names.contains(name) || !seen.insert(name) { return Err(CoreError::input("Invalid effective ownership name")); }
        hint(&method["source"])?;
        if method["owner_index"].is_null() {
            if !method["source"].is_null() { return Err(CoreError::input("Unknown owner cannot supply a source hint")); }
        } else {
            let index = method["owner_index"].as_u64().filter(|i| *i < owners.len() as u64)
                .ok_or_else(|| CoreError::input("Invalid effective owner index"))? as usize;
            let source = direct_sources[index].get(name)
                .ok_or_else(|| CoreError::input("Effective owner does not define method"))?;
            if **source != method["source"] { return Err(CoreError::input("Effective descriptor hint disagrees")); }
        }
    }
    if seen != names { return Err(CoreError::input("Incomplete effective ownership inventory")); }
    entries.checked_add(methods.len()).filter(|n| *n <= 100_000)
        .ok_or_else(|| CoreError::limit("Ownership combined entries exceed allowance"))
}

fn normalize_hints(data: &mut Value, root: &str) {
    fn normalize(row: &mut Value, root: &str) {
        if let Some(path) = row["source"]["path"].as_str() {
            // Ruby eval/internal/relative pseudo-locations are not physical
            // in-root evidence. Only an absolute root-prefixed path is eligible.
            let path = path.strip_prefix(root).and_then(|tail| tail.strip_prefix('/'));
            row["source"] = match path.filter(|path| schema::path(path).is_ok()) {
                Some(path) => json!({"path":path,"line":row["source"]["line"]}),
                None => Value::Null,
            };
        }
    }
    for owner in data["ancestors"].as_array_mut().unwrap() {
        for method in owner["methods"].as_array_mut().unwrap() { normalize(method,root); }
    }
    for method in data["effective_methods"].as_array_mut().unwrap() { normalize(method,root); }
}

pub(crate) fn batch(context: &Value, observation: &Value, root: &str) -> Result<Value> {
    if !root.starts_with('/') || root.contains('\0') || root.split('/').skip(1).any(|part| part.is_empty() || part=="." || part=="..") {
        return Err(CoreError::input("Expected normalized absolute ownership root without trailing slash"));
    }
    schema::depth(observation)?;
    schema::encoded_bytes(observation, schema::MAX_FACTS_BYTES)?;
    schema::model_object(observation, &["version", "models"])?;
    if observation["version"] != 1 { return Err(CoreError::input("Unknown ownership observation version")); }
    let models = schema::array(observation, "models")?;
    let mut admission = schema::ObservationAdmission::new(context)?;
    admission.ensure_facts(models.len())?;
    let mut facts = Vec::with_capacity(models.len());
    for (ordinal, data) in models.iter().enumerate() {
        let entries = validate_observation(data)?;
        // Registry ordinals distinguish duplicate/anonymous labels; not source identity.
        let id = schema::digest(&schema::canonical(&json!(["rails_source_ownership", 1, ordinal, data["name"]]))?);
        let mut fact = json!({"id":id,"kind":"rails_source_ownership","name":data["name"].as_str().unwrap_or("Anonymous model"),
            "evidence":"runtime","path":null,"location":null,"links":[],
            "attributes":{"source_comprehension":{"version":1,"ordinal":ordinal,"observation":null}}});
        // Input is sized and validated before this sole bounded tree copy.
        let mut data = data.clone();
        normalize_hints(&mut data,root);
        fact["attributes"]["source_comprehension"]["observation"] = data;
        admission.admit(&fact, entries)?;
        facts.push(fact);
    }
    let mut out = json!({"appended":admission.appended(),"source_comprehension_observer":{"version":1,
        "scope":"Explicit loaded classes before supplied stop boundary; builtin descriptors only; source/runtime coherence unknown"},
        "coverage":[{"family":"source_ownership","status":"partial",
        "scope":"Explicit loaded classes, builtin instance-method descriptors before a supplied stop boundary; no method execution",
        "reason":"Ordered loaded ancestry and hints only. Saved-source coherence, conditions, dispatch and execution unknown."}]});
    out["facts"] = Value::Array(facts);
    Ok(out)
}

pub(crate) fn validate_fact(fact: &Value) -> Result<()> {
    if fact["kind"] != "rails_source_ownership" || fact["evidence"] != "runtime" || !fact["path"].is_null() ||
        !fact["location"].is_null() || !schema::array(fact,"links")?.is_empty() {
        return Err(CoreError::input("Invalid ownership fact provenance"));
    }
    schema::model_object(&fact["attributes"], &["source_comprehension"])?;
    let data = &fact["attributes"]["source_comprehension"];
    schema::model_object(data, &["version", "ordinal", "observation"])?;
    if data["version"] != 1 || data["ordinal"].as_u64().is_none() { return Err(CoreError::input("Unknown ownership fact version")); }
    validate_observation(&data["observation"])?;
    let observation = &data["observation"];
    for method in observation["ancestors"].as_array().unwrap().iter().flat_map(|row| row["methods"].as_array().unwrap())
        .chain(observation["effective_methods"].as_array().unwrap()) {
        if let Some(path) = method["source"]["path"].as_str() { schema::path(path)?; }
    }
    let name = data["observation"]["name"].as_str().unwrap_or("Anonymous model");
    let expected = schema::digest(&schema::canonical(&json!(["rails_source_ownership",1,data["ordinal"],data["observation"]["name"]]))?);
    if fact["id"] != expected || fact["name"] != name { return Err(CoreError::input("Ownership identity disagrees")); }
    Ok(())
}

fn identity(fact: &Value) -> Value {
    json!({"id":fact["id"],"kind":fact["kind"],"name":fact["name"],"evidence":fact["evidence"],"path":fact["path"],"location":fact["location"]})
}

/// Borrowed request-local lookup over already publish/open-validated immutable
/// facts. No fact revalidation, ownership-group encoding cap or retained index.
struct Inventory<'a> {
    owners: &'a [Value], labels: HashMap<&'a str, usize>,
    effective: HashMap<&'a str, &'a Value>, methods: usize,
}
impl<'a> Inventory<'a> {
    fn new(owners: &'a [Value], observed: Option<&'a Value>, work: &mut Work) -> Result<Self> {
        let mut labels = HashMap::new();
        let mut methods = 0;
        for owner in owners {
            let name = owner["name"].as_str();
            work.scan(name.map_or(0,str::len))?;
            if let Some(name) = name { *labels.entry(name).or_insert(0) += 1; }
            // Array lengths are constant-time; do not walk every direct method.
            methods += owner["methods"].as_array().unwrap().len();
        }
        let mut effective = HashMap::new();
        if let Some(observed) = observed {
            for method in observed["effective_methods"].as_array().unwrap() {
                let name = method["name"].as_str().unwrap();
                work.scan(name.len())?;
                effective.insert(name,method);
            }
        }
        Ok(Self { owners,labels,effective,methods })
    }
    fn row(&self, family: &str, label: &str, row: usize, work: &mut Work) -> Result<(&'a Value, Option<&'a Value>)> {
        if family=="contributions" {
            let mut direct = None;
            for (index,owner) in self.owners.iter().enumerate() {
                let name = owner["name"].as_str();
                work.scan(name.map_or(0,str::len).saturating_add(label.len()))?;
                if name==Some(label) { direct=Some(index); break; }
            }
            // Model declaration first; original owner indexes/order stay intact.
            let index = match direct {
                Some(direct) if row==0 => direct,
                Some(direct) if row<=direct => row-1,
                _ => row,
            };
            return Ok((&self.owners[index],None));
        }
        let mut position = row;
        for owner in self.owners {
            work.scan(0)?;
            let methods = owner["methods"].as_array().unwrap();
            if position<methods.len() { return Ok((owner,Some(&methods[position]))); }
            position-=methods.len();
        }
        Err(CoreError::input("Invalid source comprehension method position"))
    }
}

struct Selected<'a> {
    owner: &'a Value, method: Option<&'a Value>, row: usize, offset: usize,
    positions: Vec<usize>, matches_seen: usize, complete: bool, partial: bool,
    status: &'static str, next: Option<(usize,usize)>,
}

// A later row can retry with a fresh request budget. Never emit a cursor
// back to an unchanged first row when this request has made no progress.
fn defer_row_after_progress(selected: &mut [Selected<'_>], row: usize, offset: usize) -> bool {
    if let Some(last) = selected.last_mut() {
        last.next = Some((row,offset));
        true
    } else { false }
}

fn project_page(generation: &str, model: &Value, ownership: &[&Value], inventory: &Inventory<'_>,
    selected: &[Selected<'_>], facts: &[Value], work: &mut Work) -> Result<Value> {
    work.scan(model["name"].as_str().map_or(0,str::len) + model["path"].as_str().map_or(0,str::len) + 64 * (ownership.len()+1))?;
    let mut contributions = Vec::new();
    let mut outline = Vec::with_capacity(selected.len());
    let mut owners = Vec::new();
    let mut owner_indexes = HashSet::new();
    let mut matches_seen = 0;
    let mut range_complete = true;
    let mut page_complete = true;
    let mut observed_only = Vec::new();
    for row in selected {
        let owner_label = row.owner["name"].as_str();
        let method_name = row.method.and_then(|method| method["name"].as_str());
        work.scan(owner_label.map_or(0,str::len).saturating_add(method_name.map_or(0,str::len)))?;
        if owner_indexes.insert(row.owner["index"].as_u64().unwrap()) {
            owners.push(json!({"index":row.owner["index"],"name":row.owner["name"],"kind":row.owner["kind"]}));
        }
        let complete = row.complete && row.offset==0 && row.positions.len()==row.matches_seen;
        matches_seen += row.matches_seen;
        range_complete &= row.complete;
        page_complete &= complete;
        outline.push(json!({"row":row.row,"owner_index":row.owner["index"],"owner":row.owner["name"],
            "method_name":method_name,"visibility":row.method.map(|method| &method["visibility"]),
            "status":row.status,"candidate_matches_seen":row.matches_seen,"offset":row.offset,
            "returned":row.positions.len(),"range_complete":row.complete,"partial":row.partial}));
        for position in &row.positions {
            let fact = &facts[*position];
            let name = fact["attributes"]["method_name"].as_str();
            let effective = name.and_then(|name| inventory.effective.get(name).copied());
            let effective_owner = effective.and_then(|method| method["owner_index"].as_u64())
                .and_then(|index| inventory.owners.get(index as usize));
            // Meter copied labels/hints, not full immutable fact trees.
            let bytes = [fact["name"].as_str(),fact["path"].as_str(),owner_label,name,
                effective_owner.and_then(|owner| owner["name"].as_str()),
                effective.and_then(|method| method["source"]["path"].as_str())]
                .into_iter().flatten().map(str::len).sum();
            work.scan(bytes)?;
            let status = if fact["evidence"]!="static" { "unknown_precedence" }
                else if fact["kind"]!="method" { "as_written_declaration" }
                else if !complete { "unknown_incomplete_candidates" }
                else if fact["attributes"]["name_resolution"]!="lexical" { "unknown_precedence" }
                else if row.positions.len()>1 { "ambiguous_definitions" }
                else if effective_owner.is_some_and(|owner| owner["name"].as_str()==owner_label) { "observed_loaded_owner_source_binding_unknown" }
                else if effective_owner.is_some() { "alternative_to_observed_loaded_owner" }
                else { "unknown_precedence" };
            contributions.push(json!({"fact":identity(fact),"owner":owner_label,"method_name":name,"status":status,
                "observed_owner":effective_owner.map(|owner| &owner["name"]),
                "observed_source_hint":effective.map(|method| &method["source"]),
                "source":{"operation":"source","generation":generation,"id":fact["id"]},
                "callers":{"operation":"references","generation":generation,"id":fact["id"],"direction":"incoming","cursor":null}}));
        }
        if row.positions.is_empty() && row.complete && row.offset==0 {
            if let Some(method) = row.method {
                work.scan(method["source"]["path"].as_str().map_or(0,str::len))?;
                observed_only.push(json!({"name":method["name"],"owner":row.owner["name"],"owner_index":row.owner["index"],
                    "visibility":method["visibility"],"source_hint":method["source"],"status":row.status,
                    "source_runtime_coherence":"unknown"}));
            }
        }
    }
    owners.sort_unstable_by_key(|owner| owner["index"].as_u64().unwrap());
    Ok(json!({"version":1,"generation":generation,"model":identity(model),"owner":model["name"],
        "composition":"identified_contributions","source_runtime_coherence":"unknown",
        "ownership_status":if ownership.len()==1 {"unique_label_candidate_binding_unknown"} else if ownership.is_empty() {"unavailable"} else {"ambiguous"},
        "ownership_evidence_ids":ownership.iter().map(|fact| &fact["id"]).collect::<Vec<_>>(),
        "owners":owners,"rows":outline,"contributions":contributions,"observed_only":observed_only,
        "coverage":{"candidate_matches_seen":matches_seen,"range_complete":range_complete,"returned":contributions.len(),"page_complete":page_complete,
            "scope":"Selected owner/method rows and bounded indexed candidates; per-row witnesses are not whole-family totals. Labels do not establish runtime binding; owners shown are page-local."},
        "continuation":null,
        "semantics":"Separate as-written contributions, not a concatenated effective runtime class. Loaded owner is observed; saved-source binding, conditions, invocation and execution remain unknown."}))
}

#[derive(Default)]
struct Work { visits: usize, comparisons: usize, bytes: usize }
impl Work {
    fn scan(&mut self, bytes: usize) -> Result<()> {
        if self.visits>=WORK_VISITS || bytes>WORK_BYTES.saturating_sub(self.bytes) {
            return Err(CoreError::limit("Ownership projection work exhausted"));
        }
        self.visits+=1; self.bytes+=bytes;
        Ok(())
    }
}
impl method_lookup::Work for Work {
    fn visit(&mut self) -> bool {
        if self.visits>=WORK_VISITS-PROJECTION_VISITS { return false; } self.visits+=1; true
    }
    fn bytes(&mut self, bytes: usize) -> bool {
        if bytes> (WORK_BYTES-PROJECTION_BYTES).saturating_sub(self.bytes) { return false; } self.bytes+=bytes; true
    }
    fn compare(&mut self, a: &str, b: &str) -> Option<Ordering> {
        if self.comparisons==100_000 || !self.bytes(a.len().saturating_add(b.len())) { return None; }
        self.comparisons+=1; Some(a.cmp(b))
    }
    fn compare_digest(&mut self, a: &[u8;32], b: &[u8;32]) -> Option<Ordering> {
        if self.comparisons==100_000 || !self.bytes(64) { return None; }
        self.comparisons+=1; Some(a.cmp(b))
    }
}
impl recorded_domain::LabelWork for Work {
    fn compare(&mut self, a: &str, b: &str) -> Result<Ordering> {
        method_lookup::Work::compare(self,a,b).ok_or_else(|| CoreError::limit("Ownership label work exhausted"))
    }
}

/// Up to limit logical rows/candidate positions per response. An empty or unknown
/// row consumes one slot, so generated methods advance in bounded groups. The
/// unchanged two-coordinate cursor names the next row and its candidate offset.
/// No source I/O; method-directory locks end before response construction.
pub(crate) fn select(reader: &Reader, query: &Query<'_>) -> Result<Value> {
    select_with_work(reader,query,Work::default())
}

fn select_with_work(reader: &Reader, query: &Query<'_>, mut work: Work) -> Result<Value> {
    let root = reader.stored_fact(query.id)?;
    if !matches!(root["kind"].as_str(),Some("rails_model" | "class")) { return Err(CoreError::input("Expected saved model or class")); }
    let label = if root["kind"]=="rails_model" { root["attributes"]["model"]["name"].as_str() } else { root["name"].as_str() };
    let label = label.ok_or_else(|| CoreError::input("Anonymous model source composition is unavailable"))?;
    let (registries,registry_stats) = reader.recorded_candidates(label,Some("rails_source_ownership"),0,2,&mut work)?;
    let ownership = registries.positions.iter().map(|index| &reader.facts[*index]).collect::<Vec<_>>();
    // Reader open and publication already validated these immutable pinned facts.
    // A two-element witness is ambiguity, never an ownership-group size refusal.
    let observed = (registries.total==1).then(|| &ownership[0]["attributes"]["source_comprehension"]["observation"]);
    let fallback = json!([{"index":0,"name":label,"kind":"class","methods":[]}]);
    let owners = observed.map_or(&fallback, |data| &data["ancestors"]).as_array().unwrap();
    let inventory = Inventory::new(owners,observed,&mut work)?;
    let rows = if query.family=="contributions" { owners.len() } else { inventory.methods };
    let (mut row,mut offset) = query.position(&reader.generation)?;
    let start = row;
    if row>=rows && !(row==0 && rows==0) { return Err(CoreError::input("Source comprehension cursor is beyond family")); }
    if rows==0 && offset!=0 { return Err(CoreError::input("Invalid empty-family candidate offset")); }
    let mut selected = Vec::with_capacity(query.limit);
    let mut slots = 0;
    let mut method_stats = Value::Null;
    let mut work_deferred = false;
    while row<rows && slots<query.limit {
        let (selected_owner,method) = inventory.row(query.family,label,row,&mut work)?;
        let owner = selected_owner["name"].as_str();
        let status = match owner {
            None => "anonymous_owner_no_label_candidate",
            Some(owner) if inventory.labels.get(owner).copied().unwrap_or(0)>1 => "duplicate_owner_label_unknown",
            _ => "no_saved_definition_candidate",
        };
        let (positions,matches_seen,complete,partial,next_offset) = if status!="no_saved_definition_candidate" {
            if offset!=0 { return Err(CoreError::input("Unknown owner row has no candidate offset")); }
            (Vec::new(),0,false,false,None)
        } else if let Some(method) = method {
            let name = method["name"].as_str().unwrap();
            let result = reader.with_method_directory(query::budget(), |directory,built| {
                (directory.page(&reader.facts,owner.unwrap(),name,offset,query.limit-slots,&mut work),directory.stats(built).value())
            }).and_then(|(page,stats)| page.map(|page| (page,stats)));
            let (page,stats) = match result {
                Ok(page) => page,
                Err(error) if error.code=="limit_exceeded" && defer_row_after_progress(&mut selected,row,offset) => {
                    work_deferred=true; break;
                },
                Err(error) => return Err(error),
            };
            if method_stats.is_null() { method_stats=stats; }
            (page.positions,page.matches_seen,page.range_complete,page.partial,page.next_offset)
        } else {
            let kind = if selected_owner["kind"]=="module" {"module"} else {"class"};
            let (page,_) = match reader.recorded_candidates(owner.unwrap(),Some(kind),offset,query.limit-slots,&mut work) {
                Ok(page) => page,
                Err(error) if error.code=="limit_exceeded" && defer_row_after_progress(&mut selected,row,offset) => {
                    work_deferred=true; break;
                },
                Err(error) => return Err(error),
            };
            if offset>page.total { return Err(CoreError::input("Contribution cursor exceeds candidate range")); }
            let next = offset+page.positions.len();
            (page.positions,page.total,next==page.total,false,(next<page.total).then_some(next))
        };
        if partial && positions.is_empty() && defer_row_after_progress(&mut selected,row,offset) {
            work_deferred=true; break;
        }
        let next = next_offset.map(|offset| (row,offset)).or_else(|| (!partial && row+1<rows).then_some((row+1,0)));
        slots += positions.len().max(1);
        let status = if positions.is_empty() {status} else {"saved_candidates"};
        selected.push(Selected { owner:selected_owner,method,row,offset,positions,matches_seen,complete,partial,status,next });
        match next {
            Some((next_row,next_offset)) if next_row>row => { row=next_row; offset=next_offset; },
            _ => break, // candidate suffix or zero-progress Work exhaustion
        }
    }
    // Encode only compact bounded projections. If the byte budget cuts a row,
    // retain its exact suffix cursor; no successful row/candidate is skipped.
    loop {
        let mut out = project_page(&reader.generation,root,&ownership,&inventory,&selected,&reader.facts,&mut work)?;
        out["family"] = json!(query.family);
        out["coverage"]["family_rows"] = json!(rows);
        out["coverage"]["row"] = json!(start);
        out["coverage"]["rows_returned"] = json!(selected.len());
        out["coverage"]["partial"] = json!(work_deferred || selected.iter().any(|row| row.partial));
        if rows==0 { out["coverage"]["reason"] = json!("no_observed_method_inventory_not_evidence_of_absence"); }
        if let Some(position) = selected.last().and_then(|row| row.next) {
            let cursor = recorded_domain::cursor(&reader.generation,&json!(["source_comprehension",query.id,query.family]),position)?;
            out["continuation"] = json!({"operation":"source_comprehension","id":query.id,"generation":reader.generation,"family":query.family,"cursor":cursor});
        }
        match finish(out,query,&work,registry_stats.clone(),method_stats.clone()) {
            Ok(out) => return Ok(out),
            Err(error) => {
                if let Some(last) = selected.last_mut() {
                    if last.positions.len()>1 {
                        last.positions.pop(); last.complete=false;
                        last.next=Some((last.row,last.offset+last.positions.len()));
                        continue;
                    }
                }
                if selected.len()<=1 { return Err(error); }
                let removed = selected.pop().unwrap();
                selected.last_mut().unwrap().next=Some((removed.row,removed.offset));
            }
        }
    }
}

fn finish(mut out: Value, query: &Query<'_>, work: &Work, registry_stats: Value, method_stats: Value) -> Result<Value> {
    out["usage"] = json!({"candidate_fact_visits":work.visits,"label_comparisons":work.comparisons,"label_bytes":work.bytes,
        "recorded_directory":registry_stats,"method_directory":method_stats,"source_reads":0,
        "projection_work_reservation":{"visits":PROJECTION_VISITS,"label_bytes":PROJECTION_BYTES},
        "scratch_reservation":query.scratch(),"max_wire_bytes":query.max_bytes,
        "scope":"Visits include observation scans, row selection, compact projection copies and candidate visits; compared/hashed/copied label bytes are charged. Reader open and lazy directory construction are separate; no latency or RSS claim"});
    // Output counting precedes native envelope serialization. The dispatch owns
    // its existing envelope/bridge reservation; keep one newline byte here.
    schema::encoded_bytes(&out,query.max_bytes.saturating_sub(1))?;
    Ok(out)
}

#[cfg(test)]
#[path = "source_comprehension_tests.rs"]
mod tests;
