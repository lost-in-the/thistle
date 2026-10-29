# Schema-3 tagged call links

LOS-53 implements the schema-3 encoding contract selected by LOS-52. This initial
source phase supplies an **uncomposed module and authored tests**. It does not
enable schema 3: module registration, shared schema helpers, capture accounting,
publication, Reader outputs, runtime accounting and the matching Core/Map pair
still require root's integration. No runtime checks or workload results are
claimed for this phase. LOS-45's full-application outcome remains failed/unproven.

## Wire and semantic boundaries

Snapshot schema is explicit: supported contexts are exactly 1, 2 and 3. A missing
Capture selector continues to select 1. Producer fields and payload shape never
select a schema. New native capture will explicitly select 3 and retain
`producer.call_target_schema: 2`; `producer.link_encoding_schema: 1` describes the
encoding without selecting it. Legacy publication keeps its original bytes and
generation identity. No migration, rewriting or inferred upgrade occurs.

Capture facts, `Store#publish` inputs and public Reader outputs contain semantic
object links. Stored schema-3 links may instead contain this exact row:

```json
[0, "method_name", ["implicit", null, false, false, [0, 11, 1, 1], null]]
```

The three slots are the unsigned integer tag `0`, unchanged target, and unchanged
six-slot compact-v2 DATA. DATA means receiver kind, receiver name, omitted flag,
safe-navigation flag, call coordinates, receiver coordinates. Coordinates remain
start byte, end byte, start line, end line. Nulls, booleans, names and every
coordinate survive exactly. The equivalent semantic link is:

```json
{
  "attributes": {
    "thistle_call": {
      "data": ["implicit", null, false, false, [0, 11, 1, 1], null],
      "version": 2
    }
  },
  "relation": "calls",
  "resolution": "unresolved",
  "target": "method_name"
}
```

Packing requires static parent evidence, relation `calls`, resolution
`unresolved`, valid recognized compact-v2 DATA, and these **complete** key sets:

| Object | Exact keys |
| --- | --- |
| Link | `attributes`, `relation`, `resolution`, `target` |
| Attributes | `thistle_call` |
| Call extension | `data`, `version` (integer `2`) |

Any extra key prevents packing; the complete original object survives. Recognized
malformed data still refuses, including inside an extra-key wrapper. Schema 2
keeps its existing extra-key refusal for recognized extensions. Schema 1 keeps
v2 entirely opaque, even for an exact valid compact lookalike. Schemas 2 and 3
interpret recognized v1/v2; other extension versions remain opaque under the
existing depth and byte bounds. V1 and opaque extensions retain object encoding.

Rows refuse under schemas 1/2, runtime evidence, semantic publication input, or
invalid/unknown context. Schema-3 wire rows require exactly three slots, integer
tag 0, a valid target and strict DATA. Boolean/float/string tags, unknown tags,
nested row misuse and malformed recognized metadata refuse.

## Borrowed API and required shared hooks

`engine/src/link_encoding.rs` centralizes row positions and semantic constants:

| API | Responsibility |
| --- | --- |
| `SemanticLinkView::from_semantic(link, version, evidence)` | Borrow an object; reject row input. |
| `SemanticLinkView::from_wire(link, version, evidence)` | Borrow an object or explicit schema-3 static row. |
| `relation`, `target`, `resolution`, `call_metadata` | Inspect borrowed semantic fields without owned-object reconstruction. |
| `WireLink::new(link, version, evidence)` | Serialize eligible semantic objects as rows with serde `SerializeTuple`; delegate all fallback objects unchanged. |
| `WireFact::new(fact, version)` | Borrow all fact entries, projecting only the links sequence. |
| `WireFacts::new(ordered_refs, version)` | Serialize the caller's existing stable-ID fact order. |
| `SemanticLinkView::materialize`, `materialize_fact`, `materialize_links` | Produce only requested semantic output through serde, with no retained expanded cache. |

Root owns the following existing-source seams. The new module deliberately calls
them rather than copying their implementations or creating a test-only encoder:

- `schema::compact_call_metadata(data: &Value) -> Result<CallMetadata<'_>>`:
  extract the existing six-slot decoder for direct borrowed DATA validation.
- `schema::validate_call_shape(&CallMetadata) -> Result<()>`: extract the existing
  receiver/name/omitted/implicit/safe-navigation rules. Source/blob/UTF-8/line
  bounds remain full fact validation, including the existing heredoc behavior.
- `schema::call_metadata(ext, version)`: retain schema-1 opacity and schema-2
  exact-key validation; recognize explicit 3 and validate recognized DATA even
  when a schema-3 extension's extra keys require object fallback.
- Use the existing generic `schema::encoded_bytes<T: Serialize + ?Sized>` seam
  from accepted Model source. The initial base predates this helper. No new
  counter, admission framework, serializer, dependency or Cargo change is added.

The module does not sort links or facts, compute identities, alter grouping, or
choose representatives. Existing semantic sort keys and equal-start behavior
must remain unchanged. Full validation precedes authoritative serialization;
the projection alone does not establish captured source bounds or provenance.

## Accounting and integration obligations

Capture must count the **same WireLink/WireFact bytes** before append or
replacement. Preserve checked arithmetic and conservative separators: two array
brackets initially, existing per-member charges, checked positive replacement
deltas before mutation and safe refunds for smaller replacements. Do not
serialize the growing facts array on every append.

Publication independently validates the actual complete semantic capture and
serializes its ordered references through `WireFacts` into one bounded
`facts.json` of at most 67,108,864 bytes, before any filesystem mutation. Existing
manifest limits and Reader preflight remain. A shared bounded serde sink stops
oversized output; root owns that existing-source integration. Counting rows and
then publishing expanded objects would violate the admission contract.

The native Capture accounting hint is planned as
`evidence_accounting: {schema_version: 3, fact_bytes_upper_bound: N}`. It is
untrusted schema-bound admission context. The in-process Ruby facade must reject
missing/malformed/mismatched hints in its schema-3 native path and add only each
runtime batch's conservative charge. It must not size all static objects again
or send them across another native sizing request. Runtime routes and Model
facts stay objects; Model's counters, normalization, IDs and provenance retain
their meanings. Publication ignores hints and recounts actual complete facts.

Reader must retain compact wire rows and use borrowed views for validation and
comparison. All public facts/fact/find/source/links outputs materialize semantic
objects only for requested results. Bulk audit output may expand all requested
facts transiently; it is a separate cost from ordinary queries. The unchanged
128 MiB aggregate Reader admission, 32 handles, source/query reservations,
request/GVL/buffer/close lifecycles and 128 MiB transport limit still apply.
Encoded bytes do not bound decoded heap or process RSS.

Map must explicitly support contexts 2 and 3 through semantic Core output. It
must not decode rows or use a `>= 2` gate. Root owns exact pre3 versions/pairing,
the Map gate and the accepted Model/Find/diagnostic/callback/platform composition.
Old generations remain accessible without rewriting them.

## Evidence scope and next checks

Authored small unit checks cover exact roundtrip and eligibility, complete
extra-key fallback, malformed rows, recognized-data refusal, receiver values,
schema-1 opaque-v2 isolation, legacy encoded bytes, real serializer/count equality
with escaping/Unicode/integer extremes/exact byte boundaries, and requested-only
materialization. They are not registered or run in this initial phase.

After shared integration and a finite execution grant, run these checks and the
existing affected capture replacement/refusal, source-bound, old-generation,
Reader/native lifecycle and installed runtime/Map contracts. Add focused hint
and independent-publication-recount regressions at those existing boundaries.
Unrun compilation, CI, installed audits and full workload acceptance remain
explicitly outstanding; this module alone cannot complete LOS-53.

The 103 fixed bytes removed per eligible envelope is format arithmetic only.
There is no measured saving, full total/fit, speed, RSS or completed customer
journey result for these bytes. Root owns the one fixed LOS-45 full
capture→publish→fresh Reader/Map acceptance plan on settled reviewed packages,
after a separate finite custodian/host grant. Failure stops dependent work;
another refusal remains failed. No execution is authorized by this document.
