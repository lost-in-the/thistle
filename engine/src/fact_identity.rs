//! One saved identity, with no relationship expansion or optional directory.
use crate::{error::Result, schema, store::Reader};
use serde::Serialize;
use serde_json::Value;

pub(crate) const MAX_OUTPUT: usize = 32 * 1024;
// Fixed-field Values, encoded response and C/Ruby copies; not complete heap/RSS.
pub(crate) const SCRATCH: usize = 512 * 1024;

pub(crate) fn id(request: &Value) -> Result<&str> {
    schema::hash(schema::string(request, "id")?)
}

#[derive(Serialize)]
struct Location<'a> {
    start_byte: &'a Value, end_byte: &'a Value,
    start_line: &'a Value, end_line: &'a Value,
}

#[derive(Serialize)]
struct Identity<'a> {
    id: &'a Value, kind: &'a Value, name: &'a Value, path: &'a Value,
    location: Option<Location<'a>>, evidence: &'a Value,
}

#[derive(Serialize)]
struct Response<'a> { generation: &'a str, fact: Identity<'a> }

fn project(generation: &str, fact: &Value) -> Result<Value> {
    let location = &fact["location"];
    let response = Response { generation, fact: Identity {
        id: &fact["id"], kind: &fact["kind"], name: &fact["name"], path: &fact["path"],
        location: (!location.is_null()).then(|| Location {
            start_byte: &location["start_byte"], end_byte: &location["end_byte"],
            start_line: &location["start_line"], end_line: &location["end_line"],
        }), evidence: &fact["evidence"],
    }};
    // Count borrowed, allowlisted fields before copying any label into output.
    // Attributes, links and unknown location fields are neither walked nor copied.
    schema::encoded_bytes(&response, MAX_OUTPUT)?;
    Ok(serde_json::to_value(response)?)
}

pub(crate) fn select(reader: &Reader, id: &str) -> Result<Value> {
    project(&reader.generation, reader.stored_fact(id)?)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn projection_is_allowlisted_and_null_location_is_explicit() {
        let fact = json!({"id":"b".repeat(64),"kind":"class","name":"Saved", "path":null,
            "evidence":"static","location":null,"attributes":{"private":"never copied"},
            "links":[{"target":"never resolved"}]});
        let result = project(&"a".repeat(64), &fact).unwrap();
        assert_eq!(result["fact"].as_object().unwrap().len(), 6);
        assert_eq!(result["fact"]["location"], Value::Null);
        assert!(result["fact"].get("attributes").is_none());
        assert!(result["fact"].get("links").is_none());
        let mut located = fact;
        located["location"] = json!({"start_byte":0,"end_byte":5,"start_line":1,"end_line":1,"unknown":"omitted"});
        assert_eq!(project("generation", &located).unwrap()["fact"]["location"],
            json!({"start_byte":0,"end_byte":5,"start_line":1,"end_line":1}));
    }

    #[test]
    fn escaped_encoded_bytes_are_bounded_before_projection() {
        let mut fact = json!({"id":"b".repeat(64),"kind":"class","name":"x","path":null,
            "evidence":"static","location":null});
        let base = schema::encoded_bytes(&project("generation", &fact).unwrap(), MAX_OUTPUT).unwrap();
        fact["name"] = json!("x".repeat(MAX_OUTPUT - base + 1));
        assert_eq!(schema::encoded_bytes(&project("generation", &fact).unwrap(), MAX_OUTPUT).unwrap(), MAX_OUTPUT);
        fact["name"] = json!("x".repeat(MAX_OUTPUT - base + 2));
        assert_eq!(project("generation", &fact).unwrap_err().code, "limit_exceeded");
        fact["name"] = json!("\u{0001}".repeat(4096));
        fact["kind"] = json!("\u{0002}".repeat(4096));
        assert_eq!(project("generation", &fact).unwrap_err().code, "limit_exceeded");
    }
}
