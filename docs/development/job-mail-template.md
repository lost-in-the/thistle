# Saved job, mailer and ERB investigation (LOS-148)

Contract: [LOS-148](https://linear.app/lost-in-the/issue/LOS-148). This is a
**source-only implementation checkpoint**, not an integrated or accepted journey.
Leah owns acceptance; Root owns shared wiring, independent review and later finite
native/framework/installed/served execution. No source/native/package or launch
qualification is inferred from the pure helper checks.

The customer follows declared retry/discard/rescue policy, a potential mailer
action, explicit template selection and ERB variable/partial/helper references.
Registrations, source declarations, source-potential operations and execution are
separate evidence. No registration handler, application override, job, callback,
mailer action, delivery method, ERB compiler/evaluator or helper is invoked.

## Dedicated interfaces and Root-owned callsites

One exact existing-file transfer permits the parser-worker extraction in
`capture.rs`; all other shared wiring remains Root-owned. The immutable starting
head is `5c80f5d167ccf30d7c38f7bd78a33ca4c5734cfa`. The parser helper below now
exists in source; the other integration seams remain outstanding:

| Root-owned location | Exact integration required |
| --- | --- |
| `engine/src/lib.rs` | Declare `mod job_mail; mod job_mail_source; mod erb_template;`. Route internal `job_mail_batch` to `job_mail::batch(context, observation)`; raw template admission to `erb_template::admit_raw(raw)`; public native `job_mail` to `job_mail::select(&reader, &job_mail::Query::parse(request)?)`. Add its `scratch()` to request admission. No second public source dispatcher. |
| `engine/src/capture.rs` | Source helper implemented: `pub(crate) fn parser_worker<T: Send + 'static>(name: &'static str, task: impl FnOnce() -> Result<T> + Send + 'static) -> Result<T>`. Existing capture delegates with unchanged effective-limit validation and capture recipe. Capture and selected source share one atomic try-admission, 64 MiB stack, spawn/join/panic mapping and RAII release. Busy is immediate; no queue/retry/fallback. Native execution remains UNRUN. |
| `engine/src/schema.rs` | Strictly recognize `rails_job_mail` through `job_mail::validate_fact` at publication **and fresh Reader admission**. Structural generic acceptance is insufficient. `rails_job_mail` runtime rows have no source location; the handler location is only a hint. Exclude anonymous job/mail registry display names from recorded-name candidate identity, as already done for anonymous models/callbacks. |
| `lib/thistle/capture.rb`, `rails_capture.rb` | Within the explicitly supplied app boundary, pass actual already loaded `jobs:`, `mailers:`, absolute `root:`, admitted `framework_version:`, remaining `limits:` and `evidence_budget:` to `JobMailObserver.new(app:,...).call`. The helper does not discover/eager-load descendants or resolve constants. Append only admitted batch facts and charge the returned `appended` counts. `job_mail_observer` producer metadata is supplied by `batch`. |
| Template inventory/blob aggregation | Open candidate files with the existing anchored/no-symlink/regular-file policy; pass a dedicated open File to `JobMailTemplateCapture.call(file:, path:, max_bytes:)`. Admit raw bytes in Rust. Deduplicate/charge source files, total bytes, source facts, entries, metadata, links and diagnostics under existing limits before publication. Include a normal `file` fact named by its exact relative path, physical full-file span and saved blob, so existing `Reader#source` and `source_file` work without Rails. No new global limit. |
| `lib/thistle/reader.rb` | `job_mail(id, family: nil, limit: 8, cursor: nil, max_bytes: 32768)` -> native op `job_mail` with these fields and the pinned handle. Keep the native scratch reservation alive through response serialization/C-envelope ownership. |
| Map App/View/NavigationContext | Consume one public answer/family page. Inject existing NavigationContext and a Root-owned projection-descriptor URL adapter into `JobMailPresenter`. Add only actual admitted projection routes/parameter allowlists. Preserve encoded page/refusal budgets and typed identity collection; do not use expanded `Reader#fact` for compact identity. |
| Packaging/install manifests | Add the two dedicated docs and new files to the affected explicit manifests; retain Core and Map note fragments for the actual PR. Wire the manually authored installed contract into an applicable admitted check. |

Raw source file admission is separate from ERB analysis: a captured ERB source
may be available even if its syntax, encoding or selection is unsupported. A
refused raw file needs explicit partial/unavailable coverage and a diagnostic;
it is not an empty successful template family. Root owns those aggregation and
publication decisions. Observe registrations independently of source coherence.

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

Supported layouts are exactly Rails **7.1.6 / 8.1.4**, matching the existing
observation cohorts, not a broad framework support claim. The private storage
reader must match the guarded framework class-attribute leaf. Public getters
are never called. Unknown VM/layout/overridden storage is unavailable, never
an empty observed registry. Bound builtins and fresh primitive copies avoid
singleton overrides on supplied class arrays, rows and descriptors. The app
token establishes explicit caller authority; it does not prove every supplied
class belongs exclusively to that app. The inventory scope is supplied classes.

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

Raw template transport:

```text
{path:relative_path, content_bytes:[u8...], bytes:u64, sha256:hex,
 provenance:'raw_template_bytes'}
```

Numeric bytes preserve invalid UTF-8 across JSON without a Ruby encoding/parser
policy. `erb_template::admit_raw` validates byte range, 256 KiB cap, exact length
and digest, safe ERB path, provenance and strict UTF-8. It returns a normal
`{path,content,bytes,sha256,encoding:'UTF-8'}` source record. The transport has an
explicit allocation/serialization cost: up to 262,144 Ruby integer slots and
numeric JSON bytes per file. Process one file at a time; aggregate admission is
still required. A later measured binary FFI transport can replace this bounded
JSON seam; no new dependency or engine coupling is introduced here.

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
| `template_references` | captured `.erb` file fact | Original physical spans for instance-variable reads, receiverless helper candidates and explicit slash-qualified partial candidates. Values/binding/execution unknown. |

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
UNRUN; the public job operation and other integration hooks remain unwired.

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
host execution window. Busy/error paths preserve the failure; oversized or
analysis-limited source gives explicit unknown coverage, never complete absence.

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
Rust compilation/tests remain **UNRUN**. Later source checks are reported on the
PR with their exact candidate; this paragraph does not qualify changed packages.

Authored but **UNRUN**:

* `job_mail_tests.rs` / `erb_template_tests.rs`: strict DTO/provenance, source
  policy, dynamic/non-UTF8 targets, physical spans, comments/escaped tags/cursors.
* `test/test_job_mail_installed.rb`: isolated installed Core + real framework
  capture, exact expected registry, saved A/CURRENT B, fresh Rails-free Reader,
  each family with limit 1, duplicate/unloaded targets, ERB/partial/helper and
  dynamic selection. Run outside checkout with isolated installed gems and an
  explicit Root lease. The manual script fails if shared wiring is missing.
* Set Root's actual `LOS148_MAP_PATH` to add the installed Rack projection check.
  This is not a served-browser substitute. Supply the real served URL to
  `test/fixtures/los148_job_mail/served_journey.mjs` for screenshots, narrow screen,
  keyboard and no-JavaScript assertions under Root's separate finite admission.

No screenshot, installed receipt, runtime safety proof or customer completion is
claimed. Package hashes/native loaded identities, actual framework cohorts,
served URL/access policy, screenshots and independent task answers must be
recorded by Root/Leah before acceptance. Keep failed attempts and earlier tuples.

## Exact synchronization proposal for Root's normal PR

Do not mark any capability qualified. In `docs/capability-ledger.md`, append the
following bounded status/evidence to **L02, L03, L04, L07, L14 and L15**, retaining
all existing outcomes/support obligations: “LOS-148 supplies dedicated source for
guarded job/mail registrations and inert ERB source-potential investigation;
shared integration and exact installed/served acceptance remain outstanding.
Registrations, source syntax, candidates, coherence and execution are distinct.”
Link this document and the eventual actual installed/served report, without
substituting pure helper results for those gates.

In Map's README/current-validation scope, add the supported job policy → potential
mailer/action → explicit ERB/partial/helper path **only after Root wires it**,
with links to `map/docs/job-mail-template.md` and actual task evidence. State that
HAML/alternate families, broader defaults/callbacks/history, full Passage,
effective inherited mail dispatch and template resolver parity remain parent
scope; this child does not close Woods replacement or launch requirements.

For `docs/development/decisions.md`, record the bounded maintained-Prism + inert
ERB projection choice above, one shared parser authority, transport cost, limits
and reconsideration conditions. No shared docs were edited by this writer.
