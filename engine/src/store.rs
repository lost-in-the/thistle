use crate::{error::{CoreError, Result}, fs::Dir, schema};
use serde_json::{json, Value};
use std::{collections::HashMap, path::Path, sync::atomic::{AtomicU64, Ordering}};

static TEMP_SEQUENCE: AtomicU64 = AtomicU64::new(0);

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

pub struct Reader {
    pub manifest: Value,
    pub generation: String,
    pub facts: Vec<Value>,
    pub weight: usize,
    by_id: HashMap<String, usize>,
    by_path: HashMap<String, Value>,
    by_file: HashMap<String, Vec<usize>>,
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
        schema::facts(&facts, files)?;
        if manifest["facts"]["count"].as_u64() != Some(facts.len() as u64) { return Err(CoreError::snapshot("Fact count mismatch")); }
        let by_id = facts.iter().enumerate().map(|(index, value)| (value["id"].as_str().unwrap().to_string(), index)).collect();
        let by_path = files.iter().map(|file| (file["path"].as_str().unwrap().to_string(), file.clone())).collect();
        let mut by_file: HashMap<String, Vec<usize>> = HashMap::new();
        for (index, fact) in facts.iter().enumerate() {
            if let Some(path) = fact["path"].as_str() { by_file.entry(path.to_string()).or_default().push(index); }
        }
        let blobs = root.child("blobs", false)?;
        Ok(Self { manifest, generation, facts, weight: facts_bytes.len() + manifest_bytes.len(), by_id, by_path, by_file, blobs })
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
        let mut matches: Vec<(usize, &Value)> = self.facts.iter().filter_map(|fact| {
            let name = fact["name"].as_str().unwrap().to_lowercase();
            let haystack = format!("{} {} {}", name, fact["kind"].as_str().unwrap(), fact["path"].as_str().unwrap_or("").to_lowercase());
            let id_match = fact["id"].as_str() == Some(query);
            if id_match || words.iter().all(|word| haystack.contains(word)) {
                let rank = if id_match || name == normalized { 0 } else if name.starts_with(&normalized) { 1 } else { 2 };
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
    fn invalid_publication_preserves_pointer() {
        let temp = tempfile::tempdir().unwrap();
        let first = publish(temp.path(), &fixture("First")).unwrap();
        let mut invalid = fixture("Broken"); invalid["files"][0]["sha256"] = json!("c".repeat(64));
        assert!(publish(temp.path(), &invalid).is_err());
        assert_eq!(Reader::open(temp.path(), None).unwrap().generation, first["generation"].as_str().unwrap());
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
}
