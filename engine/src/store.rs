use crate::{error::{CoreError, Result}, fs::Dir, schema};
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
    let mut facts = schema::array(capture, "facts")?.clone();
    facts.sort_by(|a, b| a["id"].as_str().cmp(&b["id"].as_str()));
    let facts_bytes = schema::canonical(&Value::Array(facts))?;
    if facts_bytes.len() > schema::MAX_FACTS_BYTES { return Err(CoreError::limit("Facts exceed snapshot size limit")); }
    let mut files = schema::array(capture, "files")?.clone();
    files.sort_by(|a, b| a["path"].as_str().cmp(&b["path"].as_str()));
    let metadata: Vec<Value> = files.iter().map(|file| {
        let mut entry = file.clone();
        entry.as_object_mut().expect("validated file").remove("content");
        entry
    }).collect();
    let mut manifest = json!({
        "schema_version": schema::VERSION,
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
    for file in &files {
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
        if manifest["schema_version"].as_u64() != Some(schema::VERSION) {
            return Err(CoreError::snapshot("Unsupported snapshot schema"));
        }
        if manifest["generation"].as_str() != Some(generation.as_str()) { return Err(CoreError::snapshot("Generation mismatch")); }
        manifest.as_object_mut().ok_or_else(|| CoreError::snapshot("Manifest is not an object"))?.remove("generation");
        if schema::digest(&schema::canonical(&manifest)?) != generation { return Err(CoreError::snapshot("Manifest identity verification failed")); }
        manifest["generation"] = Value::String(generation.clone());
        schema::hash(schema::string(&manifest, "root_id")?)?;
        schema::coverage(&manifest)?;
        let files = schema::array(&manifest, "files")?;
        schema::files(files, false)?;
        let facts_bytes = directory.read("facts.json", schema::MAX_FACTS_BYTES)?;
        if Some(schema::digest(&facts_bytes).as_str()) != manifest["facts"]["sha256"].as_str() {
            return Err(CoreError::snapshot("Fact content verification failed"));
        }
        let facts: Vec<Value> = serde_json::from_slice(&facts_bytes).map_err(|_| CoreError::snapshot("Invalid facts JSON"))?;
        for fact in &facts { schema::depth(fact)?; }
        schema::facts(&facts, files)?;
        if manifest["facts"]["count"].as_u64() != Some(facts.len() as u64) { return Err(CoreError::snapshot("Fact count mismatch")); }
        let by_id = facts.iter().enumerate().map(|(index, value)| (value["id"].as_str().unwrap().to_string(), index)).collect();
        let by_path = files.iter().map(|file| (file["path"].as_str().unwrap().to_string(), file.clone())).collect();
        let mut by_file: HashMap<String, Vec<usize>> = HashMap::new();
        for (index, fact) in facts.iter().enumerate() {
            if let Some(path) = fact["path"].as_str() { by_file.entry(path.to_string()).or_default().push(index); }
        }
        let blobs = root.child("blobs", false)?;
        let (search, weight) = search_cache(&facts, facts_bytes.len(), manifest_bytes.len())?;
        Ok(Self { manifest, generation, facts, weight, by_id, by_path, by_file, search, blobs })
    }

    pub fn fact(&self, id: &str) -> Result<&Value> {
        schema::hash(id)?;
        self.by_id.get(id).map(|index| &self.facts[*index]).ok_or_else(|| CoreError::new("not_found", "Fact is absent from this generation"))
    }

    pub fn find(&self, query: &str, limit: usize) -> Result<Value> {
        if query.trim().is_empty() || query.len() > 256 { return Err(CoreError::input("Find needs 1 to 256 bytes of text")); }
        if !(1..=500).contains(&limit) { return Err(CoreError::input("Limit must be between 1 and 500")); }
        let normalized = query.trim().to_lowercase();
        let words: Vec<&str> = normalized.split_whitespace().collect();
        if words.len() > 16 { return Err(CoreError::input("Find supports at most 16 terms")); }
        let mut matches: Vec<(usize, &Value)> = self.facts.iter().zip(&self.search).filter_map(|(fact, record)| {
            let id_match = fact["id"].as_str() == Some(query);
            if id_match || words.iter().all(|word| record.text.contains(word)) {
                let rank = if id_match || record.name == normalized { 0 } else if record.name.starts_with(&normalized) { 1 } else { 2 };
                Some((rank, fact))
            } else { None }
        }).collect();
        matches.sort_by(|a, b| (a.0, a.1["name"].as_str(), a.1["id"].as_str()).cmp(&(b.0, b.1["name"].as_str(), b.1["id"].as_str())));
        let total = matches.len();
        let results: Vec<&Value> = matches.into_iter().take(limit).map(|(_, value)| value).collect();
        Ok(json!({"generation": self.generation, "query": query, "limit": limit, "total_matches": total,
            "truncated": total > limit, "results": results, "coverage": self.manifest["coverage"]}))
    }

    pub fn source(&self, id: &str) -> Result<Value> {
        let fact = self.fact(id)?;
        let path = fact["path"].as_str().ok_or_else(|| CoreError::new("source_unavailable", "This fact has no verified source file"))?;
        let file = self.by_path.get(path).ok_or_else(|| CoreError::snapshot("Fact references missing source metadata"))?;
        let content = self.source_bytes(file)?;
        let mut expanded_file = file.clone();
        expanded_file["content"] = Value::String(content.clone());
        schema::facts(std::slice::from_ref(fact), &[expanded_file])
            .map_err(|_| CoreError::snapshot("Fact source positions disagree with captured bytes"))?;
        Ok(json!({"generation": self.generation, "fact": fact, "content": content, "sha256": file["sha256"]}))
    }

    fn source_bytes(&self, file: &Value) -> Result<String> {
        let hash = schema::string(file, "sha256")?;
        let bytes = self.blobs.read(hash, schema::MAX_SOURCE)?;
        if schema::digest(&bytes) != hash || Some(bytes.len() as u64) != file["bytes"].as_u64() {
            return Err(CoreError::snapshot("Source content verification failed"));
        }
        String::from_utf8(bytes).map_err(|_| CoreError::snapshot("Source blob is not UTF-8"))
    }

    pub fn check(&self) -> Result<Value> {
        for file in self.by_path.values() {
            let mut expanded = file.clone();
            expanded["content"] = Value::String(self.source_bytes(file)?);
            let matching: Vec<Value> = self.by_file.get(file["path"].as_str().unwrap()).into_iter().flatten().map(|index| self.facts[*index].clone()).collect();
            schema::facts(&matching, &[expanded]).map_err(|_| CoreError::snapshot("Fact source positions disagree with captured bytes"))?;
        }
        Ok(json!({"generation": self.generation, "integrity": "verified", "freshness": "not_checked",
            "files": self.by_path.len(), "facts": self.facts.len(), "coverage": self.manifest["coverage"],
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
