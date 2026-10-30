# Exhaust recorded reference and model-brief discovery domains

LOS-68 extends the bounded references and model-brief slice. A saved answer can
require several bounded steps; a fixed scanned prefix must not hide it forever.
This contract supersedes the fixed-prefix/no-pagination descriptions in
`model-references.md` and the registry-discovery portion of
`loaded-model-evidence.md`. Those files retain earlier evidence identities.
Root owns reconciliation of shared documentation and package manifests.

The scope is recorded outgoing/incoming relationships, exact named candidates,
model-to-registry label discovery, and the brief's allowlisted column/association
projections. Capture completeness, canonical binding, effective runtime code,
invocation and execution remain separate unknowns. A diagnostic finding that
14 of 29 recorded files were accessible is not a semantic recall or application
coverage result. The earlier ordinal-20,050 method proof covers another domain.
All 17 launch capabilities remain unqualified.

## Public continuation

```ruby
r = Thistle::Reader.new(store, generation: saved_generation)
begin
  cursor = nil
  loop do
    page = r.references(id, direction: 'incoming', limit: 50, cursor: cursor)
    consume(page.fetch('relationships'))
    cursor = page.fetch('next_cursor')
    break unless cursor
  end
ensure
  r.close
end
```

Each relationship identifies its saved `origin.id` and zero-based `link_ordinal`.
These together identify one logical recorded link group, including distinct
identical-looking groups. Relationships follow saved fact order, then saved link
order. A page stops on the existing visit/comparison/byte bounds, output size or
result limit. It may contain no matches and still have a continuation.

`next_cursor` is an opaque string or null. Pass it to the same operation, anchor,
direction and generation. Result limits may change. Rust validates bounded token
shape, scope, generation and positions. Tokens contain no trusted aggregate count
or claim about previously searched input. They are positional bookmarks, not
authorization credentials: existing store access controls still apply. Every
emitted continuation advances; no work-progress refusal emits a circular cursor.
Following returned cursors from the beginning exhausts the selected saved domain.
Replaying a token repeats and charges that step's work. A suspended fact can be
visited again, but its consumed link prefix is not traversed again.

`coverage.scan_scope` is `remaining_cursor_domain`; `start_position` records that
domain's start. `scan_complete` means the suffix is exhausted, and `not_searched`
means there is remaining input. `known_matches` counts this page's relationships.
Outgoing links have an exact known remainder; incoming unsearched matches remain
unknown. A final empty suffix does not erase earlier pages. Complete no-match is
established only by a complete traversal with no matches. Capture partiality and
unknown label binding remain visible even after traversal completes.

Outgoing rows carry full-domain `candidate_matches` and
`candidate_search_complete`, at most four candidate identities, and a pinned
`candidate_followup`. Enumerate all candidate identities with:

```ruby
r.references(origin_id, candidate_link: saved_link_ordinal, limit: 50, cursor: token)
```

Candidate pages return `candidates`, the exact global `candidate_matches`,
`candidate_status`, `page_complete` and `next_cursor`. A far-end duplicate makes
the first page ambiguous. Zero matches means no saved label candidate; one means
unique label/binding unknown. Incoming rows identify only the selected anchor and
keep global candidate-search completeness false. Candidate ordering is exact
label, kind, then saved fact position; anonymous synthetic names are excluded.

The literal CLI requires an explicit generation:

```sh
thistle references ID --store STORE --generation GENERATION --direction incoming --cursor TOKEN
thistle references ORIGIN_ID --store STORE --generation GENERATION --candidate-link ORDINAL --cursor TOKEN
thistle model-brief MODEL_ID --store STORE --generation GENERATION --family registry_candidates --cursor TOKEN
```

Omit `--cursor` on the first step. CLI opens exactly the requested generation and
closes its Reader on success or error. Ruby only forwards primitive parameters;
Rust owns selection and continuation. No C ABI or callback algorithm changes.

## Bounded brief and usable underlying evidence

The ordinary summary keeps its existing ID/limit/max-bytes defaults. Every
columns, associations, registry-candidates, incoming and outgoing family exposes
a pinned `followup` even if the summary drops every optional item. Follow-ups
start independent enumeration at zero; do not append a summary prefix to those
pages and count it twice. Summary pruning never advances a family cursor past
unreturned items.

`model_brief(id, family: 'columns' | 'associations' | 'registry_candidates',
cursor: token, limit: 8, max_bytes: 32768)` returns a family page with `result`,
`offset`, `page_complete`, and `next_cursor`. Item/wire limits remain unchanged.
Fields project only existing allowlisted keys, including no default/option trees.
If the mandatory envelope or a first item cannot fit, the request refuses; it
does not silently skip that item. Capture family statuses/partiality accompany
each page. Incoming/outgoing follow-ups use the public references operation.
The existing selected-registry callback operation is a separate follow-up; this
change does not extend callback traversal or source/effect analysis.

Registry discovery obtains a complete exact model-label/registry-kind range
before deciding zero/unique/ambiguous. It cannot consume the brief's entire fact
allowance through inventory scanning. Optional directory admission refusal leaves
that family explicitly unsearched while other families continue. Only a complete
unique **label** candidate enables the existing callback explanation. Anonymous
model labels remain unavailable, and multiple registries never select one as a
canonical model identity.

## Alternatives, cost and refusal

The chosen primitive is an optional immutable sorted vector of fact positions.
It borrows names/kinds from the Reader and shares the existing query Budget and
Reservation implementation. It adds no crate, persistent index, stored schema,
capture work or duplicated link tree. A directory is built under a Reader-local
mutex once; a query copies only its bounded page of positions while locked, then
releases the lock before identity/output construction. In-flight requests own the
existing Reader Arc; close rejects later requests and releases retained state
after the last in-flight owner. Snapshot generations never invalidate in place.

Construction reserves capacity for at most the existing 100,000 saved facts
before allocating, then traverses every saved fact once and sorts eligible
positions in place with std's maintained unstable sort. Keys compare exact names,
then kinds, then positions. Worst-case build is O(F log F) string comparisons,
with at most 4,096 bytes per saved name/kind. Query range selection uses two
binary searches, charging actual declared comparison/label-byte units; output
projection is proportional to requested items. Incoming relationship traversal
uses direct fact/link positions, so a complete investigation visits the selected
domain plus bounded boundary revisits. Outgoing traversal reads only anchor links.

The `recorded_directory` cost reports full build fact visits, eligible facts,
key bytes, sort comparisons, compared-label-byte upper units, slot capacity and
reserved retained bytes. The stored keys are borrowed, not copied. Reservation
is vector capacity plus the inline directory mutex/container; it is not total
heap or RSS. The vector uses at most F * sizeof(usize) capacity plus container.
Allocator capacity beyond the admitted amount refuses. Admission uses the
existing aggregate 128 MiB Reader/query budget; the 32 MiB request reservation
remains held through serialization. An optional directory cannot promote refusal
to completeness or weaken publication/Reader admission.

Publication and initial Reader opening do not build this directory or gain another
fact pass. Reader-open's existing five passes and encoded-data/search admission
are reported separately. First selected lookup pays construction; later same-
Reader lookups reuse it, with zero new construction. Reopening pays Reader-open
and rebuilds on demand. CLI invocations use fresh Readers and can therefore repeat
directory construction. Brief `whole_job` includes actual method/name directory
construction once, separately from incremental request visits. Existing method
directory, native crossings, source checks and callback costs are not removed.

Alternatives considered from those costs:

* Cursor-only candidate scanning avoids retention but repeats whole inventory work
  for each outgoing label and complicates trusted global uniqueness. Use direct
  cursors for links, where no global candidate aggregation is required.
* A link reverse index adds retained entries proportional to all links, plus
  construction/admission work even for sparse incoming questions. Direct resumable
  traversal makes the selected domain reachable without that second index.
* Reusing the method directory would encode different keys/eligibility and would
  expand another owner's algorithm. Reuse its Budget/Reservation pattern instead.
* Raising scan caps leaves a new permanently inaccessible suffix and increases
  request work. A persistent index/schema/framework adds publication, validation,
  migration and maintenance costs unnecessary for this saved-domain contract.

This is source cost analysis, not a measured speed/support claim. Reconsider
retained-name or reverse-link indexing only with whole-job evidence covering
construction, first-open/reopen, repeated queries, memory and admission/refusal.
Root owns adding this bounded decision to the shared development decisions.

## Finite evidence plan and current boundary

Current phase is source and light static only. No native compilation/tests,
installation, Rails capture, database or benchmark campaign has run for this
candidate. A parse-only rustfmt attempt could not start because rustfmt is absent;
no tool installation or setup was attempted. Ruby syntax and diff checks are
source evidence only. The inherited 120-test/control families keep their original
identities and remain applicable bounded regressions, not candidate passes.

After the signed draft checkpoint, Root allocates an existing finite execution
resource separately from the other primary. Proposed focused work, subject to
that actual technical allocation:

1. One offline copied-source native build, then the recorded-domain/references/
   model-brief regressions and applicable existing native/reader-boundary controls.
   Test global counts, incomplete/no-match distinctions, positional progression,
   admission refusal/release, pinning/reopen and in-flight close ownership.
2. Run dedicated Core references and model-brief tests with that built native.
   The harmless recorded-domain fixture has 20,060 synthetic class facts, an origin
   after fact 20,000 and relevant link ordinal 50,000, plus normalized model/two
   registry facts. The public Reader and CLI must exhaust without duplicate/lost
   logical rows after CURRENT advances, reach the late fact/link, retain registry
   ambiguity, and keep columns usable. The existing real-producer brief tests
   retain their separate fixture/support applicability; synthetic data proves
   saved-domain access, not Rails/application capture coverage.
3. Record exact source/input hashes, loaded native/toolchain/support identities,
   full-build/initial-open/reused-query/reopen counters and reserved retained bytes.
   Any observed RSS must be labelled as process measurement, not encoded bytes.
   Keep raw failed attempts. No historical package or speed verdict transfers.
4. Root completes substantive independent review/current affected CI and schedules
   ONE settled changed-package acceptance using the existing installed contracts
   and relevant Map smoke. Installed results bind exact gem/native/fixture/support
   tuples. Leah retains applicable acceptance; PM owns Linear metadata.

For the eventual execution window, use Root's named process/container bounds,
task-private disk-backed inputs/TMP, bounded private logs, no credentials or
evaluator policy, and enforced subprocess failure propagation. No heavy slot is
claimed by this source writer. Stop scope expansion once these selected recorded
domains are finitely exhaustible; all-Find/Links/callback/Map work is separate.
