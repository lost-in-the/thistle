//! Optional, immutable method positions belonging to exactly one saved Reader.
use crate::{error::{CoreError, Result}, query::{Budget, Reservation}};
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::{cmp::Ordering, sync::Arc};

pub(crate) const MAX_KEY_BYTES: usize = 32 * 1024 * 1024;
const MAX_BUILD_FACTS: usize = 100_000; // Existing saved-fact schema ceiling.
const MAX_SORT_COMPARISONS: usize = MAX_BUILD_FACTS * 64;

pub(crate) fn key(fact: &Value) -> Option<(&str, &str)> {
    if fact["kind"] != "method" || fact["evidence"] != "static" || fact["attributes"]["singleton"] == true { return None; }
    Some((fact["attributes"]["owner"].as_str()?, fact["attributes"]["method_name"].as_str()?))
}

#[derive(Default, Clone, Copy)]
pub(crate) struct Counts { pub methods: usize, pub key_bytes: usize }
impl Counts {
    pub(crate) fn record(&mut self, fact: &Value) -> Result<()> {
        if let Some((owner, name)) = key(fact) {
            self.methods = self.methods.checked_add(1).ok_or_else(|| CoreError::limit("Method count overflow"))?;
            self.key_bytes = self.key_bytes.checked_add(owner.len()).and_then(|n| n.checked_add(name.len()))
                .ok_or_else(|| CoreError::limit("Method key accounting overflow"))?;
        }
        Ok(())
    }
}

fn digest(owner: &str, name: &str) -> [u8; 32] {
    let mut hash = Sha256::new();
    hash.update(b"thistle/saved-instance-method/v1\0");
    for label in [owner, name] {
        hash.update((label.len() as u64).to_be_bytes());
        hash.update(label.as_bytes());
    }
    hash.finalize().into()
}

struct Slot { digest: [u8; 32], fact: usize }
pub(crate) struct Directory {
    slots: Vec<Slot>,
    facts_visited: usize,
    key_bytes: usize,
    sort_comparisons: usize,
    retained_bytes: usize,
    _charge: Reservation,
}

/// Each comparison/visit consumes the caller's unchanged shared request caps.
pub(crate) trait Work {
    fn visit(&mut self) -> bool;
    fn bytes(&mut self, bytes: usize) -> bool;
    fn compare(&mut self, a: &str, b: &str) -> Option<Ordering>;
    fn compare_digest(&mut self, a: &[u8; 32], b: &[u8; 32]) -> Option<Ordering>;
}

#[derive(Debug, PartialEq)]
pub(crate) struct Match {
    pub candidate: Option<usize>,
    /// Capped at two: two exact matches prove ambiguity, not a total count.
    pub matches: usize,
    pub decided: bool,
    pub range_complete: bool,
}

impl Directory {
    fn capacity_bytes(methods: usize) -> Result<usize> {
        methods.checked_mul(std::mem::size_of::<Slot>())
            .and_then(|n| n.checked_add(std::mem::size_of::<std::sync::Mutex<Option<Self>>>()))
            .ok_or_else(|| CoreError::limit("Method directory capacity overflow"))
    }

    pub(crate) fn build(facts: &[Value], counts: Counts, budget: &Arc<Budget>) -> Result<Self> {
        if facts.len() > MAX_BUILD_FACTS || counts.methods > facts.len() || counts.key_bytes > MAX_KEY_BYTES {
            return Err(CoreError::limit("Method directory construction allowance exceeded"));
        }
        // The inline container is charged here, never added to Reader.weight.
        // No retained allocation or construction precedes capacity admission.
        let retained_bytes = Self::capacity_bytes(counts.methods)?;
        let charge = budget.reserve(retained_bytes)?;
        let mut slots = Vec::new();
        slots.try_reserve_exact(counts.methods).map_err(|_| CoreError::limit("Method directory allocation unavailable"))?;
        if Self::capacity_bytes(slots.capacity())? != retained_bytes {
            return Err(CoreError::limit("Method directory allocator capacity exceeds reservation"));
        }
        let mut visited = Counts::default();
        for (fact, value) in facts.iter().enumerate() {
            visited.record(value)?;
            if let Some((owner, name)) = key(value) {
                // Also protects internal test Readers that violate immutability.
                if slots.len() == slots.capacity() || visited.key_bytes > MAX_KEY_BYTES {
                    return Err(CoreError::limit("Method directory inventory changed"));
                }
                slots.push(Slot { digest: digest(owner, name), fact });
            }
        }
        if visited.methods != counts.methods || visited.key_bytes != counts.key_bytes {
            return Err(CoreError::limit("Method directory inventory changed"));
        }
        let mut sort_comparisons = 0;
        // Fixed keys, in-place std sort: comparator remains total even if the
        // completed sort exceeds its allowance. Never publish an over-budget build.
        slots.sort_unstable_by(|a, b| { sort_comparisons += 1; a.digest.cmp(&b.digest) });
        if sort_comparisons > MAX_SORT_COMPARISONS {
            return Err(CoreError::limit("Method directory sort allowance exceeded"));
        }
        Ok(Self { slots, facts_visited: facts.len(), key_bytes: counts.key_bytes,
            sort_comparisons, retained_bytes, _charge: charge })
    }

    pub(crate) fn stats(&self, built: bool) -> Stats {
        Stats { built, facts: self.facts_visited, methods: self.slots.len(), key_bytes: self.key_bytes,
            comparisons: self.sort_comparisons, capacity: self.slots.capacity(), retained_bytes: self.retained_bytes }
    }

    pub(crate) fn lookup(&self, facts: &[Value], owner: &str, name: &str, work: &mut impl Work) -> Match {
        let mut found = Match { candidate: None, matches: 0, decided: false, range_complete: false };
        if !work.bytes(owner.len().saturating_add(name.len())) { return found; }
        let digest = digest(owner, name);
        let (mut lo, mut hi) = (0, self.slots.len());
        while lo < hi {
            let mid = lo + (hi - lo) / 2;
            match work.compare_digest(&self.slots[mid].digest, &digest) {
                Some(Ordering::Less) => lo = mid + 1,
                Some(_) => hi = mid,
                None => return found,
            }
        }
        for slot in &self.slots[lo..] {
            match work.compare_digest(&slot.digest, &digest) {
                Some(Ordering::Equal) => {},
                Some(_) => { found.decided = true; found.range_complete = true; return found; },
                None => return found,
            }
            if !work.visit() { return found; }
            let Some((actual_owner, actual_name)) = key(&facts[slot.fact]) else { return found; };
            let Some(owner_order) = work.compare(actual_owner, owner) else { return found; };
            let Some(name_order) = work.compare(actual_name, name) else { return found; };
            if owner_order == Ordering::Equal && name_order == Ordering::Equal {
                found.matches += 1;
                if found.matches == 2 { found.candidate = None; found.decided = true; return found; }
                found.candidate = Some(slot.fact);
            }
        }
        found.decided = true;
        found.range_complete = true;
        found
    }
}

#[derive(Clone, Copy)]
pub(crate) struct Stats { built: bool, facts: usize, methods: usize, key_bytes: usize, comparisons: usize, capacity: usize, retained_bytes: usize }
impl Stats {
    pub(crate) fn value(&self) -> Value {
        json!({"status":"complete","built_this_request":self.built,"builds_for_reader":1,
            "facts_visited":self.facts,"eligible_methods":self.methods,"key_bytes":self.key_bytes,
            "sort_comparisons":self.comparisons,"slot_bytes":std::mem::size_of::<Slot>(),
            "slot_capacity":self.capacity,"container_bytes":std::mem::size_of::<std::sync::Mutex<Option<Directory>>>(),
            "retained_bytes":self.retained_bytes,"budgets":{"facts":MAX_BUILD_FACTS,"key_bytes":MAX_KEY_BYTES,
                "sort_comparisons":MAX_SORT_COMPARISONS}})
    }
}

#[cfg(test)]
#[path = "method_lookup_tests.rs"]
mod tests;
