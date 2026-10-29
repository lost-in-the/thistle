# Literal Find over saved evidence

`Reader#search_evidence(text, limit: 50, kind: nil, path: nil, domain: nil)`
returns version 1 evidence. `search` and `find` retain their existing name-search
contract. The CLI `find` and Map use evidence search. For example:

```sh
thistle find 'render json:' --store STORE --generation GENERATION --domain source --path app/
thistle source-file app/controllers/items_controller.rb --store STORE --generation GENERATION
```

One trimmed literal (1–256 UTF-8 bytes) is matched case-insensitively for ASCII
letters only. Non-ASCII bytes remain exact: `É` and `é` differ. There are no
embeddings, token conjunctions, regexes, query language, normalization, stemming,
or relevance scores. Original source offsets are never computed from folded
text. Spans use zero-based bytes, exclusive ends, and one-based lines (including
the line containing the exclusive end). Snippets start at the match and contain
at most 384 original bytes, ending on a UTF-8 boundary.

Domains are `all` (default), `source`, and `metadata`. Kind is exact and path is
a case-sensitive captured-path prefix. Source matches have kind `file`, one first
match per captured file, and no invented fact owner. A `method` filter selects
metadata candidates, not all methods that happen to share matching file text.
Spec and concern files are not excluded. Names identify candidates, never runtime
bindings. Metadata results identify their matched field; source results include
an exact span. Each response is generation-pinned.

The metadata allowlist is fact name, kind, path and ID; for route facts only,
controller, action, route_path, route_name, verb, source_status, coherence and
route_constraints.status. Each string is searched only when at most 4096 bytes;
oversized allowed fields are explicitly omitted. Arbitrary attributes, nested
private values and model metadata are not searched. Model keys require a separate
agreed schema. File paths are also captured metadata independent of fact ownership.

Ordering is metadata facts by ID, then manifest file metadata by path, then source
files by path. `limit` is an integer from 1 to 500. `total_matches` counts known
matches, `truncated` means known matches exceed the result limit, and
`search_coverage` separately counts eligible source files, files searched, files
not searched, source matches omitted by the result limit, and first-occurrence
semantics. `total_is_lower_bound` distinguishes an incomplete scan from an exact total.
`status: partial` covers budget exhaustion, omitted fields or unavailable/corrupt
source. Search completeness does not imply complete capture coverage; consult the
same generation's manifest and Check. No empty partial result establishes absence.

## Index and operation costs

The fit assessment in issue #74 considered maintained Tantivy segments, writers,
background merges and the offline vendor/package cost. This bounded literal job
uses an immutable verified source corpus instead. No dependencies, background
threads, persistent index schema or postings were introduced. This is not a
performance claim. Reconsider Tantivy when measured complete-user-job evidence
or richer retrieval justifies those lifecycle costs. The integration owner can
incorporate this decision into the shared decision log.

The first source query builds one corpus per Reader from saved manifest members,
using descriptor-relative no-follow blob reads and digest/byte-count verification.
Each file is loaded once per index attempt, never once per fact. The corpus keeps
its verified bytes until the Reader's last Arc is released. A fresh Reader is
required to retry a partial corpus. Source navigation independently re-verifies
the stored blob; a cached match is not permission to display changed bytes.
No live application filesystem scanning occurs.

All derived reservations use checked arithmetic in the existing process-wide
128 MiB admission policy. Base reader admission retains the existing encoded-data
plus name-cache charge. This policy is not a total RSS bound for all existing JSON
objects or caller-owned results. Added corpus slots are charged before allocation;
source reads reserve twice the declared file size plus 4096 bytes before I/O,
including conservative read-buffer growth. At most 32 MiB of corpus slots and
attempted source reservations is used per Reader, including failed verification
attempts. Missing capacity yields partial coverage, not failure to open an older
generation. A close removes its handle immediately but admission/corpus charges
remain until in-flight reader references have finished.

Each Find operation reserves 2 MiB plus 128 KiB per requested result before work,
covering bounded JSON results, worst-case escaping/serialization and pointer sort
scratch. The source-file operation reserves 64 KiB plus sixteen times the selected file
size (at most the existing 4 MiB source cap) for read growth and escaped output. Reservations are held through C response
serialization; the C bridge then owns and frees the returned response. Concurrent
operations reserve independently. Insufficient operation capacity refuses with
`limit_exceeded`; callers can reduce Find's result limit or close unused readers.
No reader cap is raised. A large admitted reader may permit old APIs but refuse
an evidence query's additional scratch; the refusal is explicit.

Search has at most 32 Mi comparisons/line-count bytes per operation. A separate
bounded corpus-build allowance applies on first use. Literal matching is
worst-case O(text bytes × literal bytes), capped by that comparison budget;
metadata and source use the same budget. Sort costs are O(facts log facts + files
log files) with borrowed keys and no comparator allocation. No source is copied
per term or fact. Result construction stops allocating after the result limit,
while counting further known matches. Partial scans expose coverage and lower
bound totals, not a false complete answer.

## File Source boundary

`Reader#source_file(path)` resolves a safe relative path in the selected manifest;
it cannot open an arbitrary filesystem path. Map accepts
`/source?generation=DIGEST&path=CAPTURED_PATH#LNUMBER`, requires the generation,
and refuses ambiguous fact-ID/file-path requests. The route passes the existing
authorization, host/origin and GET/HEAD gates, uses the existing source byte/line
web caps, escapes/highlights content, and closes the reader on success or error.
It displays file evidence without synthesizing a declaration or Links owner.
Native Source still checks symlinks, regular files, digest, length and UTF-8.

Focused checks live in native query tests, `test/test_find_evidence.rb`, and the
Map Find presenter/file Source tests. These are candidate development checks,
not qualification of L05 or any of the 17 launch capabilities.
