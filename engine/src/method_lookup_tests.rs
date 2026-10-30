use super::*;

fn method(owner: &str, name: &str) -> Value {
    json!({"kind":"method","evidence":"static","attributes":{"owner":owner,"method_name":name,"singleton":false}})
}
fn counts(facts: &[Value]) -> Counts {
    let mut counts = Counts::default();
    for fact in facts { counts.record(fact).unwrap(); }
    counts
}
struct Meter { facts: usize, bytes: usize }
impl Work for Meter {
    fn visit(&mut self) -> bool { if self.facts == 0 { return false; } self.facts -= 1; true }
    fn bytes(&mut self, n: usize) -> bool { if n > self.bytes { return false; } self.bytes -= n; true }
    fn compare(&mut self, a: &str, b: &str) -> Option<Ordering> { self.bytes(a.len() + b.len()).then(|| a.cmp(b)) }
    fn compare_digest(&mut self, a: &[u8; 32], b: &[u8; 32]) -> Option<Ordering> { self.bytes(64).then(|| a.cmp(b)) }
}
fn meter() -> Meter { Meter { facts: 20_000, bytes: MAX_KEY_BYTES } }

#[test]
fn exact_eligibility_includes_incomplete_and_unresolved_duplicates() {
    let good = method("Record", "deliver");
    let mut unresolved = good.clone(); unresolved["attributes"]["name_resolution"] = json!("unresolved_receiver");
    unresolved["attributes"].as_object_mut().unwrap().remove("singleton");
    let mut singleton = good.clone(); singleton["attributes"]["singleton"] = json!(true);
    let mut runtime = good.clone(); runtime["evidence"] = json!("runtime");
    let mut ownerless = good.clone(); ownerless["attributes"]["owner"] = Value::Null;
    let facts = vec![good, unresolved, singleton, runtime, ownerless, json!({"kind":"class"})];
    let counts = counts(&facts);
    assert_eq!(counts.methods, 2);
    let directory = Directory::build(&facts, counts, &Budget::new(1024)).unwrap();
    let found = directory.lookup(&facts, "Record", "deliver", &mut meter());
    assert_eq!(found.matches, 2); assert!(found.decided); assert!(!found.range_complete);
    assert_eq!(found.candidate, None);
    assert_ne!(digest("ab", "c"), digest("a", "bc"));
}

#[test]
fn collisions_require_borrowed_key_equality_and_incomplete_ranges_never_bind() {
    let facts = vec![method("Other", "deliver"), method("Record", "deliver")];
    let mut directory = Directory::build(&facts, counts(&facts), &Budget::new(2048)).unwrap();
    // Force a cryptographic collision at the directory boundary, independently
    // of the hash implementation. Both colliding facts must actually be visited.
    for (i, slot) in directory.slots.iter_mut().enumerate() { slot.digest = digest("Record", "deliver"); slot.fact = i; }
    let mut work = meter();
    let found = directory.lookup(&facts, "Record", "deliver", &mut work);
    assert_eq!(found.candidate, Some(1)); assert!(found.decided && found.range_complete);
    assert_eq!(work.facts, 19_998);
    let found = directory.lookup(&facts, "Record", "deliver", &mut Meter { facts: 1, bytes: MAX_KEY_BYTES });
    assert!(!found.decided);
    let found = directory.lookup(&facts, "Record", "deliver", &mut Meter { facts: 20_000, bytes: 1 });
    assert!(!found.decided && !found.range_complete);
    assert_eq!(directory.lookup(&facts, "Absent", "call", &mut meter()).candidate, None);
}

#[test]
fn capacity_admission_refusal_and_drop_return_the_exact_reservation() {
    let facts = vec![method("Record", "deliver")];
    let bytes = Directory::capacity_bytes(1).unwrap();
    let budget = Budget::new(bytes);
    let held = budget.reserve(1).unwrap();
    assert_eq!(Directory::build(&facts, counts(&facts), &budget).err().unwrap().code, "limit_exceeded");
    drop(held);
    let directory = Directory::build(&facts, counts(&facts), &budget).unwrap();
    assert_eq!(directory.retained_bytes, bytes);
    let stats = directory.stats(true).value();
    assert_eq!(stats["retained_bytes"].as_u64().unwrap(),
        stats["slot_capacity"].as_u64().unwrap() * stats["slot_bytes"].as_u64().unwrap() +
        stats["container_bytes"].as_u64().unwrap());
    assert!(budget.reserve(1).is_err());
    drop(directory);
    let all = budget.reserve(bytes).unwrap(); drop(all);
    let refused = Counts { methods: 1, key_bytes: MAX_KEY_BYTES + 1 };
    assert!(Directory::build(&facts, refused, &budget).is_err());
    assert!(budget.reserve(bytes).is_ok());
    assert!(Directory::capacity_bytes(usize::MAX).is_err());
}
