use crate::{error::{CoreError, Result}, fs::Dir, schema, link_encoding};
use serde_json::{json, Value};
use std::{collections::HashMap, path::Path, sync::atomic::{AtomicU64, Ordering}};

static TEMP_SEQUENCE: AtomicU64 = AtomicU64::new(0);
pub(crate) const READER_BUDGET: usize = 128 * 1024 * 1024;

fn temporary(prefix: &str) -> String {
    let instant = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).unwrap_or_default().as_nanos();
    format!(".{prefix}-{}-{instant}-{}", std::process::id(), TEMP_SEQUENCE.fetch_add(1, Ordering::Relaxed))
}

fn after_commit(generation: &str, result: Result<()>) -> Result<()> {
    result.map_err(|_| CoreError::new("commit_uncertain", format!(
        "Generation {generation} was selected, but directory durability could not be confirmed. Reopen the store; do not assume the previous generation remains current."
    )))
}

pub fn publish(path: &Path, capture: &Value) -> Result<Value> {
    publish_with_reader_budget(path, capture, READER_BUDGET)
}

fn publish_with_reader_budget(path: &Path, capture: &Value, reader_budget: usize) -> Result<Value> {
    schema::capture(capture)?;
    let facts_bytes = {
        let mut facts: Vec<&Value> = schema::array(capture, "facts")?.iter().collect();
        facts.sort_by(|a, b| a["id"].as_str().cmp(&b["id"].as_str()));
        let version = schema::capture_version(capture)?;
        if version == 3 {
            schema::encoded_vec(&link_encoding::WireFacts::new(&facts, version), schema::MAX_FACTS_BYTES)
        } else {
            // Explicit legacy publication retains the original representation.
            schema::encoded_vec(&facts, schema::MAX_FACTS_BYTES)
        }.map_err(|error| if error.code == "limit_exceeded" { CoreError::limit("Facts exceed snapshot size limit") } else { error })?
    };
    if facts_bytes.len() > schema::MAX_FACTS_BYTES { return Err(CoreError::limit("Facts exceed snapshot size limit")); }
    // Borrow validated files; copying every source body only to drop it
    // from the manifest metadata doubled the inventory's transient footprint.
    let mut files: Vec<&Value> = schema::array(capture, "files")?.iter().collect();
    files.sort_by(|a, b| a["path"].as_str().cmp(&b["path"].as_str()));
    let metadata: Vec<Value> = files.iter().map(|file| {
        Value::Object(file.as_object().expect("validated file").iter()
            .filter(|(key, _)| key.as_str() != "content")
            .map(|(key, value)| (key.clone(), value.clone())).collect())
    }).collect();
    let mut manifest = json!({
        "schema_version": schema::capture_version(capture)?,
        "root_id": capture["root_id"], "producer": capture["producer"],
        "facts": {"sha256": schema::digest(&facts_bytes), "count": capture["facts"].as_array().map_or(0, Vec::len)},
        "files": metadata, "coverage": capture["coverage"], "diagnostics": capture["diagnostics"],
    });
    let generation = schema::digest(&schema::canonical(&manifest)?);
    manifest["generation"] = Value::String(generation.clone());
    let manifest_bytes = schema::canonical(&manifest)?;
    if manifest_bytes.len() > schema::MAX_MANIFEST { return Err(CoreError::limit("Manifest exceeds snapshot size limit")); }
    // Use the same retained-capacity accounting as an empty reader registry.
    // Drop the temporary search cache before staging any files.
    let (_, weight) = search_cache(schema::array(capture, "facts")?, facts_bytes.len(), manifest_bytes.len())?;
    if weight > reader_budget { return Err(CoreError::limit("Snapshot exceeds the reader admission budget")); }

    let root = Dir::open(path, true)?;
    let _lock = root.lock()?;
    let blobs = root.child("blobs", true)?;
    let generations = root.child("generations", true)?;
    for file in files {
        let hash = schema::string(file, "sha256")?;
        let content = schema::string(file, "content")?.as_bytes();
        match blobs.read(hash, schema::MAX_SOURCE) {
            Ok(bytes) if bytes == content => {},
            Ok(_) => return Err(CoreError::snapshot("Existing source blob is corrupt")),
            Err(error) if error.code == "not_found" => {
                let name = temporary("blob");
                let result = blobs.write_new(&name, content).and_then(|_| blobs.rename(&name, &blobs, hash));
                let _ = blobs.unlink(&name, false);
                result?;
            }
            Err(error) => return Err(error),
        }
    }
    blobs.sync()?;
    match generations.child(&generation, false) {
        Ok(existing) => {
            if existing.read("manifest.json", schema::MAX_MANIFEST)? != manifest_bytes ||
                existing.read("facts.json", schema::MAX_FACTS_BYTES)? != facts_bytes {
                return Err(CoreError::snapshot("Existing generation differs from its identity"));
            }
        }
        Err(error) if error.code == "not_found" => {
            let name = temporary("stage");
            let staged = generations.child(&name, true)?;
            let result = (|| -> Result<()> {
                staged.write_new("facts.json", &facts_bytes)?;
                staged.write_new("manifest.json", &manifest_bytes)?;
                staged.sync()?;
                generations.rename(&name, &generations, &generation)?;
                Ok(())
            })();
            if result.is_err() {
                let _ = staged.unlink("facts.json", false);
                let _ = staged.unlink("manifest.json", false);
                let _ = generations.unlink(&name, true);
            }
            result?;
        }
        Err(error) => return Err(error),
    }
    generations.sync()?;
    let pointer = temporary("current");
    let result = root.write_new(&pointer, format!("{generation}\n").as_bytes())
        .and_then(|_| root.rename(&pointer, &root, "CURRENT"));
    let _ = root.unlink(&pointer, false);
    result?;
    after_commit(&generation, root.sync())?;
    Ok(manifest)
}

struct SearchRecord {
    name: String,
    text: String,
}

fn search_cache(facts: &[Value], facts_bytes: usize, manifest_bytes: usize) -> Result<(Vec<SearchRecord>, usize)> {
    let mut search = Vec::with_capacity(facts.len());
    let mut weight = facts_bytes.checked_add(manifest_bytes).ok_or_else(|| CoreError::limit("Search cache accounting overflow"))?;
    for fact in facts {
        let name = fact["name"].as_str().unwrap().to_lowercase();
        let text = format!("{} {} {}", name, fact["kind"].as_str().unwrap(), fact["path"].as_str().unwrap_or("").to_lowercase());
        weight = weight.checked_add(name.capacity()).and_then(|n| n.checked_add(text.capacity()))
            .ok_or_else(|| CoreError::limit("Search cache accounting overflow"))?;
        search.push(SearchRecord { name, text });
    }
    let slots = search.capacity().checked_mul(std::mem::size_of::<SearchRecord>())
        .and_then(|n| n.checked_add(std::mem::size_of::<Vec<SearchRecord>>()))
        .ok_or_else(|| CoreError::limit("Search cache accounting overflow"))?;
    weight = weight.checked_add(slots).ok_or_else(|| CoreError::limit("Search cache accounting overflow"))?;
    Ok((search, weight))
}

pub struct Reader {
    pub manifest: Value,
    pub generation: String,
    pub facts: Vec<Value>,
    pub weight: usize,
    by_id: HashMap<String, usize>,
    by_path: HashMap<String, Value>,
    by_file: HashMap<String, Vec<usize>>,
    search: Vec<SearchRecord>,
    blobs: Dir,
    pub(crate) source_index: std::sync::Mutex<Option<crate::query::Index>>,
    pub(crate) admission: Option<crate::query::Reservation>,
    method_counts: crate::method_lookup::Counts,
    method_open_bytes: (usize, usize),
    method_directory: std::sync::Mutex<Option<crate::method_lookup::Directory>>,
    schema_version: u64,
}

impl Reader {
    pub fn open(path: &Path, requested: Option<&str>) -> Result<Self> {
        let root = Dir::open(path, false)?;
        let generation = if let Some(generation) = requested {
            schema::hash(generation)?.to_string()
        } else {
            let bytes = root.read("CURRENT", 65)?;
            let text = std::str::from_utf8(&bytes).map_err(|_| CoreError::snapshot("Invalid generation pointer"))?;
            schema::hash(text.strip_suffix('\n').unwrap_or(text))?.to_string()
        };
        let directory = root.child("generations", false)?.child(&generation, false)?;
        let manifest_bytes = directory.read("manifest.json", schema::MAX_MANIFEST)?;
        let mut manifest: Value = serde_json::from_slice(&manifest_bytes).map_err(|_| CoreError::snapshot("Invalid manifest JSON"))?;
        schema::depth(&manifest)?;
        if !manifest["producer"].is_object() || !manifest["diagnostics"].is_array() {
            return Err(CoreError::snapshot("Manifest producer or diagnostics has an invalid shape"));
        }
        let version = schema::snapshot_version(&manifest["schema_version"])
            .map_err(|_| CoreError::snapshot("Unsupported snapshot schema"))?;
        if manifest["generation"].as_str() != Some(generation.as_str()) { return Err(CoreError::snapshot("Generation mismatch")); }
        manifest.as_object_mut().ok_or_else(|| CoreError::snapshot("Manifest is not an object"))?.remove("generation");
        if schema::digest(&schema::canonical(&manifest)?) != generation { return Err(CoreError::snapshot("Manifest identity verification failed")); }
        manifest["generation"] = Value::String(generation.clone());
        schema::hash(schema::string(&manifest, "root_id")?)?;
        schema::diagnostic_counts(schema::array(&manifest, "diagnostics")?)
            .map_err(|_| CoreError::snapshot("Manifest diagnostic counts or budget are invalid"))?;
        schema::coverage(&manifest)?;
        let files = schema::array(&manifest, "files")?;
        schema::files(files, false)?;
        let facts_bytes = directory.read("facts.json", schema::MAX_FACTS_BYTES)?;
        if Some(schema::digest(&facts_bytes).as_str()) != manifest["facts"]["sha256"].as_str() {
            return Err(CoreError::snapshot("Fact content verification failed"));
        }
        let facts: Vec<Value> = serde_json::from_slice(&facts_bytes).map_err(|_| CoreError::snapshot("Invalid facts JSON"))?;
        for fact in &facts { schema::depth(fact)?; }
        schema::stored_facts(&facts, files, version)?;
        if manifest["facts"]["count"].as_u64() != Some(facts.len() as u64) { return Err(CoreError::snapshot("Fact count mismatch")); }
        let by_id = facts.iter().enumerate().map(|(index, value)| (value["id"].as_str().unwrap().to_string(), index)).collect();
        let by_path = files.iter().map(|file| (file["path"].as_str().unwrap().to_string(), file.clone())).collect();
        let mut by_file: HashMap<String, Vec<usize>> = HashMap::new();
        let mut method_counts = crate::method_lookup::Counts::default();
        for (index, fact) in facts.iter().enumerate() {
            method_counts.record(fact)?;
            if let Some(path) = fact["path"].as_str() {
                match by_file.get_mut(path) {
                    Some(indices) => indices.push(index),
                    None => { by_file.insert(path.to_string(), vec![index]); }
                }
            }
        }
        let blobs = root.child("blobs", false)?;
        let (search, weight) = search_cache(&facts, facts_bytes.len(), manifest_bytes.len())?;
        Ok(Self { manifest, generation, facts, weight, by_id, by_path, by_file, search, blobs,
            source_index: std::sync::Mutex::new(None), admission: None, schema_version: version,
            method_counts, method_open_bytes: (facts_bytes.len(), manifest_bytes.len()), method_directory: std::sync::Mutex::new(None) })
    }

    pub(crate) fn method_lookup_baseline(&self) -> Value {
        let facts = self.facts.len();
        json!({"facts":facts,"facts_json_bytes":self.method_open_bytes.0,"manifest_json_bytes":self.method_open_bytes.1,
            "reader_admission_bytes":self.weight,"eligible_methods":self.method_counts.methods,
            "eligible_key_bytes":self.method_counts.key_bytes,"completed_open_fact_passes":{
                "depth":facts,"stored_fact_validation":facts,"by_id":facts,"by_file_and_method_counts":facts,"legacy_search_cache":facts},
            "accounting":"Existing encoded-data/search admission, not complete heap or RSS; method directory reserved separately"})
    }

    /// Initialization and candidate-position copying only; callers release this
    /// lock before source I/O, validation or response construction.
    pub(crate) fn with_method_directory<T>(&self, budget: &std::sync::Arc<crate::query::Budget>,
        select: impl FnOnce(&crate::method_lookup::Directory, bool) -> T) -> Result<T> {
        let mut directory = self.method_directory.lock()
            .map_err(|_| CoreError::new("internal_error", "Method directory lock unavailable"))?;
        let built = directory.is_none();
        if built {
            *directory = Some(crate::method_lookup::Directory::build(&self.facts, self.method_counts, budget)?);
        }
        Ok(select(directory.as_ref().unwrap(), built))
    }

    pub(crate) fn stored_fact(&self, id: &str) -> Result<&Value> {
        schema::hash(id)?;
        self.by_id.get(id).map(|index| &self.facts[*index]).ok_or_else(|| CoreError::new("not_found", "Fact is absent from this generation"))
    }

    pub(crate) fn schema_version(&self) -> u64 { self.schema_version }

    pub fn fact(&self, id: &str) -> Result<Value> {
        link_encoding::materialize_fact(self.stored_fact(id)?, self.schema_version)
    }

    /// Bulk audit expansion is transient output, never a second retained tree.
    pub fn all_facts(&self) -> Result<Value> {
        self.facts.iter().map(|fact| link_encoding::materialize_fact(fact, self.schema_version))
            .collect::<Result<Vec<_>>>().map(Value::Array)
    }

    pub fn links(&self, id: &str) -> Result<Value> {
        link_encoding::materialize_links(self.stored_fact(id)?, self.schema_version)
    }

    pub fn find(&self, query: &str, limit: usize) -> Result<Value> {
        if query.trim().is_empty() || query.len() > 256 { return Err(CoreError::input("Find needs 1 to 256 bytes of text")); }
        if !(1..=500).contains(&limit) { return Err(CoreError::input("Limit must be between 1 and 500")); }
        let normalized = query.trim().to_lowercase();
        let words: Vec<&str> = normalized.split_whitespace().collect();
        if words.len() > 16 { return Err(CoreError::input("Find supports at most 16 terms")); }
        // Identity lookup replaces one string comparison per fact; ordering
        // keys are read once per match rather than on every comparison.
        let identity = self.by_id.get(query).copied();
        let mut matches: Vec<(usize, Option<&str>, Option<&str>, &Value)> = self.facts.iter().zip(&self.search).enumerate()
            .filter_map(|(index, (fact, record))| {
                let id_match = identity == Some(index);
                if id_match || words.iter().all(|word| record.text.contains(word)) {
                    let rank = if id_match || record.name == normalized { 0 } else if record.name.starts_with(&normalized) { 1 } else { 2 };
                    Some((rank, fact["name"].as_str(), fact["id"].as_str(), fact))
                } else { None }
            }).collect();
        matches.sort_by(|a, b| (a.0, a.1, a.2).cmp(&(b.0, b.1, b.2)));
        let total = matches.len();
        let results: Vec<Value> = matches.into_iter().take(limit)
            .map(|(_, _, _, value)| link_encoding::materialize_fact(value, self.schema_version)).collect::<Result<_>>()?;
        let mut response = json!({"generation": self.generation, "query": query, "limit": limit, "total_matches": total,
            "truncated": total > limit, "coverage": self.manifest["coverage"]});
        // Move requested output into the envelope; do not serialize/clone its
        // just-materialized link trees through json! a second time.
        response["results"] = Value::Array(results);
        Ok(response)
    }

    pub fn source(&self, id: &str) -> Result<Value> {
        let fact = self.stored_fact(id)?;
        let path = fact["path"].as_str().ok_or_else(|| CoreError::new("source_unavailable", "This fact has no verified source file"))?;
        let file = self.by_path.get(path).ok_or_else(|| CoreError::snapshot("Fact references missing source metadata"))?;
        let content = self.source_bytes(file)?;
        let mut expanded_file = file.clone();
        expanded_file["content"] = Value::String(content.clone());
        schema::stored_facts(std::iter::once(fact), &[expanded_file], self.schema_version)
            .map_err(|_| CoreError::snapshot("Fact source positions disagree with captured bytes"))?;
        let mut response = json!({"generation": self.generation, "content": content, "sha256": file["sha256"]});
        response["fact"] = link_encoding::materialize_fact(fact, self.schema_version)?;
        Ok(response)
    }

    pub(crate) fn source_file_scratch(&self, path: &str) -> Result<usize> {
        schema::path(path)?;
        let file = self.by_path.get(path).ok_or_else(|| CoreError::new("not_found", "File is absent from this generation"))?;
        (file["bytes"].as_u64().unwrap() as usize).checked_mul(16).and_then(|n| n.checked_add(65536))
            .ok_or_else(|| CoreError::limit("Source response accounting overflow"))
    }

    pub fn source_file(&self, path: &str) -> Result<Value> {
        schema::path(path)?;
        let file = self.by_path.get(path).ok_or_else(|| CoreError::new("not_found", "File is absent from this generation"))?;
        Ok(json!({"generation":self.generation, "file":{"path":file["path"],"bytes":file["bytes"],"sha256":file["sha256"]}, "content":self.source_bytes(file)?, "sha256":file["sha256"]}))
    }

    pub(crate) fn source_bytes(&self, file: &Value) -> Result<String> {
        let hash = schema::string(file, "sha256")?;
        let bytes = self.blobs.read(hash, file["bytes"].as_u64().unwrap() as usize)?;
        if schema::digest(&bytes) != hash || Some(bytes.len() as u64) != file["bytes"].as_u64() {
            return Err(CoreError::snapshot("Source content verification failed"));
        }
        String::from_utf8(bytes).map_err(|_| CoreError::snapshot("Source blob is not UTF-8"))
    }

    pub fn check(&self) -> Result<Value> {
        for file in self.by_path.values() {
            let mut expanded = file.clone();
            expanded["content"] = Value::String(self.source_bytes(file)?);
            let matching = self.by_file.get(file["path"].as_str().unwrap()).into_iter().flatten().map(|index| &self.facts[*index]);
            schema::stored_facts(matching, &[expanded], self.schema_version).map_err(|_| CoreError::snapshot("Fact source positions disagree with captured bytes"))?;
        }
        Ok(json!({"generation": self.generation, "integrity": "verified", "freshness": "not_checked",
            "files": self.by_path.len(), "facts": self.facts.len(), "coverage": self.manifest["coverage"],
            "diagnostics": schema::diagnostic_counts(schema::array(&self.manifest, "diagnostics")?)?,
            "note": "Integrity verifies captured bytes, not current application state."}))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn fixture(name: &str) -> Value {
        let content = format!("class {name}\nend\n");
        json!({"root_id": "a".repeat(64), "producer": {"name":"fixture"},
            "files": [{"path":"app.rb","sha256":schema::digest(content.as_bytes()),"bytes":content.len(),"encoding":"UTF-8","content":content}],
            "facts": [{"id":"b".repeat(64),"kind":"class","name":name,"path":"app.rb","location":null,"evidence":"static","attributes":{},"links":[]}],
            "coverage":[{"family":"ruby","status":"partial","scope":"fixture","reason":"No runtime resolution"}],"diagnostics":[]})
    }

    fn call_fixture(version: u64) -> Value {
        let mut data = fixture("First"); data["schema_version"] = json!(version);
        data["facts"][0]["links"] = json!([{"relation":"calls","target":"héllo\"\\",
            "resolution":"unresolved","attributes":{"thistle_call":{"version":2,
            "data":["implicit",null,false,false,[0,5,1,1],null]}}}]);
        data
    }

    // Forge an internally hashed generation to exercise wire/source validation,
    // rather than allowing an unrelated digest failure to explain a refusal.
    fn forged_generation(path: &Path, manifest: &Value, facts: &[Value], version: u64) -> String {
        let bytes = serde_json::to_vec(facts).unwrap();
        let mut manifest = manifest.clone();
        manifest["schema_version"] = json!(version);
        manifest["facts"] = json!({"sha256":schema::digest(&bytes),"count":facts.len()});
        manifest.as_object_mut().unwrap().remove("generation");
        let generation = schema::digest(&schema::canonical(&manifest).unwrap());
        manifest["generation"] = json!(generation);
        let directory = path.join("generations").join(&generation);
        std::fs::create_dir_all(&directory).unwrap();
        std::fs::write(directory.join("facts.json"), bytes).unwrap();
        std::fs::write(directory.join("manifest.json"), schema::canonical(&manifest).unwrap()).unwrap();
        generation
    }

    #[test]
    fn tagged_publication_retains_rows_and_materializes_only_semantic_outputs() {
        let temp = tempfile::tempdir().unwrap();
        let mut data = call_fixture(3);
        let eligible = data["facts"][0]["links"][0].clone();
        let mut fallback = eligible.clone(); fallback["attributes"]["thistle_call"]["future"] = json!([null,"雪"]);
        data["facts"][0]["links"].as_array_mut().unwrap().extend([
            fallback, json!({"relation":"inherits","target":"Base","resolution":"unresolved"})]);
        // Publication ignores caller hint identities/sizes and counts actual bytes.
        data["evidence_accounting"] = json!({"schema_version":1,"fact_bytes_upper_bound":0});
        let manifest = publish(temp.path(), &data).unwrap();
        let reader = Reader::open(temp.path(), None).unwrap();
        assert!(reader.facts[0]["links"][0].is_array());
        assert!(reader.facts[0]["links"][1].is_object());
        let expected = &data["facts"][0];
        let id = expected["id"].as_str().unwrap();
        assert_eq!(reader.fact(id).unwrap(), *expected);
        assert_eq!(reader.all_facts().unwrap(), data["facts"]);
        assert_eq!(reader.find("First", 1).unwrap()["results"][0], *expected);
        assert_eq!(reader.source(id).unwrap()["fact"], *expected);
        assert_eq!(reader.links(id).unwrap(), expected["links"]);
        reader.check().unwrap();
        assert!(reader.facts[0]["links"][0].is_array()); // no expanded retained cache
        let bytes = std::fs::read(temp.path().join("generations").join(&reader.generation).join("facts.json")).unwrap();
        assert_eq!(manifest["facts"]["sha256"], schema::digest(&bytes));
        assert_eq!(schema::encoded_bytes(&link_encoding::WireFact::new(expected, 3).unwrap(), schema::MAX_FACTS_BYTES).unwrap() + 2, bytes.len());
        let next = publish(temp.path(), &fixture("Second")).unwrap();
        assert_ne!(next["generation"], manifest["generation"]);
        let pinned = Reader::open(temp.path(), Some(&reader.generation)).unwrap();
        assert_eq!(pinned.fact(id).unwrap(), *expected);
        assert_eq!(pinned.source(id).unwrap()["content"], data["files"][0]["content"]);
    }

    #[test]
    fn explicit_legacy_bytes_and_generation_reference_survive_new_schema_current() {
        let temp = tempfile::tempdir().unwrap();
        let mut generations = Vec::new();
        for version in [1,2,3] {
            let data = call_fixture(version);
            let manifest = publish(temp.path(), &data).unwrap();
            let bytes = std::fs::read(temp.path().join("generations").join(manifest["generation"].as_str().unwrap()).join("facts.json")).unwrap();
            if version != 3 {
                // Reference the original legacy serializer, without a projection.
                let reference = serde_json::to_vec(data["facts"].as_array().unwrap()).unwrap();
                assert_eq!(bytes, reference);
                let mut expected = manifest.clone(); expected.as_object_mut().unwrap().remove("generation");
                expected["facts"]["sha256"] = json!(schema::digest(&reference));
                assert_eq!(manifest["generation"], schema::digest(&schema::canonical(&expected).unwrap()));
            } else { assert!(serde_json::from_slice::<Value>(&bytes).unwrap()[0]["links"][0].is_array()); }
            assert_eq!(publish(temp.path(), &data).unwrap(), manifest);
            generations.push((manifest["generation"].as_str().unwrap().to_owned(), data));
        }
        for (generation, data) in generations {
            let reader = Reader::open(temp.path(), Some(&generation)).unwrap();
            assert_eq!(reader.all_facts().unwrap(), data["facts"]);
            reader.check().unwrap();
        }
    }

    #[test]
    fn invalid_tagged_input_refuses_whole_semantic_batch_and_stored_context() {
        let temp = tempfile::tempdir().unwrap();
        let data = call_fixture(3);
        let manifest = publish(temp.path(), &data).unwrap();
        let reader = Reader::open(temp.path(), None).unwrap();
        let wire = reader.facts.clone();
        for version in [1,2] {
            let generation = forged_generation(temp.path(), &manifest, &wire, version);
            assert!(Reader::open(temp.path(), Some(&generation)).is_err());
        }
        for row in [json!([false,"target",["implicit",null,false,false,[0,5,1,1],null]]),
            json!([1,"target",[]]), json!([0,"target"]),
            json!([0,"target",["implicit",null,0,false,[0,5,1,1],null]])] {
            let mut bad = wire.clone(); bad[0]["links"][0] = row;
            let generation = forged_generation(temp.path(), &manifest, &bad, 3);
            assert!(Reader::open(temp.path(), Some(&generation)).is_err());
        }
        let mut runtime = wire.clone(); runtime[0]["evidence"] = json!("runtime");
        let generation = forged_generation(temp.path(), &manifest, &runtime, 3);
        assert!(Reader::open(temp.path(), Some(&generation)).is_err());
        let mut semantic = data.clone();
        let mut invalid_tail = wire[0].clone(); invalid_tail["id"] = json!("c".repeat(64));
        semantic["facts"].as_array_mut().unwrap().push(invalid_tail);
        let missing = temp.path().join("not-created");
        assert!(publish(&missing, &semantic).is_err());
        assert!(!missing.exists());
        assert_eq!(Reader::open(temp.path(), None).unwrap().generation, reader.generation);
    }

    #[test]
    fn tagged_call_positions_are_checked_against_pinned_source_without_eager_expansion() {
        let temp = tempfile::tempdir().unwrap();
        let mut data = call_fixture(3);
        let content = "é\nhello\n";
        data["files"][0]["content"] = json!(content);
        data["files"][0]["bytes"] = json!(content.len());
        data["files"][0]["sha256"] = json!(schema::digest(content.as_bytes()));
        data["facts"][0]["links"][0]["attributes"]["thistle_call"]["data"][4] = json!([0,2,1,1]);
        let manifest = publish(temp.path(), &data).unwrap();
        for (coordinates, open_fails) in [(json!([0,99999,1,1]),true),
            (json!([0,2,1,2]),false),(json!([1,2,1,1]),false)] {
            let mut bad = data["facts"][0].clone();
            bad["links"][0]["attributes"]["thistle_call"]["data"][4] = coordinates;
            let wire = serde_json::to_value(link_encoding::WireFact::new(&bad, 3).unwrap()).unwrap();
            let generation = forged_generation(temp.path(), &manifest, &[wire], 3);
            let opened = Reader::open(temp.path(), Some(&generation));
            if open_fails { assert!(opened.is_err()); }
            else {
                let reader = opened.unwrap();
                assert!(reader.facts[0]["links"][0].is_array());
                assert!(reader.source(bad["id"].as_str().unwrap()).is_err());
                assert!(reader.check().is_err());
            }
        }
    }
    #[test]
    fn saved_diagnostic_groups_and_occurrences_are_checked_at_open_and_check() {
        let temp = tempfile::tempdir().unwrap();
        let mut data = fixture("DiagnosticCounts");
        data["diagnostics"] = json!([
            {"code":"dynamic_scope","message":"recoverable fixture","path":"app.rb","occurrences":3},
            {"code":"syntax_error","message":"legacy fixture","path":"app.rb"}
        ]);
        let mut manifest = publish(temp.path(), &data).unwrap();
        let reader = Reader::open(temp.path(), None).unwrap();
        assert_eq!(reader.check().unwrap()["diagnostics"], json!({"groups":2,"occurrences":4}));
        let old = temp.path().join("generations").join(manifest["generation"].as_str().unwrap());
        // Recompute the identity so refusal is attributable to diagnostic
        // validation rather than an unrelated manifest hash mismatch.
        manifest["diagnostics"][0]["occurrences"] = json!(0);
        manifest.as_object_mut().unwrap().remove("generation");
        let generation = schema::digest(&schema::canonical(&manifest).unwrap());
        manifest["generation"] = json!(generation);
        let invalid = temp.path().join("generations").join(&generation);
        std::fs::create_dir(&invalid).unwrap();
        std::fs::copy(old.join("facts.json"), invalid.join("facts.json")).unwrap();
        std::fs::write(invalid.join("manifest.json"), schema::canonical(&manifest).unwrap()).unwrap();
        let error = Reader::open(temp.path(), Some(&generation)).err().unwrap();
        assert_eq!(error.code, "invalid_snapshot");
        assert!(error.message.contains("diagnostic"));
        assert_eq!(Reader::open(temp.path(), None).unwrap().generation, reader.generation);
    }
    #[test]
    fn borrowed_publication_matches_owned_reference_for_permutations() {
        let temp = tempfile::tempdir().unwrap();
        let mut capture = fixture("First");
        capture["facts"][0]["attributes"] = json!({"nested": ["quote\" slash\\ newline\n", {"unicode":"é", "numbers":[-42, 0, 1.25, 1e30]}]});
        let mut second = capture["facts"][0].clone();
        second["id"] = json!("a".repeat(64));
        second["name"] = json!("Second");
        capture["facts"].as_array_mut().unwrap().push(second);
        let original = capture.clone();
        let mut owned = capture["facts"].as_array().unwrap().clone();
        owned.sort_by(|a, b| a["id"].as_str().cmp(&b["id"].as_str()));
        let expected = schema::canonical(&Value::Array(owned)).unwrap();
        let manifest = publish(temp.path(), &capture).unwrap();
        assert_eq!(capture, original);
        let generation = manifest["generation"].as_str().unwrap();
        let dir = temp.path().join("generations").join(generation);
        assert_eq!(std::fs::read(dir.join("facts.json")).unwrap(), expected);
        assert_eq!(manifest["facts"]["sha256"], schema::digest(&expected));
        let manifest_bytes = std::fs::read(dir.join("manifest.json")).unwrap();
        capture["facts"].as_array_mut().unwrap().reverse();
        let reversed = capture.clone();
        let again = publish(temp.path(), &capture).unwrap();
        assert_eq!(capture, reversed);
        assert_eq!(manifest, again);
        assert_eq!(std::fs::read(dir.join("manifest.json")).unwrap(), manifest_bytes);
        assert_eq!(Reader::open(temp.path(), None).unwrap().facts, serde_json::from_slice::<Vec<Value>>(&expected).unwrap());
    }
    fn assert_publication_limit_preserves_store(capture: Value, message: &str) {
        let temp = tempfile::tempdir().unwrap();
        let missing = temp.path().join("missing");
        let error = publish(&missing, &capture).unwrap_err();
        assert_eq!(error.code, "limit_exceeded");
        assert_eq!(error.message, message);
        assert!(!missing.exists());

        let existing = temp.path().join("existing");
        let first = publish(&existing, &fixture("First")).unwrap();
        let pointer = std::fs::read(existing.join("CURRENT")).unwrap();
        let error = publish(&existing, &capture).unwrap_err();
        assert_eq!(error.code, "limit_exceeded");
        assert_eq!(error.message, message);
        assert_eq!(std::fs::read(existing.join("CURRENT")).unwrap(), pointer);
        let reader = Reader::open(&existing, None).unwrap();
        assert_eq!(reader.generation, first["generation"].as_str().unwrap());
        assert_eq!(reader.facts[0]["name"], "First");
        reader.check().unwrap();
    }
    #[test]
    fn publication_depth_refusal_precedes_filesystem_changes() {
        let mut capture = fixture("Deep");
        let mut nested = Value::Null;
        for _ in 0..=schema::MAX_DEPTH { nested = Value::Array(vec![nested]); }
        capture["facts"][0]["attributes"]["nested"] = nested;
        assert_publication_limit_preserves_store(capture, "JSON structure exceeds 64 nested levels");
    }
    #[test]
    fn publication_fact_count_refusal_precedes_filesystem_changes() {
        let mut capture = fixture("Many");
        // Count validation must refuse before inspecting the individual entries.
        capture["facts"] = Value::Array(vec![Value::Null; 100_001]);
        assert_publication_limit_preserves_store(capture, "Fact count exceeds 100000");
    }
    #[test]
    fn publication_encoded_size_refusal_preserves_existing_generation() {
        let mut capture = fixture("Escaped");
        capture["schema_version"] = json!(3);
        // A forged tiny hint never participates in publication validation/counting.
        capture["evidence_accounting"] = json!({"schema_version":3,"fact_bytes_upper_bound":2});
        // Each NUL encodes as six bytes: exceed the real limit with ~11 MiB input.
        capture["facts"][0]["attributes"]["payload"] =
            Value::String("\0".repeat(schema::MAX_FACTS_BYTES / 6 + 1));
        assert_publication_limit_preserves_store(capture, "Facts exceed snapshot size limit");
    }
    #[test]
    fn invalid_fact_ids_fail_before_creating_store() {
        let temp = tempfile::tempdir().unwrap();
        let path = temp.path().join("store");
        let mut capture = fixture("First");
        capture["facts"][0]["id"] = json!("invalid");
        assert_eq!(publish(&path, &capture).unwrap_err().code, "invalid_input");
        assert!(!path.exists());
        capture = fixture("First");
        let duplicate = capture["facts"][0].clone();
        capture["facts"].as_array_mut().unwrap().push(duplicate);
        assert_eq!(publish(&path, &capture).unwrap_err().code, "invalid_input");
        assert!(!path.exists());
    }
    #[test]
    fn immutable_pin_survives_new_publication() {
        let temp = tempfile::tempdir().unwrap();
        let first = publish(temp.path(), &fixture("First")).unwrap();
        let old = Reader::open(temp.path(), None).unwrap();
        let second = publish(temp.path(), &fixture("Second")).unwrap();
        assert_ne!(first["generation"], second["generation"]);
        assert_eq!(old.find("First", 10).unwrap()["total_matches"], 1);
        assert_eq!(Reader::open(temp.path(), None).unwrap().find("Second", 10).unwrap()["total_matches"], 1);
        assert_eq!(Reader::open(temp.path(), first["generation"].as_str()).unwrap().facts[0]["name"], "First");
    }
    #[test]
    fn grammar_metadata_changes_identity_and_legacy_manifest_remains_readable() {
        let temp = tempfile::tempdir().unwrap();
        let legacy = fixture("Same");
        let old = publish(temp.path(), &legacy).unwrap();
        let mut current = legacy;
        current["producer"]["ruby_syntax_version"] = json!("4.1");
        current["producer"]["parser_policy"] = json!("prism-default-guarded");
        let new = publish(temp.path(), &current).unwrap();
        assert_ne!(old["generation"], new["generation"]);
        let reader = Reader::open(temp.path(), old["generation"].as_str()).unwrap();
        assert!(reader.manifest["producer"].get("ruby_syntax_version").is_none());
    }
    #[test]
    fn invalid_publication_preserves_pointer() {
        let temp = tempfile::tempdir().unwrap();
        let first = publish(temp.path(), &fixture("First")).unwrap();
        let mut invalid = fixture("Broken"); invalid["files"][0]["sha256"] = json!("c".repeat(64));
        assert!(publish(temp.path(), &invalid).is_err());
        assert_eq!(Reader::open(temp.path(), None).unwrap().generation, first["generation"].as_str().unwrap());
    }
    #[test]
    fn call_metadata_validation_preserves_current_and_legacy() {
        let temp = tempfile::tempdir().unwrap();
        let mut data = fixture("First");
        let old = publish(temp.path(), &data).unwrap();
        let loc = json!({"start_byte":0,"end_byte":5,"start_line":1,"end_line":1});
        data["facts"][0]["links"] = json!([{"relation":"calls","target":"hello","resolution":"unresolved",
            "attributes":{"thistle_call":{"version":1,"receiver":{"kind":"implicit","name":null,"omitted_limit":false},
            "safe_navigation":false,"call_location":loc,"receiver_location":null}}}]);
        let good = publish(temp.path(), &data).unwrap();
        let reader = Reader::open(temp.path(), good["generation"].as_str()).unwrap();
        assert_eq!(reader.fact(&"b".repeat(64)).unwrap()["links"][0]["target"], "hello");
        reader.check().unwrap();
        let mut bad = data.clone();
        bad["facts"][0]["links"][0]["attributes"]["thistle_call"]["call_location"]["start_line"] = json!(2);
        assert!(publish(temp.path(), &bad).is_err());
        bad = data.clone();
        bad["facts"][0]["links"][0]["attributes"]["thistle_call"]["receiver"]["name"] = json!("invented");
        assert!(publish(temp.path(), &bad).is_err());
        bad = data.clone();
        bad["facts"][0]["links"][0]["attributes"]["thistle_call"]["receiver"] = json!({"kind":"local","name":"x".repeat(257),"omitted_limit":false});
        bad["facts"][0]["links"][0]["attributes"]["thistle_call"]["receiver_location"] = json!({"start_byte":0,"end_byte":1,"start_line":1,"end_line":1});
        assert!(publish(temp.path(), &bad).is_err());
        bad = data.clone();
        bad["facts"][0]["links"][0]["attributes"]["thistle_call"]["call_location"]["end_byte"] = json!(99999);
        assert!(publish(temp.path(), &bad).is_err());
        bad = data.clone();
        bad["facts"][0]["path"] = json!("missing.rb");
        assert!(publish(temp.path(), &bad).is_err());
        bad = data.clone();
        let unicode = "é\n";
        bad["files"][0]["content"] = json!(unicode);
        bad["files"][0]["bytes"] = json!(unicode.len());
        bad["files"][0]["sha256"] = json!(schema::digest(unicode.as_bytes()));
        bad["facts"][0]["links"][0]["attributes"]["thistle_call"]["call_location"] = json!({"start_byte":1,"end_byte":2,"start_line":1,"end_line":1});
        assert!(publish(temp.path(), &bad).is_err());
        assert_eq!(Reader::open(temp.path(), None).unwrap().generation, good["generation"].as_str().unwrap());
        assert!(Reader::open(temp.path(), old["generation"].as_str()).unwrap().fact(&"b".repeat(64)).unwrap()["links"].as_array().unwrap().is_empty());
        data["facts"][0]["links"][0]["attributes"]["thistle_call"] = json!({"version":2,"future":[1,2,3]});
        publish(temp.path(), &data).unwrap();
    }

    #[test]
    fn explicit_schema_selection_preserves_legacy_identity_and_opaque_compact() {
        let temp = tempfile::tempdir().unwrap();
        let mut legacy = fixture("First");
        // Intentionally not a static unresolved call: even an EXACT valid compact
        // extension was opaque in schema 1 and must not acquire v2 semantics.
        legacy["producer"]["call_target_schema"] = json!(2);
        let compact = json!({"version":2,"data":["implicit",null,false,false,[0,5,1,1],null]});
        legacy["facts"][0]["links"] = json!([{"relation":"references","target":"hello","resolution":"resolved",
            "attributes":{"thistle_call":compact}}]);
        let old = publish(temp.path(), &legacy).unwrap();
        assert_eq!(old["schema_version"], 1);
        legacy["schema_version"] = json!(1);
        assert_eq!(publish(temp.path(), &legacy).unwrap(), old);
        let old_facts = std::fs::read(temp.path().join("generations").join(old["generation"].as_str().unwrap()).join("facts.json")).unwrap();
        let mut current = legacy.clone(); current["schema_version"] = json!(2);
        assert!(publish(temp.path(), &current).is_err());
        current["facts"][0]["links"][0]["relation"] = json!("calls");
        current["facts"][0]["links"][0]["resolution"] = json!("unresolved");
        let new = publish(temp.path(), &current).unwrap();
        assert_ne!(old["generation"], new["generation"]);
        for manifest in [&old, &new] {
            let reader = Reader::open(temp.path(), manifest["generation"].as_str()).unwrap();
            let source = reader.source(&"b".repeat(64)).unwrap();
            assert_eq!(source["fact"]["links"][0]["attributes"]["thistle_call"], compact);
            reader.check().unwrap();
        }
        assert_eq!(std::fs::read(temp.path().join("generations").join(old["generation"].as_str().unwrap()).join("facts.json")).unwrap(), old_facts);
        for version in [Value::Null, json!(true), json!("2"), json!(2.0), json!(0), json!(4), json!(-1)] {
            current["schema_version"] = version;
            let absent = temp.path().join("must-not-exist");
            assert!(publish(&absent, &current).is_err());
            assert!(!absent.exists());
            assert_eq!(Reader::open(temp.path(), None).unwrap().generation, new["generation"].as_str().unwrap());
        }
    }

    #[test]
    fn compact_validation_runs_at_open_source_and_check() {
        let temp = tempfile::tempdir().unwrap();
        let mut data = fixture("First"); data["schema_version"] = json!(2);
        data["facts"][0]["links"] = json!([{"relation":"calls","target":"hello","resolution":"unresolved",
            "attributes":{"thistle_call":{"version":2,"data":["implicit",null,false,false,[0,5,1,1],null]}}}]);
        let mut manifest = publish(temp.path(), &data).unwrap();
        let mut reader = Reader::open(temp.path(), None).unwrap();
        // Open can validate numeric bounds without blobs; Source and Check must
        // also validate line/UTF-8 semantics against the pinned source content.
        reader.facts[0]["links"][0]["attributes"]["thistle_call"]["data"][4][3] = json!(2);
        assert!(reader.source(&"b".repeat(64)).is_err());
        assert!(reader.check().is_err());
        reader.facts[0]["links"][0]["attributes"]["thistle_call"]["data"][4] = json!([0,99999,1,1]);
        let bytes = serde_json::to_vec(&reader.facts).unwrap();
        manifest["facts"]["sha256"] = json!(schema::digest(&bytes));
        manifest.as_object_mut().unwrap().remove("generation");
        let generation = schema::digest(&schema::canonical(&manifest).unwrap());
        manifest["generation"] = json!(generation);
        let dir = temp.path().join("generations").join(&generation);
        std::fs::create_dir(&dir).unwrap();
        std::fs::write(dir.join("facts.json"), bytes).unwrap();
        std::fs::write(dir.join("manifest.json"), schema::canonical(&manifest).unwrap()).unwrap();
        assert!(Reader::open(temp.path(), Some(&generation)).is_err());
        // Schema 2 also admits strict v1 without rewriting it.
        data["facts"][0]["links"][0]["attributes"]["thistle_call"] = json!({"version":1,
            "receiver":{"kind":"implicit","name":null,"omitted_limit":false},"safe_navigation":false,
            "call_location":{"start_byte":0,"end_byte":5,"start_line":1,"end_line":1},"receiver_location":null});
        publish(temp.path(), &data).unwrap();
        Reader::open(temp.path(), None).unwrap().check().unwrap();
    }

    #[test]
    fn tampering_and_symlinks_fail_closed() {
        use std::os::unix::fs::symlink;
        let temp = tempfile::tempdir().unwrap();
        let capture = fixture("First");
        publish(temp.path(), &capture).unwrap();
        let reader = Reader::open(temp.path(), None).unwrap();
        let blob = temp.path().join("blobs").join(capture["files"][0]["sha256"].as_str().unwrap());
        std::fs::write(&blob, "corrupt").unwrap();
        assert_eq!(reader.check().unwrap_err().code, "invalid_snapshot");
        std::fs::remove_file(&blob).unwrap(); symlink("/etc/passwd", &blob).unwrap();
        assert_eq!(reader.source(&"b".repeat(64)).unwrap_err().code, "unsafe_path");
    }
    #[test]
    fn deterministic_identity_and_labelled_links() {
        let temp = tempfile::tempdir().unwrap();
        let data = fixture("First");
        assert_eq!(publish(temp.path(), &data).unwrap(), publish(temp.path(), &data).unwrap());
        let reader = Reader::open(temp.path(), None).unwrap();
        assert_eq!(reader.check().unwrap()["freshness"], "not_checked");
        assert!(reader.find("", 10).is_err());
        assert!(reader.find("First", 1000).is_err());
        assert!(reader.fact("../../elsewhere").is_err());
    }
    #[test]
    fn source_positions_are_checked_against_bytes() {
        let temp = tempfile::tempdir().unwrap();
        let mut bad = fixture("First");
        bad["facts"][0]["location"] = json!({"start_line":9999,"end_line":9999,"start_byte":0,"end_byte":5});
        assert_eq!(publish(temp.path(), &bad).unwrap_err().code, "invalid_input");
        bad["facts"][0]["location"] = json!({"start_line":1,"end_line":1,"start_byte":0,"end_byte":5});
        publish(temp.path(), &bad).unwrap();
    }
    #[test]
    fn durability_failure_after_commit_is_explicitly_uncertain() {
        let result = after_commit(&"a".repeat(64), Err(CoreError::new("io_error", "injected directory sync failure")));
        let error = result.unwrap_err();
        assert_eq!(error.code, "commit_uncertain");
        assert!(error.message.contains("was selected"));
        assert!(error.message.contains(&"a".repeat(64)));
    }

    #[test]
    fn search_preserves_unicode_original_id_kind_and_ranking_semantics() {
        let temp = tempfile::tempdir().unwrap();
        let mut data = fixture("unused");
        data["files"][0]["path"] = json!("ÄPP.rb");
        data["facts"] = json!([
            {"id":"b".repeat(64),"kind":"Class","name":"İTEM","path":"ÄPP.rb","location":null,"evidence":"static","attributes":{},"links":[]},
            {"id":"c".repeat(64),"kind":"class","name":"Itemized","path":"ÄPP.rb","location":null,"evidence":"static","attributes":{},"links":[]},
            {"id":"d".repeat(64),"kind":"class","name":"Item","path":null,"location":null,"evidence":"runtime","attributes":{},"links":[]},
            {"id":"e".repeat(64),"kind":"class","name":"item","path":"ÄPP.rb","location":null,"evidence":"static","attributes":{},"links":[]},
            {"id":"f".repeat(64),"kind":"class","name":"AnItem","path":null,"location":null,"evidence":"runtime","attributes":{},"links":[]}
        ]);
        publish(temp.path(), &data).unwrap();
        let reader = Reader::open(temp.path(), None).unwrap();
        let found = reader.find(" item ", 3).unwrap();
        assert_eq!(found["query"], " item ");
        assert_eq!(found["total_matches"], 4);
        assert_eq!(found["truncated"], true);
        assert_eq!(found["results"].as_array().unwrap().iter().map(|f| f["name"].as_str().unwrap()).collect::<Vec<_>>(), ["Item", "item", "Itemized"]);
        assert_eq!(reader.find("İTEM", 10).unwrap()["results"][0]["name"], "İTEM");
        assert_eq!(reader.find("CLASS äpp", 10).unwrap()["total_matches"], 2);
        assert_eq!(reader.find("äPP", 10).unwrap()["total_matches"], 3);
        assert_eq!(reader.find(&"b".repeat(64), 10).unwrap()["total_matches"], 1);
        assert_eq!(reader.find(&format!(" {} ", "b".repeat(64)), 10).unwrap()["total_matches"], 0);
        assert_eq!(reader.find(&"B".repeat(64), 10).unwrap()["total_matches"], 0);
        for query in ["".to_string(), "  \n".to_string(), "a".repeat(257), vec!["a"; 17].join(" ")] {
            assert_eq!(reader.find(&query, 10).unwrap_err().code, "invalid_input");
        }
        assert!(reader.find("item", 0).is_err());
        assert!(reader.find("item", 501).is_err());
    }

    #[test]
    fn search_cache_retained_capacities_are_charged_to_reader_admission() {
        let temp = tempfile::tempdir().unwrap();
        publish(temp.path(), &fixture("İTEM")).unwrap();
        let reader = Reader::open(temp.path(), None).unwrap();
        let directory = temp.path().join("generations").join(&reader.generation);
        let encoded = std::fs::metadata(directory.join("facts.json")).unwrap().len() as usize
            + std::fs::metadata(directory.join("manifest.json")).unwrap().len() as usize;
        let cache = std::mem::size_of::<Vec<SearchRecord>>()
            + reader.search.capacity() * std::mem::size_of::<SearchRecord>()
            + reader.search.iter().map(|r| r.name.capacity() + r.text.capacity()).sum::<usize>();
        assert!(cache > 0);
        assert_eq!(reader.weight, encoded + cache);
    }

    #[test]
    fn publication_preflight_matches_reader_weight_and_preserves_current() {
        let temp = tempfile::tempdir().unwrap();
        let data = fixture("İTEM");
        let first = publish(temp.path(), &data).unwrap();
        let weight = Reader::open(temp.path(), None).unwrap().weight;
        assert_eq!(publish_with_reader_budget(temp.path(), &data, weight).unwrap(), first);
        let mut next = data;
        next["facts"][0]["name"] = json!("İTEX");
        assert_eq!(publish_with_reader_budget(temp.path(), &next, weight - 1).unwrap_err().code, "limit_exceeded");
        assert_eq!(Reader::open(temp.path(), None).unwrap().generation, first["generation"].as_str().unwrap());
    }
}
