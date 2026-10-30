//! Schema-bound call-link storage projection and borrowed semantic access.
//!
//! Capture/publication input is always semantic. Only stored schema-3 links may
//! be rows. Source bounds and whole-capture validation remain owned by schema;
//! this module reuses its call decoder/shape checks, never reconstructing an
//! owned extension to validate a row. No expanded dataset is retained here.

use crate::{error::{CoreError, Result}, schema};
use serde::{ser::{Error as _, SerializeMap, SerializeSeq, SerializeTuple}, Serialize, Serializer};
use serde_json::{Map, Value};

const CALL_TAG: u64 = 0;

enum Representation<'a> {
    Object(&'a Value),
    Call { target: &'a Value, data: &'a Value },
}

/// Borrowed semantic fields for validation, ordering and requested output.
/// Constructors distinguish semantic input from stored wire input explicitly.
pub(crate) struct SemanticLinkView<'a> {
    representation: Representation<'a>,
    relation: &'a str,
    target: &'a str,
    resolution: &'a str,
    call: Option<schema::CallMetadata<'a>>,
}

fn context(version: u64, evidence: &str) -> Result<()> {
    if !matches!(version, 1 | 2 | 3) {
        return Err(CoreError::input("Unsupported snapshot schema"));
    }
    if !matches!(evidence, "static" | "runtime") {
        return Err(CoreError::input("Fact evidence must be static or runtime"));
    }
    Ok(())
}

fn label(value: &Value, key: &str) -> Result<()> {
    let text = value.as_str().ok_or_else(|| CoreError::input(format!("{key} must be a string")))?;
    if text.is_empty() || text.len() > 4096 {
        return Err(CoreError::input("Invalid link label or target"));
    }
    Ok(())
}

fn has_exact_keys(value: &Value, keys: &[&str]) -> bool {
    value.as_object().is_some_and(|object|
        object.len() == keys.len() && keys.iter().all(|key| object.contains_key(*key)))
}

impl<'a> SemanticLinkView<'a> {
    pub(crate) fn from_semantic(link: &'a Value, version: u64, evidence: &str) -> Result<Self> {
        context(version, evidence)?;
        if !link.is_object() { return Err(CoreError::input("Semantic links must be objects")); }
        for key in ["relation", "target"] { label(&link[key], key)?; }
        let resolution = schema::string(link, "resolution")?;
        if !matches!(resolution, "resolved" | "unresolved") {
            return Err(CoreError::input("Link resolution must be explicit"));
        }
        let call = link.get("attributes").and_then(|attrs| attrs.get("thistle_call"))
            .map(|ext| schema::call_metadata(ext, version)).transpose()?.flatten();
        if let Some(call) = &call {
            if link["relation"] != "calls" || resolution != "unresolved" || evidence != "static" {
                return Err(CoreError::input("Invalid call metadata shape"));
            }
            schema::validate_call_shape(call)?;
        }
        Ok(Self { representation: Representation::Object(link), relation: schema::string(link, "relation")?,
            target: schema::string(link, "target")?, resolution, call })
    }

    pub(crate) fn from_wire(link: &'a Value, version: u64, evidence: &str) -> Result<Self> {
        context(version, evidence)?;
        if link.is_object() { return Self::from_semantic(link, version, evidence); }
        if version != 3 || evidence != "static" {
            return Err(CoreError::input("Tagged call links require schema 3 and static evidence"));
        }
        let row: &[Value; 3] = link.as_array().and_then(|values| values.as_slice().try_into().ok())
            .ok_or_else(|| CoreError::input("Tagged call link must have three fields"))?;
        if row[0].as_u64() != Some(CALL_TAG) {
            return Err(CoreError::input("Unknown call link tag"));
        }
        label(&row[1], "target")?;
        let call = schema::compact_call_metadata(&row[2])?;
        schema::validate_call_shape(&call)?;
        Ok(Self { representation: Representation::Call { target: &row[1], data: &row[2] },
            relation: "calls", target: row[1].as_str().expect("validated target"),
            resolution: "unresolved", call: Some(call) })
    }

    pub(crate) fn relation(&self) -> &'a str { self.relation }
    pub(crate) fn target(&self) -> &'a str { self.target }
    pub(crate) fn resolution(&self) -> &'a str { self.resolution }
    pub(crate) fn call_metadata(&self) -> Option<&schema::CallMetadata<'a>> { self.call.as_ref() }

    fn compact_parts(&self, version: u64) -> Option<(&'a Value, &'a Value)> {
        if version != 3 || self.call.is_none() { return None; }
        match self.representation {
            Representation::Call { target, data } => Some((target, data)),
            Representation::Object(link) => {
                let attrs = &link["attributes"];
                let ext = &attrs["thistle_call"];
                (has_exact_keys(link, &["relation", "target", "resolution", "attributes"])
                    && has_exact_keys(attrs, &["thistle_call"])
                    && has_exact_keys(ext, &["version", "data"])
                    && ext["version"].as_u64() == Some(2))
                    .then_some((&link["target"], &ext["data"]))
            }
        }
    }

    pub(crate) fn materialize(&self) -> Result<Value> { Ok(serde_json::to_value(self)?) }
}

/// Serializing a view always produces the public semantic object, never a row.
impl Serialize for SemanticLinkView<'_> {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        match self.representation {
            Representation::Object(link) => link.serialize(serializer),
            Representation::Call { target, data } => {
                #[derive(Serialize)]
                struct Extension<'a> { data: &'a Value, version: u64 }
                #[derive(Serialize)]
                struct Attributes<'a> { thistle_call: Extension<'a> }
                // Match canonical Value map order, including the nested extension.
                let mut map = serializer.serialize_map(Some(4))?;
                map.serialize_entry("attributes", &Attributes { thistle_call: Extension { data, version: 2 } })?;
                map.serialize_entry("relation", "calls")?;
                map.serialize_entry("resolution", "unresolved")?;
                map.serialize_entry("target", target)?;
                map.end()
            }
        }
    }
}

/// The same borrowed serializer is used for per-link charging and publication.
/// Construction accepts semantic objects only, even for explicit schema 3.
pub(crate) struct WireLink<'a> {
    view: SemanticLinkView<'a>,
    version: u64,
}

impl<'a> WireLink<'a> {
    pub(crate) fn new(link: &'a Value, version: u64, evidence: &str) -> Result<Self> {
        Ok(Self { view: SemanticLinkView::from_semantic(link, version, evidence)?, version })
    }
}

impl Serialize for WireLink<'_> {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        if let Some((target, data)) = self.view.compact_parts(self.version) {
            let mut row = serializer.serialize_tuple(3)?;
            row.serialize_element(&CALL_TAG)?;
            row.serialize_element(target)?;
            row.serialize_element(data)?;
            row.end()
        } else {
            self.view.serialize(serializer)
        }
    }
}

/// A fact projection borrows all entries and replaces only its links sequence.
struct FactView<'a> {
    object: &'a Map<String, Value>,
    links: &'a [Value],
    evidence: &'a str,
    version: u64,
}

impl<'a> FactView<'a> {
    fn new(fact: &'a Value, version: u64) -> Result<Self> {
        let evidence = schema::string(fact, "evidence")?;
        context(version, evidence)?;
        Ok(Self { object: fact.as_object().ok_or_else(|| CoreError::input("Fact must be an object"))?,
            links: schema::array(fact, "links")?, evidence, version })
    }

    fn serialize<S: Serializer>(&self, serializer: S, wire: bool) -> std::result::Result<S::Ok, S::Error> {
        let mut map = serializer.serialize_map(Some(self.object.len()))?;
        for (key, value) in self.object {
            if key == "links" { map.serialize_entry(key, &Links { fact: self, wire })?; }
            else { map.serialize_entry(key, value)?; }
        }
        map.end()
    }
}

struct Links<'a, 'b> { fact: &'a FactView<'b>, wire: bool }

impl Serialize for Links<'_, '_> {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        let mut seq = serializer.serialize_seq(Some(self.fact.links.len()))?;
        for link in self.fact.links {
            if self.wire {
                let link = WireLink::new(link, self.fact.version, self.fact.evidence).map_err(S::Error::custom)?;
                seq.serialize_element(&link)?;
            } else {
                let link = SemanticLinkView::from_wire(link, self.fact.version, self.fact.evidence).map_err(S::Error::custom)?;
                seq.serialize_element(&link)?;
            }
        }
        seq.end()
    }
}

pub(crate) struct WireFact<'a>(FactView<'a>);

impl<'a> WireFact<'a> {
    pub(crate) fn new(fact: &'a Value, version: u64) -> Result<Self> { Ok(Self(FactView::new(fact, version)?)) }
}

impl Serialize for WireFact<'_> {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        self.0.serialize(serializer, true)
    }
}

/// The caller supplies facts in existing stable-ID publication order. Neither
/// this serializer nor the link view changes sorting/grouping/representatives.
pub(crate) struct WireFacts<'a> { facts: &'a [&'a Value], version: u64 }

impl<'a> WireFacts<'a> {
    pub(crate) fn new(facts: &'a [&'a Value], version: u64) -> Self { Self { facts, version } }
}

impl Serialize for WireFacts<'_> {
    fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
        // Also reject an unsupported context when the facts array is empty.
        context(self.version, "static").map_err(S::Error::custom)?;
        let mut seq = serializer.serialize_seq(Some(self.facts.len()))?;
        for fact in self.facts {
            let fact = WireFact::new(fact, self.version).map_err(S::Error::custom)?;
            seq.serialize_element(&fact)?;
        }
        seq.end()
    }
}

/// Expand just the requested stored fact. No retained expansion/cache, and no
/// initial clone of the compact links followed by a second expanded array.
pub(crate) fn materialize_fact(fact: &Value, version: u64) -> Result<Value> {
    struct SemanticFact<'a>(FactView<'a>);
    impl Serialize for SemanticFact<'_> {
        fn serialize<S: Serializer>(&self, serializer: S) -> std::result::Result<S::Ok, S::Error> {
            self.0.serialize(serializer, false)
        }
    }
    Ok(serde_json::to_value(SemanticFact(FactView::new(fact, version)?))?)
}

/// Links-only responses need not clone the rest of their owning fact.
pub(crate) fn materialize_links(fact: &Value, version: u64) -> Result<Value> {
    Ok(serde_json::to_value(Links { fact: &FactView::new(fact, version)?, wire: false })?)
}

#[cfg(test)]
#[path = "link_encoding_tests.rs"]
mod tests;
