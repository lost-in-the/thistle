//! Optional generation-local name positions and positional continuation. No wire index.
use crate::{error::{CoreError, Result}, query::{Budget, Reservation}, schema};
use serde_json::{json, Value};
use std::{cmp::Ordering, sync::Arc};

pub(crate) fn candidate_name(fact: &Value) -> Option<&str> {
    if (fact["kind"] == "rails_model" && fact["attributes"]["model"]["name"].is_null()) ||
        (fact["kind"] == "rails_save_callbacks" && fact["attributes"]["callbacks"]["name"].is_null()) { return None; }
    fact["name"].as_str()
}

/// Cursors carry positions only, never a caller-supplied completeness/count claim.
pub(crate) fn position(cursor: Option<&Value>, generation: &str, scope: &Value) -> Result<(usize, usize)> {
    let Some(cursor) = cursor.filter(|v| !v.is_null()) else { return Ok((0, 0)); };
    let text = cursor.as_str().filter(|s| s.len() <= 512).ok_or_else(|| CoreError::input("Cursor must be a bounded string"))?;
    let value: Value = serde_json::from_str(text).map_err(|_| CoreError::input("Invalid continuation cursor"))?;
    let token = value.as_array().filter(|v| v.len() == 5).ok_or_else(|| CoreError::input("Invalid continuation cursor"))?;
    if token[0] != "recorded-v1" || token[1] != generation || token[2] != schema::digest(&schema::canonical(scope)?) {
        return Err(CoreError::input("Cursor belongs to another generation or query"));
    }
    let integer = |v: &Value| v.as_u64().and_then(|n| usize::try_from(n).ok())
        .ok_or_else(|| CoreError::input("Invalid continuation position"));
    Ok((integer(&token[3])?, integer(&token[4])?))
}
pub(crate) fn cursor(generation: &str, scope: &Value, position: (usize, usize)) -> Result<Value> {
    Ok(Value::String(serde_json::to_string(&json!(["recorded-v1", generation,
        schema::digest(&schema::canonical(scope)?), position.0, position.1]))?))
}

pub(crate) trait LabelWork { fn compare(&mut self, a: &str, b: &str) -> Result<Ordering>; }
pub(crate) struct Page { pub positions: Vec<usize>, pub total: usize }
pub(crate) struct Directory {
    slots: Vec<usize>, facts: usize, key_bytes: usize, comparisons: usize,
    sort_label_bytes: usize, retained_bytes: usize, _charge: Reservation,
}
impl Directory {
    fn capacity_bytes(capacity: usize) -> Result<usize> {
        capacity.checked_mul(std::mem::size_of::<usize>())
            .and_then(|n| n.checked_add(std::mem::size_of::<std::sync::Mutex<Option<Self>>>()))
            .ok_or_else(|| CoreError::limit("Recorded directory capacity overflow"))
    }
    pub(crate) fn build(facts: &[Value], budget: &Arc<Budget>) -> Result<Self> {
        // Existing saved-fact ceiling. Construction has its own full-domain
        // accounting; it never masquerades as a bounded incremental query.
        if facts.len() > 100_000 { return Err(CoreError::limit("Recorded directory construction allowance exceeded")); }
        let retained_bytes = Self::capacity_bytes(facts.len())?;
        let charge = budget.reserve(retained_bytes)?;
        let mut slots = Vec::new();
        slots.try_reserve_exact(facts.len()).map_err(|_| CoreError::limit("Recorded directory allocation unavailable"))?;
        if Self::capacity_bytes(slots.capacity())? != retained_bytes {
            return Err(CoreError::limit("Recorded directory capacity exceeds reservation"));
        }
        let mut key_bytes = 0;
        for (index, fact) in facts.iter().enumerate() {
            if let Some(name) = candidate_name(fact) {
                key_bytes += name.len() + fact["kind"].as_str().unwrap().len(); slots.push(index);
            }
        }
        let mut comparisons = 0; let mut sort_label_bytes = 0;
        // In-place std sort, no copied labels. Equal keys retain saved fact order.
        slots.sort_unstable_by(|a, b| {
            comparisons += 1;
            let (a_name, b_name) = (candidate_name(&facts[*a]).unwrap(), candidate_name(&facts[*b]).unwrap());
            let (a_kind, b_kind) = (facts[*a]["kind"].as_str().unwrap(), facts[*b]["kind"].as_str().unwrap());
            sort_label_bytes += a_name.len() + b_name.len();
            a_name.cmp(b_name).then_with(|| { sort_label_bytes += a_kind.len() + b_kind.len(); a_kind.cmp(b_kind) }).then(a.cmp(b))
        });
        Ok(Self { slots, facts: facts.len(), key_bytes, comparisons, sort_label_bytes, retained_bytes, _charge: charge })
    }
    pub(crate) fn stats(&self, built: bool) -> Value {
        json!({"status":"complete","built_this_request":built,"facts_visited":self.facts,
            "eligible_facts":self.slots.len(),"key_bytes":self.key_bytes,"sort_comparisons":self.comparisons,
            "sort_compared_label_bytes":self.sort_label_bytes,"slot_capacity":self.slots.capacity(),
            "slot_bytes":std::mem::size_of::<usize>(),"retained_bytes":self.retained_bytes,
            "accounting":"Reserved vector capacity and container; borrowed labels. Not complete heap/RSS. Fresh Reader rebuilds; same Reader reuses."})
    }
    pub(crate) fn page(&self, facts: &[Value], name: &str, kind: Option<&str>, offset: usize,
        limit: usize, work: &mut impl LabelWork) -> Result<Page> {
        let mut bound = |upper: bool| -> Result<usize> {
            let (mut lo, mut hi) = (0, self.slots.len());
            while lo < hi {
                let mid = lo + (hi - lo) / 2;
                let fact = &facts[self.slots[mid]];
                let mut order = work.compare(candidate_name(fact).unwrap(), name)?;
                if order == Ordering::Equal {
                    if let Some(kind) = kind { order = work.compare(fact["kind"].as_str().unwrap(), kind)?; }
                }
                if order == Ordering::Less || upper && order == Ordering::Equal { lo = mid + 1; } else { hi = mid; }
            }
            Ok(lo)
        };
        let start = bound(false)?; let end = bound(true)?;
        let total = end - start;
        if offset > total { return Err(CoreError::input("Continuation exceeds the candidate range")); }
        Ok(Page { positions: self.slots[start + offset..start + offset + limit.min(total - offset)].to_vec(), total })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    struct Work;
    impl LabelWork for Work {
        fn compare(&mut self, a: &str, b: &str) -> Result<Ordering> { Ok(a.cmp(b)) }
    }
    #[test]
    fn exact_ranges_global_ambiguity_reservation_and_lifetime() {
        let facts=vec![json!({"name":"User","kind":"class"}),
            json!({"name":"Admin::User","kind":"class"}),
            json!({"name":"User","kind":"rails_save_callbacks","attributes":{"callbacks":{"name":"User"}}}),
            json!({"name":"Anonymous model 0","kind":"rails_model","attributes":{"model":{"name":null}}}),
            json!({"name":"User","kind":"class"})];
        let bytes=Directory::capacity_bytes(facts.len()).unwrap();
        let budget=Budget::new(bytes);
        assert!(Directory::build(&facts,&Budget::new(bytes-1)).is_err());
        let directory=Directory::build(&facts,&budget).unwrap();
        assert!(budget.reserve(1).is_err());
        let page=directory.page(&facts,"User",None,0,1,&mut Work).unwrap();
        assert_eq!(page.total,3); assert_eq!(page.positions,vec![0]);
        assert_eq!(directory.page(&facts,"User",Some("class"),1,1,&mut Work).unwrap().positions,vec![4]);
        assert_eq!(directory.page(&facts,"User",Some("rails_save_callbacks"),0,1,&mut Work).unwrap().total,1);
        assert_eq!(directory.page(&facts,"Missing",None,0,1,&mut Work).unwrap().total,0);
        assert_eq!(directory.page(&facts,"Anonymous model 0",None,0,1,&mut Work).unwrap().total,0);
        assert!(directory.page(&facts,"User",None,4,1,&mut Work).is_err());
        drop(directory); assert!(budget.reserve(bytes).is_ok());
    }
    #[test]
    fn cursor_scope_generation_and_malformed_positions_refuse() {
        let scope=json!(["references","anchor","incoming"]);
        let token=cursor("generation",&scope,(20000,50000)).unwrap();
        assert_eq!(position(Some(&token),"generation",&scope).unwrap(),(20000,50000));
        assert!(position(Some(&token),"new-generation",&scope).is_err());
        assert!(position(Some(&token),"generation",&json!(["another query"])).is_err());
        for value in [json!(false),json!("[]"),json!("x".repeat(513)),json!("not-json")] {
            assert!(position(Some(&value),"generation",&scope).is_err());
        }
    }
}
