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
The query borrows stored facts and uses the schema-aware `SemanticLinkView`.
Exact candidate lookup uses an optional admitted Reader-local directory of fact
positions, without copying labels or retaining another link dataset. See the
[recorded-domain continuation contract](recorded-domain-access.md) for public
Reader/CLI paging, global candidate counts and separate construction costs.

An outgoing relationship is a recorded link on the selected fact. Incoming
relationships match the selected fact's full name against a recorded target's
matching key. Recognized call metadata uses its non-omitted constant receiver,
removing exactly one leading `::` for matching while preserving the recorded
spelling; the method selector is insufficient. Other receiver forms do not
establish a model candidate, and arbitrary targets retain literal matching.
Matching is case-sensitive and preserves namespaces: `::Admin::User` matches
`Admin::User`, never `User`. See the
[root-qualified receiver contract](https://github.com/lost-in-the/thistle/blob/b46656bcf65d713362e5e42067e638271816aba6/docs/development/root-qualified-references.md)
for schema boundaries, original-byte accounting and uncertainty. Synthetic
anonymous model names are not candidate labels.
Schema 1 unknown metadata remains opaque, including colliding version-2 data;
schema 2/3 recognized receiver metadata uses the existing decoder.

Candidate IDs are facts in this generation whose full name matches that key.
Duplicate static declarations, model metadata and registered-callback observations
remain separate named candidates; anonymous model/callback display names do not.
Even one candidate is **name match / binding unknown**. A resolution string never
establishes canonical identity, runtime dispatch, execution or source coherence.
Recorded link groups are neither macro counts nor textual occurrence counts.
This path does not infer associations that capture never recorded.

## Bounded work and evidence

Relationships follow stored stable-ID order, then the recorded link order.
Candidate pages follow matching key, kind and saved fact position. Public Reader
and CLI calls return a generation/query-bound `next_cursor`; following it from
the beginning exhausts the selected recorded domain. Counts and completeness
refer to the remaining cursor domain, not the application or earlier pages.
Map currently renders its bounded page; no Map pagination UI is claimed here.

Each request admits a 32 MiB transient reservation through the existing aggregate
Reader/query budget, held through native response serialization. It scans at most
20,000 facts and 50,000 links, performs at most 100,000 label comparisons and
charges at most 16 MiB of compared label bytes. These are per-step limits;
continuation resumes at saved fact/link positions instead of rescanning the
consumed prefix. Outgoing candidate lookup shares comparison/byte admission and
uses exact global directory ranges before reporting uniqueness or ambiguity.
At most four candidate identities are emitted per relationship; pinned candidate
pages expose the rest. Directory construction, capacity reservation, reuse and
rebuilding on a fresh Reader are separate full-domain costs, never hidden in the
incremental scan allowance. Resource refusal remains explicit.

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
If reference admission reaches a resource limit, Map reports the unavailable
selection and preserves existing outgoing details; invalid snapshots and
generation mismatches still refuse. Incoming views use the query's compact anchor
and never request the anchor's expanded fact or outgoing links. Detailed model
and callback metadata is not loaded in this view; the identity tiles say so.
A resource refusal (`Thistle::LimitExceeded`) shows the limit notice; a Reader
without the references API shows its unavailable notice. Neither expands a
fallback fact. Integrity refusals such as `Thistle::InvalidSnapshot` return 422;
they are not converted into an unavailable result. Source navigation resumes
when a bounded identity is available.

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
