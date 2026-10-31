pub mod error;
pub mod capture;
mod fs;
mod model;
mod callbacks;
mod callback_effects;
mod method_lookup;
mod source_comprehension;
mod job_mail;
mod job_mail_source;
mod erb_template;
mod references;
mod fact_identity;
mod model_brief;
mod recorded_domain;
mod link_encoding;
mod schema;
mod store;
mod query;

use error::{CoreError, Result};
use serde_json::{json, Value};
use std::{collections::HashMap, ffi::{c_char, CString}, path::Path, sync::{Arc, Mutex, OnceLock, atomic::{AtomicU32, Ordering}}};

struct Registry { next: u64, readers: HashMap<u64, Arc<store::Reader>> }
static READERS: OnceLock<Mutex<Registry>> = OnceLock::new();
static PROCESS: AtomicU32 = AtomicU32::new(0);

// Public-capture fixtures share its process-wide permit; ordinary unit tests
// keep independent Readers and can otherwise run concurrently.
#[cfg(test)]
static CAPTURE_FIXTURE_LOCK: Mutex<()> = Mutex::new(());

fn registry() -> &'static Mutex<Registry> {
    READERS.get_or_init(|| Mutex::new(Registry { next: 1, readers: HashMap::new() }))
}

fn reader(request: &Value) -> Result<Arc<store::Reader>> {
    let handle = request["handle"].as_u64().ok_or_else(|| CoreError::input("Reader handle is required"))?;
    let registry = registry().lock().map_err(|_| CoreError::new("internal_error", "Reader registry is unavailable"))?;
    registry.readers.get(&handle).cloned().ok_or_else(|| CoreError::new("closed_reader", "Reader is closed or unknown"))
}

pub fn dispatch(request: &Value) -> Result<Value> {
    ensure_process()?;
    let _scratch = request_scratch(request)?;
    dispatch_inner(request)
}

fn request_scratch(request: &Value) -> Result<Option<query::Reservation>> {
    let bytes = match request["op"].as_str() {
        Some("fact_identity") => { fact_identity::id(request)?; fact_identity::SCRATCH },
        Some("model_brief") => model_brief::Query::parse(request)?.scratch(),
        Some("source_comprehension") => source_comprehension::Query::parse(request)?.scratch(),
        Some("job_mail") => job_mail::Query::parse(request)?.scratch(),
        Some("callback_effects") => callback_effects::Query::parse(request)?.scratch(),
        Some("references") => references::Query::parse(request)?.scratch(),
        Some("find_evidence") => query::Query::parse(request)?.scratch()?,
        Some("source_file") => reader(request)?.source_file_scratch(schema::string(request, "file_path")?)?,
        _ => return Ok(None),
    };
    Ok(Some(query::budget().reserve(bytes)?))
}

fn ensure_process() -> Result<()> {
    let current_pid = std::process::id();
    let initialized = PROCESS.compare_exchange(0, current_pid, Ordering::SeqCst, Ordering::SeqCst).unwrap_or_else(|value| value);
    if initialized != 0 && initialized != current_pid {
        return Err(CoreError::new("forked_process", "Native engine was inherited across fork; exec a fresh process before using Thistle"));
    }
    Ok(())
}

fn dispatch_inner(request: &Value) -> Result<Value> {
    for field in ["root", "path"] {
        if let Some(value) = request.get(field) {
            let value = value.as_str().ok_or_else(|| CoreError::input("Filesystem path must be a string"))?;
            if value.is_empty() || value.contains('\0') { return Err(CoreError::input("Filesystem path must be nonempty and contain no NUL")); }
        }
    }
    match schema::string(request, "op")? {
        "version" => Ok(json!({"engine":"rust", "version":env!("CARGO_PKG_VERSION"), "schema_version":schema::VERSION,
            "arch":std::env::consts::ARCH, "os":std::env::consts::OS, "parser":"prism-1.9.0"})),
        "capture" => match request.get("templates") {
            None | Some(Value::Null) => capture::capture(Path::new(schema::string(request, "root")?), request.get("limits").unwrap_or(&json!({}))),
            Some(paths) => capture::capture_with_templates(Path::new(schema::string(request,"root")?), request.get("limits").unwrap_or(&json!({})), paths),
        },
        "capture_publish" => {
            let captured = capture::capture(Path::new(schema::string(request, "root")?), request.get("limits").unwrap_or(&json!({})))?;
            store::publish(Path::new(schema::string(request, "path")?), &captured)
        }
        "publish" => store::publish(Path::new(schema::string(request, "path")?), &request["capture"]),
        "model_batch" => model::batch(&request["context"], &request["observation"]),
        "callback_batch" => callbacks::batch(&request["context"], &request["observation"]),
        "source_comprehension_batch" => source_comprehension::batch(&request["context"], &request["observation"], schema::string(request, "root")?),
        "job_mail_batch" => job_mail::batch(&request["context"], &request["observation"]),
        "erb_template_admit" => erb_template::admit_raw(&request["template"]),
        "open" => {
            let requested = match request.get("generation") { None | Some(Value::Null) => None,
                Some(value) => Some(value.as_str().ok_or_else(|| CoreError::input("Generation must be a string"))?) };
            let mut reader = store::Reader::open(Path::new(schema::string(request, "path")?), requested)?;
            let mut registry = registry().lock().map_err(|_| CoreError::new("internal_error", "Reader registry is unavailable"))?;
            if registry.readers.len() >= 32 {
                return Err(CoreError::limit("Open readers exceed the handle or encoded-data budget; close unused readers"));
            }
            reader.admission = Some(query::budget().reserve(reader.weight)?);
            let handle = registry.next;
            registry.next = registry.next.checked_add(1).ok_or_else(|| CoreError::limit("Reader identity space exhausted"))?;
            let output = json!({"handle":handle,"generation":reader.generation,"manifest":reader.manifest});
            registry.readers.insert(handle, Arc::new(reader));
            Ok(output)
        }
        "close" => {
            let handle = request["handle"].as_u64().ok_or_else(|| CoreError::input("Reader handle is required"))?;
            let mut registry = registry().lock().map_err(|_| CoreError::new("internal_error", "Reader registry is unavailable"))?;
            let closed = registry.readers.remove(&handle).is_some();
            Ok(json!({"closed":closed}))
        }
        "facts" => reader(request)?.all_facts(),
        "fact" => reader(request)?.fact(schema::string(request, "id")?),
        "fact_identity" => fact_identity::select(&*reader(request)?, fact_identity::id(request)?),
        "find" => {
            let limit = match request.get("limit") { None => 50, Some(value) => value.as_u64().ok_or_else(|| CoreError::input("Limit must be an integer"))? };
            if limit > 500 { return Err(CoreError::input("Limit must be between 1 and 500")); }
            reader(request)?.find(schema::string(request, "query")?, limit as usize)
        }
        "find_evidence" => query::search(&*reader(request)?, &query::Query::parse(request)?),
        "source_file" => reader(request)?.source_file(schema::string(request, "file_path")?),
        "source" => reader(request)?.source(schema::string(request, "id")?),
        "links" => reader(request)?.links(schema::string(request, "id")?),
        "model_brief" => model_brief::select(&*reader(request)?, &model_brief::Query::parse(request)?),
        "source_comprehension" => source_comprehension::select(&*reader(request)?, &source_comprehension::Query::parse(request)?),
        "job_mail" => job_mail::select(&*reader(request)?, &job_mail::Query::parse(request)?),
        "callback_effects" => callback_effects::select(&*reader(request)?, &callback_effects::Query::parse(request)?),
        "references" => references::select(&*reader(request)?, &references::Query::parse(request)?),
        "check" => reader(request)?.check(),
        _ => Err(CoreError::input("Unknown native operation")),
    }
}

fn envelope_reserved(bytes: &[u8], reservation: &mut Option<query::Reservation>) -> Value {
    let outcome = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| -> Result<Value> {
        if bytes.len() > schema::MAX_REQUEST { return Err(CoreError::limit("Native request exceeds 128 MiB")); }
        let request: Value = serde_json::from_slice(bytes)?;
        schema::depth(&request)?;
        ensure_process()?;
        *reservation = request_scratch(&request)?;
        dispatch_inner(&request)
    }));
    match outcome {
        Ok(Ok(value)) => json!({"ok":true,"result":value}),
        Ok(Err(error)) => json!({"ok":false,"error":error}),
        Err(_) => json!({"ok":false,"error":{"code":"internal_error","message":"Native operation panicked; no result was returned"}}),
    }
}

/// C bridge owns input bytes for the duration of this call and frees the result
/// exactly once with thistle_response_free. No Ruby objects cross this boundary.
///
/// # Safety
/// Input must address `length` readable bytes, or be null with zero length.
#[no_mangle]
pub unsafe extern "C" fn thistle_request(input: *const u8, length: usize) -> *mut c_char {
    let mut reservation = None;
    let result = if length > schema::MAX_REQUEST || (input.is_null() && length != 0) {
        json!({"ok":false,"error":{"code":"invalid_input","message":"Invalid native request buffer"}})
    } else {
        let bytes = if length == 0 { &[] } else { unsafe { std::slice::from_raw_parts(input, length) } };
        envelope_reserved(bytes, &mut reservation)
    };
    let bytes = serde_json::to_vec(&result).unwrap_or_else(|_| b"{\"ok\":false,\"error\":{\"code\":\"internal_error\",\"message\":\"Serialization failed\"}}".to_vec());
    // JSON always escapes embedded NULs.
    CString::new(bytes).expect("JSON cannot contain a literal NUL").into_raw()
}

/// # Safety
/// `response` must be null or a live pointer returned by thistle_request.
#[no_mangle]
pub unsafe extern "C" fn thistle_response_free(response: *mut c_char) {
    if !response.is_null() { drop(unsafe { CString::from_raw(response) }); }
}

#[cfg(test)]
fn envelope(bytes: &[u8]) -> Value { envelope_reserved(bytes, &mut None) }

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn malformed_input_is_an_error_not_a_panic() {
        assert_eq!(envelope(b"not-json")["ok"], false);
        assert_eq!(envelope(br#"{"op":"not-an-operation"}"#)["error"]["code"], "invalid_input");
        assert_eq!(envelope(br#"{"op":"find","handle":99999,"query":"x"}"#)["error"]["code"], "closed_reader");
        assert_eq!(envelope(br#"{"op":"fact_identity","handle":99999,"id":"bad"}"#)["error"]["code"], "invalid_input");
        let identity = json!({"op":"fact_identity","handle":99999,"id":"b".repeat(64)});
        assert_eq!(envelope(&serde_json::to_vec(&identity).unwrap())["error"]["code"], "closed_reader");
    }
    #[test]
    fn ffi_owns_and_releases_response() {
        let request = br#"{"op":"version"}"#;
        unsafe {
            let response = thistle_request(request.as_ptr(), request.len());
            let result: Value = serde_json::from_slice(std::ffi::CStr::from_ptr(response).to_bytes()).unwrap();
            assert_eq!(result["result"]["engine"], "rust");
            thistle_response_free(response);
            thistle_response_free(std::ptr::null_mut());
        }
    }
}
