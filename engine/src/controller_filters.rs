//! Guarded process_action registration evidence, never an invocation order.
use crate::{error::{CoreError, Result}, schema};
use serde_json::{json, Value};
use std::path::{Path, Component};

fn reference(value: &Value, normalized: bool) -> Result<()> {
    match value["kind"].as_str() {
        Some("opaque"|"unavailable") => return schema::model_object(value,&["kind"]),
        Some("method") => {
            schema::model_object(value,&["kind","name","owner","source"])?;
            schema::string(value,"name")?; schema::model_label(&value["name"])?;
            schema::model_label(&value["owner"])?;
        },
        Some("proc") => schema::model_object(value,&["kind","source"])?,
        _ => return Err(CoreError::input("Invalid controller filter descriptor")),
    }
    if !value["source"].is_null() {
        schema::model_object(&value["source"],&["path","line"])?;
        let path = schema::string(&value["source"],"path")?;
        schema::model_label(&value["source"]["path"])?;
        if normalized { schema::path(path)?; }
        if !value["source"]["line"].as_u64().is_some_and(|n| n>0 && n<=u32::MAX as u64) {
            return Err(CoreError::input("Invalid controller filter source hint"));
        }
    }
    Ok(())
}
fn conditions(value: &Value) -> Result<usize> {
    if value.is_null() { return Ok(0); }
    let rows = value.as_array().ok_or_else(|| CoreError::input("Invalid filter conditions"))?;
    if rows.len()>100_000 { return Err(CoreError::limit("Filter condition limit")); }
    let mut count=rows.len();
    for row in rows {
        match row["kind"].as_str() {
            Some("opaque") => schema::model_object(row,&["kind"])?,
            Some("actions") => {
                schema::model_object(row,&["kind","mode","actions"])?;
                if !matches!(row["mode"].as_str(),Some("only"|"except")) { return Err(CoreError::input("Invalid filter action mode")); }
                let names=schema::array(row,"actions")?;
                count=count.checked_add(names.len()).filter(|n| *n<=100_000).ok_or_else(|| CoreError::limit("Filter action limit"))?;
                for name in names { if name.as_str().is_none() { return Err(CoreError::input("Filter action must be a label")); } schema::model_label(name)?; }
            },
            _ => return Err(CoreError::input("Invalid filter condition")),
        }
    }
    Ok(count)
}
fn controller(data: &Value, normalized: bool) -> Result<usize> {
    schema::model_object(data,&["name","superclass","status","entries"])?;
    schema::model_label(&data["name"])?; schema::model_label(&data["superclass"])?;
    let entries=schema::array(data,"entries")?;
    if entries.len()>100_000 { return Err(CoreError::limit("Controller filter entries limit")); }
    if !matches!(data["status"].as_str(),Some("observed"|"unavailable")) || data["status"]=="unavailable" && !entries.is_empty() {
        return Err(CoreError::input("Invalid controller filter coverage"));
    }
    let mut count=1usize;
    for entry in entries {
        schema::model_object(entry,&["kind","filter","if","unless","inherited"])?;
        if !(entry["kind"].is_null() || matches!(entry["kind"].as_str(),Some("before"|"after"|"around"))) ||
            !(entry["inherited"].is_null() || entry["inherited"].is_boolean()) {
            return Err(CoreError::input("Invalid controller filter row"));
        }
        reference(&entry["filter"],normalized)?;
        count=count.checked_add(1+conditions(&entry["if"])?+conditions(&entry["unless"])?).filter(|n| *n<=100_000)
            .ok_or_else(|| CoreError::limit("Controller registration work limit"))?;
    }
    Ok(count)
}
fn identity(data: &Value) -> Result<(String,String)> {
    let name=data["controller"]["name"].as_str().map(str::to_owned)
        .unwrap_or_else(|| format!("Anonymous controller {}",data["ordinal"]));
    Ok((schema::digest(&schema::canonical(&json!(["rails_controller_filters",1,data["ordinal"],data["controller"]["name"]]))?),name))
}
pub(crate) fn validate_fact(fact: &Value) -> Result<()> {
    schema::model_object(&fact["attributes"],&["controller_filters"])?;
    let data=&fact["attributes"]["controller_filters"];
    schema::model_object(data,&["version","ordinal","framework_version","coherence","controller"])?;
    if data["version"]!=1 || data["ordinal"].as_u64().is_none() || data["framework_version"]!="8.1.4" ||
        data["coherence"]!="unknown" || fact["kind"]!="rails_controller_filters" || fact["evidence"]!="runtime" ||
        !fact["path"].is_null() || !fact["location"].is_null() || fact["links"]!=json!([]) {
        return Err(CoreError::input("Invalid saved controller filter provenance"));
    }
    controller(&data["controller"],true)?;
    let (id,name)=identity(data)?;
    if fact["id"]!=id || fact["name"]!=name { return Err(CoreError::input("Invalid controller filter identity")); }
    Ok(())
}
pub(crate) fn batch(context: &Value, observation: &Value) -> Result<Value> {
    schema::depth(observation)?;
    schema::model_object(observation,&["version","framework_version","root","status","controllers"])?;
    schema::model_label(&observation["framework_version"])?;
    let root=schema::string(observation,"root")?;
    let controllers=schema::array(observation,"controllers")?;
    if observation["version"]!=1 || !matches!(observation["status"].as_str(),Some("observed"|"unavailable")) ||
        observation["status"]=="observed" && observation["framework_version"]!="8.1.4" ||
        observation["status"]=="unavailable" && !controllers.is_empty() {
        return Err(CoreError::input("Invalid controller filter observation"));
    }
    schema::encoded_bytes(observation,schema::MAX_FACTS_BYTES)?;
    let mut admission=schema::ObservationAdmission::new(context)?;
    admission.ensure_facts(controllers.len())?;
    let mut facts=Vec::with_capacity(controllers.len());
    for (ordinal,observed) in controllers.iter().enumerate() {
        let count=controller(observed,false)?;
        let mut observed=observed.clone();
        for row in observed["entries"].as_array_mut().unwrap() {
            if row["filter"]["source"].is_null() { continue; }
            let normalized=row["filter"]["source"]["path"].as_str().and_then(|text| {
                let path=Path::new(text);
                if !Path::new(root).is_absolute() || !path.is_absolute() || path.components().any(|p| matches!(p,Component::CurDir|Component::ParentDir)) { return None; }
                let relative=path.strip_prefix(root).ok()?.to_str()?;
                schema::path(relative).ok().map(str::to_owned)
            });
            row["filter"]["source"]=normalized.map(|path|json!({"path":path,"line":row["filter"]["source"]["line"]})).unwrap_or(Value::Null);
        }
        let data=json!({"version":1,"ordinal":ordinal,"framework_version":"8.1.4","coherence":"unknown","controller":observed});
        let (id,name)=identity(&data)?;
        let fact=json!({"id":id,"kind":"rails_controller_filters","name":name,"evidence":"runtime","path":null,"location":null,
            "attributes":{"controller_filters":data},"links":[]});
        validate_fact(&fact)?; admission.admit(&fact,count)?; facts.push(fact);
    }
    Ok(json!({"facts":facts,"appended":admission.appended(),"coverage":[{"family":"rails_controller_filters",
        "status":if observation["status"]=="observed" {"partial"} else {"unavailable"},
        "scope":"Explicit loaded controller registries only","reason":"Registration order, inherited descriptors and opaque conditions; no execution/coherence proof"}],
        "controller_filters_observer":{"version":1,"framework_version":observation["framework_version"]}}))
}

/// Registration applicability is syntax/metadata only, never condition execution.
pub(crate) fn applicability(row: &Value, action: &str) -> &'static str {
    let mut opaque=false;
    for (field,negated) in [("if",false),("unless",true)] {
        let Some(conditions)=row[field].as_array() else { opaque=true; continue; };
        for condition in conditions {
            if condition["kind"]!="actions" { opaque=true; continue; }
            let matched=condition["actions"].as_array().unwrap().iter().any(|name| name==action);
            // Rails ActionFilter#match? uses set membership for both modes;
            // the registry's if/unless slot owns negation. Never negate twice.
            if matched==negated { return "excluded_by_recorded_action_condition"; }
        }
    }
    if opaque {"opaque_conditions_unknown"} else {"action_applicable_conditions_not_executed"}
}

#[cfg(test)]
#[path="controller_filters_tests.rs"]
mod tests;
