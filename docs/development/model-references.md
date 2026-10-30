# Follow recorded model references

Select a class/model in Find, open Links, then choose Incoming references or
Outgoing references. Follow a named candidate to its Links or Captured Source.
Every destination carries the saved generation. A newer CURRENT does not replace
that evidence. No captured source is shown explicitly for runtime-only facts.
Existing outgoing Links and representative call-source details remain available.

```ruby
reader = Thistle::Reader.new(store, generation: saved_generation)
begin
  incoming = reader.references(model_id, direction: 'incoming', limit: 50)
  outgoing = reader.references(model_id) # outgoing, limit 50
ensure
  reader.close
end
```

The native `references` operation takes the existing Reader handle, `id`,
`direction` (`incoming` or `outgoing`) and integer `limit` (1–500, default 50).
Invalid parameters, missing facts, closed handles and admission failures refuse
rather than selecting another generation. Ruby forwards the request; Rust owns
selection, candidate identity validation, uncertainty and budgets.

The response has `generation`, a compact `anchor` identity, `direction`, `limit`,
`relationships`, `coverage` and a semantics explanation. Each relationship has
its compact origin, semantic link, any detail omission, candidate label, bounded
candidate identities, known candidate matches and candidate-search completeness.
The query borrows stored facts and uses the schema-aware `SemanticLinkView`;
it does not call `all_facts`, retain another dataset, or build a query index.

An outgoing relationship is a recorded link on the selected fact. Incoming
relationships match a recorded target label to the selected fact's full name.
Recognized call metadata instead matches its recorded constant receiver label;
the method selector is insufficient. Other receiver forms do not establish a
model candidate. Labels are exact, case-sensitive strings: `Admin::User` does
not become `User`. Synthetic anonymous model names are not candidate labels.
Schema 1 unknown metadata remains opaque, including colliding version-2 data;
schema 2/3 recognized receiver metadata uses the existing decoder.

Candidate IDs are facts in this generation whose full name matches the label.
Duplicate static declarations and runtime observations remain separate candidates.
Even one candidate is **name match / binding unknown**. A resolution string never
establishes canonical identity, runtime dispatch, execution or source coherence.
Recorded link groups are neither macro counts nor textual occurrence counts.
This path does not infer associations that capture never recorded.

## Bounded work and evidence

Relationships follow stored stable-ID order, then the recorded link order.
Candidates follow the same stable fact order. There is no pagination cursor or
hidden whole-dataset fallback; increase the result limit for a larger prefix.

Each request admits a 32 MiB transient reservation through the existing aggregate
Reader/query budget, held through native response serialization. It scans at most
20,000 facts and 50,000 links, performs at most 100,000 label comparisons and
charges at most 16 MiB of compared label bytes. Outgoing candidate discovery shares
the comparison/byte budgets and visits at most 20,000 facts once, comparing only
the returned relationships. At most four candidate identities are emitted per
relationship. This bounded nested comparison avoids a retained index and its
invalidation/accounting cost; wide result limits can exhaust candidate search
before all facts are examined.

Selected relationship/candidate payloads share a 2 MiB encoded budget (the small
envelope and counters are additional). Individual link detail is capped at 16 KiB;
oversized detail becomes a relation/target/resolution summary. Identity projection
includes only standard identity/source fields, never model attributes or link trees;
identities above 32 KiB are refused. Reservation is conservative accounting, not a
measured process-RSS promise. No speed improvement is claimed.

Coverage distinguishes:

- Capture partiality/unavailability, summarized from up to 256 pinned coverage
  families (further families make capture coverage unknown/partial); Check
  retains its original scoped explanations.
- Known matching and omitted relationships in the searched prefix.
- Incomplete scan: remaining input is not searched and its match count is unknown.
- Candidate-search completeness, known matches, and candidates omitted from display.

Incoming results identify the chosen anchor as a label match without performing a
global uniqueness search. Candidate-search completeness therefore stays false for
incoming results. Empty results always say they concern searched recorded evidence;
they never establish that a model has no references. A complete query scan cannot
repair partial capture.

Map keeps its access checks, 4,096-byte query limit, escaping, keyboard focus and
no-JavaScript links. Reference candidate links contain only validated native IDs
and the pinned generation; they do not need to retain Find filters to identify the
destination. Source still verifies the captured bytes under the existing limits.

## Review and validation boundary

The implementation adds no dependency, schema, capture behavior, persistent cache,
FFI ownership rule or installation hook. The existing shared registry retains the
Reader during the query; closing it prevents later requests. Only bounded requested
output crosses the normal JSON bridge. The existing outgoing detail view remains
its own legacy API; the new selector does not expand its scan to feed that view.

Focused native tests cover fixed answers, duplicate/namespaced labels, no source,
schema 1 opacity and schema 2/3 receivers, known omission versus unsearched input,
candidate saturation, generation replacement, parameter refusal and handle close.
Fresh Ruby/Map checks cover actual native loading, candidate navigation, old pinned
Source after publication, authorization, query rejection and HTML escaping.
Development evidence does not qualify installed package pairing, other support
cohorts, launch capabilities or a release. Root owns integration and settled package
checks; Leah owns acceptance.
