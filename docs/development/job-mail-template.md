# Saved job, mailer and ERB investigation (LOS-148)

Contract: [LOS-148](https://linear.app/lost-in-the/issue/LOS-148). This is a
**source-only implementation checkpoint**, not an executed or accepted journey.
Leah owns acceptance; Root owns packaging, independent review and later finite
native/framework/installed/served execution. No source/native/package or launch
qualification is inferred from the pure helper checks.

The customer follows declared retry/discard/rescue policy, a potential mailer
action, explicit template selection and ERB variable/partial/helper references.
Registrations, source declarations, source-potential operations and execution are
separate evidence. No registration handler, application override, job, callback,
mailer action, delivery method, ERB compiler/evaluator or helper is invoked.

## Dedicated interfaces and Root-owned callsites

Phase 3 composes the published LOS147 Core checkpoint
`ee37303386f688f7e9a608f79cb6dfc8d57c6e5b` by signed merge, preserving its bytes
and the shared parser worker. The immutable original base remains
`5c80f5d167ccf30d7c38f7bd78a33ca4c5734cfa`. Exact transfers now implement the Core
hooks below in source. They have not been compiled or executed in this phase;
Map routing is wired in source after phase 4's signed merge of published147
`43b2bca7555b8b62f970bc9751939226a274f4ef`. Final package/docs composition adds
published147 `a731439b1daaf9662a4e6b82dcb7ef8b3eaa1e40` and includes both job/mail
guides in the preserved installed-doc union. Independent review, actual builds,
native/installed/served execution and acceptance remain Root-owned; none is
inferred from pure mocked routes or static package selectors.

| Location | Current source integration / remaining ownership |
| --- | --- |
| `engine/src/lib.rs` | Modules and `job_mail_batch`, public `job_mail` selection and `Query::scratch()` admission implemented. Reservation uses the existing native envelope/response-serialization lifetime. Optional `capture.templates` selects the narrow existing-inventory extension. No second public source dispatcher. |
| `engine/src/capture.rs` | Source helper implemented: `pub(crate) fn parser_worker<T: Send + 'static>(name: &'static str, task: impl FnOnce() -> Result<T> + Send + 'static) -> Result<T>`. Existing capture delegates with unchanged effective-limit validation and capture recipe. Capture and selected source share one atomic try-admission, 64 MiB stack, spawn/join/panic mapping and RAII release. Busy is immediate; no queue/retry/fallback. Native execution remains UNRUN. |
| `engine/src/schema.rs`, `recorded_domain.rs` | Strict `rails_job_mail` validator is called by the common publication/fresh-open validation path. Runtime rows have no source location; handler locations are hints. One adjacent anonymous-label exclusion in `candidate_name` prevents anonymous registry display names from becoming candidate identity. |
| `lib/thistle.rb`, `capture.rb` | Optional explicit `job_mail` context is validated/copied before Native calls and forwarded within the supplied app/root. Existing Rails and LOS147 observation order/delta accounting is preserved. Loaded jobs/mailers, guarded framework version, remaining limits and byte budget reach `JobMailObserver`; no descendant lookup or eager loading. `rails_capture.rb` is unchanged. |
| `engine/src/capture.rs` template inventory | `capture_with_templates` validates/deduplicates bounded explicit paths and shares the normal Capture object after ordinary inventory. Existing `open_root`/`open_at` guard every path component/final file with NOFOLLOW and regular-file/metadata checks; existing `read_file`/`add_fact`/file record machinery accounts source/facts/bytes/diagnostics. ERB bytes pass strict Rust `admit_bytes`, create one inert full-span file fact and normal blob, and never reach Prism/ERB evaluation during capture. No Ruby path traversal or new filesystem authority/global limit. |
| `lib/thistle/reader.rb` | Thin `job_mail(id, family: nil, limit: 8, cursor: nil, max_bytes: 32768)` forwards fields and pinned handle to the one native op. Public method source is present; actual native behavior remains UNRUN. |
| Map App/View/NavigationContext | Source wiring implements `/job-mail/{overview,registrations,declarations,policy,handoff,template_references}` with family in path and id/cursor controls. Existing NavigationContext owns all URLs/state and pre-ReaderFactory scope/cursor validation. One public projection per page, validated typed envelopes/descriptors and compact root identity; explicit Source/Links actions do not eagerly query job families. Long-URL display admission can reduce requested rows without inferring Native positions. Existing source/page/output/access/close limits remain; actual installed/served task evidence is UNRUN. |
| Packaging/install manifests | Both gemspec installed-doc selectors, both installed-manifest assertions and Core/Map automation doclists include their job-mail-template guide while preserving the complete existing union. Both PR121 note fragments remain. Actual archive/install validation and the manually authored installed/served contract remain Root's admitted execution gates. |

Raw source file admission is separate from ERB analysis: a captured ERB source
may be available even if its syntax, encoding or selection is unsupported. A
refused raw file needs explicit partial/unavailable coverage and a diagnostic;
it is not an empty successful template family. Explicit unsafe/missing/oversized
input refuses the capture before publication. Invalid UTF-8 source follows the
existing inventory diagnostic/partial-coverage policy. Observe registrations
independently of source coherence.

Opt in with `Thistle.capture(root:, output:, rails: supplied_app, job_mail:
{jobs: [already_loaded_job_classes], mailers: [already_loaded_mailer_classes],
templates: ['app/views/receipt_mailer/receipt.html.erb']})`. Nil retains the prior
fast/default path; missing app, unknown keys or non-Class inventories refuse
before capture. Templates are explicit paths, not a Ruby filesystem scan or
framework resolver. The native request receives only root/limits/paths, never
earlier source/fact payloads. Duplicate paths cannot replace an accepted source
or add duplicate facts. Excluded directories and paths outside the root refuse.

Entry budgets have two scopes/units. The existing filesystem `max_entries`
counts ordinary directory entries plus explicitly traversed template components
on the SAME native Capture counter; it is never reset or raised. Native reports
`explicit_template_entries` as the exact before/after `read_templates` delta,
separately from `inventory_entries` (the total filesystem count). Missing,
noninteger, negative or oversized delta accounting refuses before publication.
Ruby combines ONLY that component delta and `job_mail` batch `appended.entries`
for the job/mail observer's own entry allowance. Model, Callback and Source
Ownership keep their prior full per-batch entry allowances; neither filesystem
walk entries nor other observer batches reduce them. Facts/links/bytes/diagnostics
remain globally cumulative and incrementally charged, with no old-fact metadata
reserialization per family. Store independently validates full publication.

## Raw observation DTO and validators

All objects below have exact fields. Ruby supplies no normalized identity,
semantic selection or relationship. `schema::ObservationAdmission` enforces the
remaining aggregate fact/link/entry/evidence counts; Store independently validates
actual publication. Native validation does not trust Ruby's version allowlist.

`JobMailObserver#call` returns:

```text
{version:1, framework_version:string|null, root:string,
 boundary:'explicit_loaded_app', status:'observed'|'unavailable', classes:[
  {kind:'job'|'mailer', name:string|null, superclass:string|null,
   rescue_handlers:{status:'observed'|'unavailable', entries:[
    {exception:string|null,
     handler:{kind:'opaque'} |
       {kind:'proc',source:hint|null} |
       {kind:'method',name:string,owner:string|null,source:hint|null},
     shared_with_superclass:boolean|null}
   ]}}
 ]}
hint = {path:string,line:positive_u32}
```

Compatibility leaf guards are present for Rails **7.1.6 / 8.1.4**, not a broad
framework support claim. The FIRST installed fixture/cards are explicitly pinned
to **Rails 8.1.4** (both current CI cohorts: Ruby 4.0.9 and 3.4.12). The harness
asserts Rails.version after boot and before card answers. The 7.1.6 path remains
present but UNVERIFIED by this fixture; version-specific cards and actual evidence
are needed before a broader claim. No plausible 7.1 failure was reproduced here.
No APPLICATION-controlled getter is dispatched: 7.1 binds only the verified
framework-generated public pure-storage leaf, 8.1 uses the verified private leaf.
Public overrides on 7.1 and unknown VM/layout/overridden storage stay unavailable,
never an empty observed registry. Bound builtins and fresh primitive copies avoid
singleton overrides on supplied arrays/rows/descriptors. The supplied app token
establishes caller authority, not proof every class belongs only to that app.

`job_mail::batch(context, observation)` strips external/unsafe hint paths without
opening them, derives `rails_job_mail` identities and preserves registry array
order. Its attributes are exactly:

```text
{job_mail:{version:1, ordinal:u64, framework_version:admitted_version,
 boundary:'explicit_loaded_app',coherence:'unknown',class:class_DTO}}
```

The fact has `kind:'rails_job_mail'`, `evidence:'runtime'`, `path:null`,
`location:null`, and `links:[]`. Its ID is the canonical digest of
`['rails_job_mail',1,ordinal,class.kind,class.name]`. Name is the class name or a
labelled anonymous display name. `validate_fact` rederives identity, validates
all nested fields/coverage/labels/hints and rejects invented keys/parameters.
Retry/discard wrappers remain opaque Procs. No closure binding is inspected.
Shared superclass row identity is inheritance evidence, not a registration site
or proof of the active exception handler. Exception labels are never constantized.

Raw template admission has ONE integrated path: explicit root-relative paths
reach Rust's existing descriptor-anchored reader, which passes bounded bytes to
`erb_template::admit_bytes`. It validates the ERB path, 256 KiB cap, digest and
strict UTF-8 and returns normal `{path,content,bytes,sha256,encoding:'UTF-8'}`
source records. The unused numeric-array helper/native op/admission/tests were
removed in R121-04; there is no second transport or Ruby file traversal.

## Public answer and family allowlist

The only public operation is `job_mail`. `Query::parse` accepts a saved SHA-256 ID,
`family:nil` (overview), limit **1..16 / default 8**, cursor string or nil, and
`max_bytes:1024..65536 / default 32768`. Unknown family/unsupported anchor kinds
refuse. The native result is encoded and checked against the requested budget.

| Family | Supported anchor | Work and page meaning |
| --- | --- | --- |
| `overview` | job/mail registry, class/module, method, ERB file | Compact root identity and supported family descriptors only. No directory or source reads/parsing. |
| `registrations` | `rails_job_mail` | Recorded ordered exception/opaque handler rows and shared-superclass evidence; position is not execution chronology. |
| `declarations` | `rails_job_mail` | Exact saved own-class, `name#perform` and superclass-class candidates. All duplicate identities retained. Missing local perform does not mean absent inherited behavior. No parsing. |
| `policy` | captured class/module | Source `retry_on`/`discard_on`/`rescue_from` calls, exception syntax, supported literal/dynamic option syntax and opaque blocks. Registration association, defaults and conditions remain unknown. Nested declarations have their own selected anchors. |
| `handoff` | captured method | Constant-receiver/action and delivery-style call-site candidates, explicit `mail`/`render` template selection. Receiver framework role, binding, invocation, branch satisfaction and delivery remain unknown. |
| `template_references` | captured `.erb` file fact | Original physical spans for instance-variable reads, receiverless local-or-helper / call-or-helper candidates and explicit slash-qualified partial candidates. Values/binding/execution unknown. |

Envelope:

```text
{version:1,generation,root:{generation,id,kind,name,evidence,path,span},
 family,items:[typed rows...],coverage,provenance:'saved_evidence',
 unknowns:{coherence,binding,execution,delivery},
 next_cursor,continuation:descriptor|null,page_complete,semantics,cost}
descriptor = {operation:'job_mail',id,family,generation,cursor}
```

Each source row references its actual saved root identity/digest/span; a candidate
has its actual same-generation ID/kind/evidence/path/span and a descriptor to its
overview. There are no raw URLs. Registry rows deliberately do not acquire source
coordinates from a hint. Missing captured targets, duplicate ambiguity, capture
coverage, binding unknowns and observed execution are separate fields.

Continuation uses existing `recorded_domain::{cursor,position}` scoped to
`['job_mail',id,family]` plus the Reader generation. Positions are the next
registry row, label/candidate offset, or source-row/candidate offset. A source
row can recur while its duplicate candidate range continues; its ordinal is
stable. Map never computes offsets. Metadata/output refusal never advances past
an omitted item; a page that cannot fit one item refuses. `page_complete` describes
the enumerated eligible page domain, not complete capture, binding or execution.

Literal source conventions supported in this child:

* `Mailer.action` -> exact `Mailer#action` saved method label candidates;
  there is no constant lookup or effective inherited-action resolver.
* `mail(template_path:'receipt_mailer',template_name:'receipt')` -> exact
  `app/views/receipt_mailer/receipt.html.erb` saved file candidates.
* `render partial:'receipt_mailer/footer'` -> exact
  `app/views/receipt_mailer/_footer.html.erb` saved file candidates.

These are syntax/convention candidates, not Rails resolver results. Dynamic
selection, implicit template defaults, relative partial prefixes, format/locale/
variant negotiation and unrecognized keyword splats remain unsupported/unknown.
Prism-decoded literal bytes must pass strict UTF-8; a source literal `"\xFF"`
never becomes a replacement-character target. Exact source remains in Source.

## Parser, cost and reuse disposition

Reuse the maintained vendored **Prism 1.9.0** parser and the existing generated
`capture_children.rs` visitor. No Woods engine/index/runtime code is used. ERB
has a small inert delimiter projection, preserving byte length/newlines, masking
HTML/comments/escaped tags and adding Ruby statement boundaries. Prism analyzes
that projection; unsupported/unclosed/syntax-invalid forms are unknown. This is
not an ERB compiler or full ActionView implementation. Alternatives: evaluating
ERB is disallowed; Ruby ERB compilation would move analysis to Ruby; introducing
another parser/runtime dependency adds maintenance without helping this bounded
source-only family. Reconsider the projection for further template languages or
demonstrated scanner incompatibility, preserving inert-source and physical spans.

Parse-free paths (`overview`, `registrations`, `declarations`) reserve **32 MiB**
query scratch. Parse-required paths (`policy`, `handoff`, `template_references`)
reserve **96 MiB**, including the existing 64 MiB worker stack, bounded owned
source/fact copies, syntax tree/projection allowance, and native/Ruby response
copies. Root keeps the reservation through response serialization. There is one
shared parser permit with capture through the implemented source helper rather
than a second parser authority. Its authored admission/error/panic regression is
UNRUN; public job/Core, Map projection and package-selector source hooks now
exist. Actual native/framework/archive/installed/served evidence remains
outstanding.

The selected saved file is limited to 256 KiB before Source reads. There are
20,000 **pending-node pops**, 200 derived rows, 64 arguments per inspected call,
64 entries per inspected keyword hash, 64 constant-path segments/256 label bytes,
4 KiB decoded string labels, and 128 KiB intermediate annotation output. Argument
and keyword inspection stops after at most the 65th entry; policy extraction
uses at most nine bounded argument-list passes and seven keyword lookups. These
helper inspections and generated child-list enumeration are additional work;
the pending-pop count is not a whole-parser or total-work bound. Newline offsets
are indexed once and physical lines use binary lookup rather than rescanning
file prefixes for every reference.

Candidate selection reuses `Reader::recorded_candidates` and the existing lazy
recorded directory. Its first build visits/sorts the saved domain under existing
Core accounting; this is reported in `cost`, not claimed constant-time or free.
Directory locks end before source parsing/output. Comparisons cap at 20,000 and
1 MiB compared labels per request. Response items reserve half the requested
budget for the envelope; final encoding can still refuse oversized metadata.

All parser/AST caps are operational and partly **after parsing**. Neither the
96 MiB reservation nor a large stack is a hard CPU/RSS/heap sandbox or deadline.
No latency/memory improvement has been measured. Source work does not admit a
host execution window. A parser `busy` code maps to `Thistle::Busy`; Map returns 503 with Retry-After:1 and explicit retry-page text, without retry/queue/fallback. GET/HEAD/access-before-open/close remain. Other error paths preserve the failure; oversized or
analysis-limited source gives explicit unknown coverage, never complete absence.

Display option snippets are at most 256 UTF-8 bytes, with `truncated` and original
`source_bytes`. Policy positional syntax appears once in `exceptions`; keyword
hashes belong to the separately recorded `options`, with no `arguments` alias. Original
physical spans and strict literal decoding/target identities remain untouched.
ERB's 200-reference/20k-node allowance returns retained `bounded_partial` evidence,
`scan_complete:false` and explicit remaining unsearched work, never empty complete
absence. Complete source scans omit `unsearched`; a partial scan retains its
explicit remaining-work marker. Large parse allocation/CPU still depends on admitted host execution.

Conventional implicit `mail(to:)`, `mail(template_name:)` without explicit path,
and positional `render 'dir/name'` remain unsupported selection, with aligned
`unsupported_selection_unknown` status and no candidate. Supporting these normal
mailer defaults/resolver forms is a PRIORITIZED PARENT follow-up, not resolved
binding, new cards or a completion claim. Mailer registry declarations do not
invent a perform method; jobs may offer the recorded perform-label candidate.

## Independent expected journey and evidence state

`test/fixtures/los148_job_mail/expected_cards.json` is authored independently of
implementation output. The public fixture contains inherited retry (four attempts,
polynomial wait), local discard/rescue with opaque/symbol handlers, a conditional
mail call, duplicate archive action declarations, unloaded mailer/exception,
dynamic template selection, ERB variable/helper/partial and sentinel overrides,
handlers/job/helper/template bodies that raise if dispatched.

Executed in the initial source phase: pure mocked observer 3 tests/9 assertions,
raw template helper 2/7, presenter 2/21. No native library, Rails app or ERB engine
was loaded for those suites. `rustfmt` was attempted and unavailable (exit 127);
Local Rust compilation/native tests remain **UNRUN** in these source-only phases.
Hosted attempts are recorded separately below. Later checks must retain their
exact candidate identity; pure source checks do not qualify changed packages.

Historical CI attempt at `4b72599e406da51e025a251264c629b95fcfae05` is **FAIL**:
required job `124658315705`, primary `124657965293`, minimum `124657965265` and
ARM `124657965238`. The primary log demonstrated Rust E0428: the registration
DTO helper and saved-fact projector both used `identity`; E0061 callers then
selected the wrong signature. Phase 4 names them `registration_identity` and
`saved_identity` and updates their two/six callers respectively. Inverse-rename
static comparison preserves every other byte, and the owned modules have no
duplicate module-level function declarations. This is a source correction, not
an executed compile pass. Compilation stopped before native/Ruby/installed
checks in that attempt; current-candidate CI/native evidence remains required.

Phase 3 pure wiring checks: new job/mail stdlib-double suite 11 tests/22
assertions PASS; existing LOS147 stdlib wiring regression 7/14 PASS; changed Ruby
syntax PASS. These cover explicit app/config copying, thin Reader/closed-handle
forwarding, nil defaults, ordered incremental composition, prior entry accounting,
no old-fact rewalk/reserialization, and failure propagation before publication.
They load neither native code nor Rails and perform no actual capture/store IO.
Phase 4 pure mocked checks: Map job navigation 3/75, isolated routes 16/32,
presenter 2/21 and existing LOS147 navigation 4/41 PASS. These validate one-query
pages, typed followups, no expanded identity fallback/fanout, pre-factory scope
refusal, HEAD/close, full collection/search-drop notice and explicit source entry
actions. They do not establish real native/server/browser behavior.

Authored but **UNRUN**:

* `job_mail_tests.rs` / `erb_template_tests.rs`: strict DTO/provenance, source
  policy, dynamic/non-UTF8 targets, physical spans, comments/escaped tags/cursors,
  explicit template source/dedup, symlink/parent/excluded/limit refusal, strict
  publication and saved Rails-free Reader source/family recovery.
* `test/test_job_mail_installed.rb`: isolated installed Core + real framework
  capture, exact expected registry, saved A/CURRENT B, fresh Rails-free Reader,
  each family with limit 1, duplicate/unloaded targets, ERB/partial/helper and
  dynamic selection. Run outside checkout with isolated installed gems and an
  explicit Root lease. The manual script fails if shared wiring is missing.
* The installed script now includes the actual `/job-mail/overview` Rack route
  (`LOS148_MAP_PATH` can supply the admitted mount's path). This is not a
  served-browser substitute. Supply the real served URL to
  `test/fixtures/los148_job_mail/served_journey.mjs` for screenshots, narrow screen,
  keyboard and no-JavaScript assertions under Root's separate finite admission.

No screenshot, installed receipt, runtime safety proof or customer completion is
claimed. Package hashes/native loaded identities, actual framework cohorts,
served URL/access policy, screenshots and independent task answers must be
recorded by Root/Leah before acceptance. Keep failed attempts and earlier tuples.

## Package/docs synchronization and remaining acceptance

The Core/Map README contracts, exact installed-doc selectors/assertions and one
bounded development decision now describe this source-wired path. Ledger candidate
cells L02/L03/L04/L07/L14/L15 record its scoped evidence and missing acceptance;
all 17 launch outcomes remain UNQUALIFIED. No parent requirement or support scope
was removed. Preserve the historical failed CI attempt above and attach the exact
new package/native/installed/served evidence before accepting the journey.

HAML/alternate families, broader defaults/callbacks/history, full Passage,
effective inherited mail dispatch and full template resolver parity remain parent
scope. Static selectors/link checks do not build an archive, install either gem,
exercise Native or qualify customer task answers. Root owns one full initial
review and the settled candidate's finite execution; Leah owns acceptance.


## R121 correction checkpoint (source only)

R121-01 typed busy/503; R121-02 Rails 8.1.4 fixture pin and honest7.1 guard wording;
R121-03 separate entry scopes; R121-04 unused transport removal; R121-05 neutral
bare/local/call labels and job-only perform; R121-06 bounded display/partial ERB;
R121-07 synchronized guides/notes/coverage; R121-08 code-specific path/component
regressions and relative safe errors; R121-09 aligned unsupported status and
prioritized conventional resolver follow-up are implemented in source. The
native regression cases remain authored UNRUN; source mocks do not prove them.

Exact f0749f13 source CI ALL8 succeeded (required124668996745, minimum124668106510,
primary124668106482, ARM124668106302, Automation124668074203, Plan124668074042,
PII124668075208/124668060892). CodeRabbit SKIPPED was not approval. This exact
prior-head evidence and historical4b failures do not transfer to a correction head.

The retained initial report SHA256 is
`a5fe0c69b0eb571209791f2fcf18f814400607f73101d9bff1cb48ee7b3c8fdb` (16812B).
Preserve its 870s/300s target overrun, partial reads, five 0644 scratch files totaling
145725B subsequently deleted, EROFS fallback and unenforced tool-output aggregate
(estimated below 1 MiB). These exceptions were not a clean procedure. Root owns
ONE changed-scope R2; no source author self-approval or acceptance build is implied.

Focused R121 correction source checks:42 job/mail stdlib/mock tests104 assertions
PASS (Busy mapping1/1, composition17/34, Map17/34, observer4/10, presenter3/25),
plus unchanged LOS147 mocked wiring7/14 and installed-document link test PASS.
Changed Ruby syntax, exact shared-hunk/ordinary-walk/anchored-IO/default/parser
byte invariants, notes and whitespace pass. One trailing-space check failed and
was corrected; its attempt is retained. No Rust/native/framework/app/archive/
install/server/browser execution occurred. These checks do not execute the new
native safe-error/component-delta/large-handler/200-reference regressions.
