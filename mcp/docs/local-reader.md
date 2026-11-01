# Local saved-generation Reader contract

## Authority and result meaning

The operator selects one store and one explicit 64-character lowercase saved
generation at process startup. The process opens one public `Thistle::Reader`
with `generation:` and retains it for the stdio session. Missing generation,
unavailable generation or startup failure never falls back to CURRENT. Advancing
CURRENT cannot repin this handle. Each tool also requires the exact selected
`generation`; a mismatch refuses before Reader work.

Rust remains the owner of normalized evidence, identity, semantics, indexes,
coverage, validation, candidate selection and analysis. The adapter does not
reconstruct Rails semantics, resolve target labels, scan stores or read live
application paths. It never calls general `facts`, `fact`, legacy `search/find`,
or expanded `links`. Startup store access inherits the operator's local authority;
an MCP connection has access to the configured saved source. This read-only
interface is not an access-control bypass or a remote deployment contract.

Successful tools return a version-1 envelope with `generation`, `tool`, unchanged
`reader` result and a fixed untrusted-data notice. Source by fact ID additionally
preserves the compact recorded `selection`. Find adds bounded `source_files`
transport identities beside the unchanged Reader answer. Tool responses contain
both JSON text and the same structured object for client compatibility. This
duplicates wire representation deliberately, within the separate wire budget.

Source by fact ID also returns `selection_span_validation: recorded_not_revalidated`.
The content bytes were verified; this call did not re-check the recorded physical
span. `thistle_check` separately validates saved positions, not live freshness.

Refusals set MCP `isError: true` and return `refusal.code/message`, generation and
the notice, with no substitute evidence. Known public Reader refusal codes are
preserved; arbitrary exceptions become `reader_error` without exception text,
paths or backtraces. Coverage/omissions/ambiguity/partiality and candidate detail
omission remain in raw Reader structures; no adapter summary declares absence,
uniqueness, dispatch or execution. Captured names/comments/strings are inert data.

## Initial tools

Every schema rejects additional properties. JSON strings must be valid UTF-8;
byte checks also apply after parsing, independently of schema character limits.
Null optional arguments are unsupported; omit them instead.

| Tool | Arguments in addition to required generation | Reader operation |
| --- | --- | --- |
| `thistle_find` | required literal `query` (1–256 bytes); `limit` 1–16, default 8; optional exact `kind`, captured `path_prefix` (each 1–4096 bytes), `domain` all/source/metadata | `search_evidence(query, limit:, kind:, path:, domain:)` |
| `thistle_model_brief` | required recorded `id`; `limit` 1–8, default 8; optional `family` columns/associations/registry_candidates and session-issued `cursor` | `model_brief(id, limit:, max_bytes: 32768, family:, cursor:)` |
| `thistle_links` | required recorded `id`; `direction` incoming/outgoing, default outgoing; `limit` 1–8, default 8; optional session-issued `cursor`, outgoing `candidate_link` ordinal 0–4294967295 | `references(id, direction:, limit:, cursor:, candidate_link:)` |
| `thistle_source` | exactly one recorded fact `id` or `file` token; neither paths nor ranges | compact `fact_identity` when selected by fact; manifest admission; `source_file(recorded_path)` |
| `thistle_check` | generation only | `check`, once per session |

IDs are lowercase SHA-256 strings. Find source/file hits may have no fact ID.
Their `source_files` entries supply `file = SHA256(recorded_path)`, recorded path,
manifest bytes and digest so the client can follow them without shell hashing or
inventing a declaration. Only exact entries in the pinned manifest resolve.
There is no arbitrary store/root/path argument. `path_prefix` is a saved-evidence
Find filter and never a filesystem selector.

## Continuation and completeness

Brief overview/family results and Links relationship/candidate results retain
their native continuation/followup objects in full. Choose a declared family or
the returned `candidate_link` and origin ID explicitly, then follow each exact
returned `next_cursor`. The adapter does not automatically expand another family
or traverse a graph. It remembers only successfully returned top-level cursors
with tool/ID/family/direction/candidate scope (at most 64 entries). Tokens are
opaque capabilities for this session; forged, cross-session, wrong-generation,
cross-ID, cross-family, cross-direction or cross-candidate tokens refuse before
Reader work. The native cursor validator still owns positions and query semantics.
Changing the page limit is supported; changing scope requires starting that scope
without a cursor. A no-progress continuation refuses, not a circular success.

Native followups are evidence selectors, not ready-made MCP argument objects.
Map `operation: model_brief` to `thistle_model_brief`, and `references` to
`thistle_links`; map `source` by fact ID to `thistle_source`. Remove `operation`
and omit null optional fields such as `cursor`. Brief's `callback_effects`
followup names an existing Core operation that this initial adapter does not
expose. Report that as an unfollowed adapter scope, not missing Core evidence.
Preserve any unsupported followup instead of inventing an alternative.

Follow candidate pages beyond the four representative candidates in a relation.
A duplicate after the first page is still a candidate; a single label match is
not a runtime binding. Native completeness concerns its selected remaining
recorded domain, not all application behavior or complete capture. A stopped
traversal, missing continuation, output refusal or exhausted session is incomplete.
Never label it complete because a bounded prefix looked useful. Start a fresh
explicitly pinned session for additional work, and account for its repeated open
and index-construction costs; there is no automatic reconnect or hidden retry.

## Source admission and the shared primitive gap

Source by fact ID first requests the compact identity. Unknown IDs refuse there,
without a full fact or Source read. Its recorded path must resolve uniquely in the
pinned manifest. File tokens resolve through the same manifest. One manifest pass
(at most 10,000 files) admits declared bytes/digest before any full source allocation.
Files above 64 KiB or the remaining 256 KiB session source reservation refuse
before `source_file`. Reservations include repeated reads and failed reads.
There is no source cache. The returned full file must match admitted generation,
path, byte count and SHA-256; no prefix/truncation is returned as success.

The adapter intentionally avoids `Reader#source(id)`: that operation also
materializes the full selected fact/links. `source_file` verifies captured bytes;
the compact selection retains its recorded physical span without claiming this
operation revalidated that span against bytes. Check separately validates saved
source positions. Check integrity is still not current source/runtime freshness.

The [LOS158 follow-on](https://linear.app/lost-in-the/issue/LOS-158/read-bounded-saved-source-ranges-and-validate-compact-physical)
retains the missing shared primitive under LOS8: an authoritative
bounded source range/peek with compact selected identity and native physical-span
validation, without full-fact/link expansion. Current Reader supplies no bounded
range primitive. Requests for ranges or large whole-file responses must remain
explicitly unsupported/refused until Core supplies it. Do not implement a Ruby
parser, silently slice a full allocation or claim a successful prefix is complete.

## Finite session and work costs

| Allowance | Bound and behavior |
| --- | --- |
| Inbound frame | 16 KiB before JSON parsing, using SDK bounded `gets` |
| Inbound session | 256 frames, 1 MiB total, including notifications/invalid requests; stop before dispatch when exceeded |
| Tool calls | 64 calls reaching the adapter, including its refusals/Reader errors; close on exhaustion. SDK schema/unknown-tool refusals are bounded by input frames/bytes instead. |
| Check | One whole-generation integrity attempt; failure consumes it |
| Encoded tool result | 2 MiB + 64 KiB; refuse the entire result, no truncation |
| Cumulative encoded tool results | 16 MiB; conservatively reserve a maximum result and refusal before Reader work |
| Protocol wire | 8 MiB per response including newline, 32 MiB cumulative; close before write on exhaustion |
| Source | Complete 64 KiB file, cumulative reserved 256 KiB per session |
| Cursors | At most one newly retained top-level token per successful call, 512 bytes each; no persisted cursor/cache |

Output-byte caps are not heap, traversal, wall-time or native preemption bounds.
Reader open admits/validates/indexes the saved domain under existing native
limits. The first source Find can build a Reader-local verified source corpus;
later Finds reuse it. Find's own comparison/scratch budgets remain unchanged.
The first label-reference/model Brief may build the full recorded-name directory
(up to 100,000 facts, sorting borrowed keys); that construction is separate from
the operation's fact/link/comparison budgets and its reported costs stay visible.
The same pinned Reader reuses the directory. Fresh sessions rebuild it. The
adapter adds no general fact inventory, second semantic index or global cache.

Each Source requests one compact identity when needed and one admitted file;
file-token resolution/Find token projection scan bounded pinned manifest metadata.
Each Brief or Links call forwards a single public Reader operation and retains
native cost/coverage fields. Up to 64 steps can repeat those per-step costs.
Check reads/verifies the entire saved generation, with each native source file
subject to existing store caps; it is not a cheap metadata freshness query.
Restricting Check to one attempt bounds repeated whole-store work per session,
not its wall time. Keep exact native reservations and limits; no speed/RSS result
or material performance improvement is claimed.

## SDK fit and lifecycle

Reuse the official [Ruby SDK v1.8.2](https://github.com/modelcontextprotocol/ruby-sdk/tree/v1.8.2).
The [tagged Tool API](https://github.com/modelcontextprotocol/ruby-sdk/blob/v1.8.2/lib/mcp/tool.rb),
[Server](https://github.com/modelcontextprotocol/ruby-sdk/blob/v1.8.2/lib/mcp/server.rb)
and [stdio transport](https://github.com/modelcontextprotocol/ruby-sdk/blob/v1.8.2/lib/mcp/server/transports/stdio_transport.rb)
fit the required Tool/Response binding, session/protocol lifecycle and bounded
input framing. The transport accepts preencoded output, allowing one final wire
serialization with additional byte accounting. A small subclass wraps only
`read_line`/`send_response`; it does not recreate JSON-RPC or its negotiation.
These version-specific seams require real SDK protocol checks on updates.

Alternatives considered: custom JSON-RPC would duplicate negotiation, validation,
session/cancellation and protocol maintenance; a different language would add a
second bridge/process around the established public Reader. Neither has a benefit
for this initial job that outweighs that cost. SDK reuse adds `json_schemer >= 2.4`
and SDK protocol-maintenance cost. Its upstream Ruby >= 2.7 floor does not lower
Thistle's Ruby >= 3.4 requirement. Reconsider the transport/language if measured
complete-investigation cost or required cancellation semantics cannot fit stdio.
The optional package pins that SDK and the paired Core version without adding
dependencies to Core or Map. This contract records the fit decision and cost;
shared guidance remains separate.

Stdout is exclusively SDK newline-delimited protocol. Diagnostics on stderr are
fixed messages; SDK exception reporting is replaced only inside this dedicated
process and does not change persisted/global client/provider configuration. Reader
and transport close in ensure on EOF, parse error, output failure, connection
limits, startup failures after acquisition, Interrupt and SDK SystemExit.
Acquisition windows defer asynchronous exceptions until resources have owners.
Malformed JSON receives the SDK parse-error response and ends the connection;
ordinary tool/protocol refusals may continue within the finite budgets.
The SDK can return normally after a parse-error close, leaving process status 0
as for EOF. A zero exit alone does not establish a valid protocol session or a
successful investigation; inspect error frames and the actual task receipt.

The SDK's single-thread stdio loop cannot consume a cancellation notification or
EOF while a native call is running. Disconnect becomes observable on the next
read/write; SIGINT cleanup waits for protected/native work to return. There is
no worker-thread preemption or hard session wall-time claim. SIGKILL cannot run
Ruby ensure. Authored real cancellation/disconnect cases must record this honestly.

## Optional package and outstanding evidence

The optional internal `thistle-mcp` manifest selects version `0.1.0.pre.1`, Ruby
`>= 3.4`, runtime dependencies `thistle = 0.1.0.pre.3` and `mcp = 1.8.2`, executable
`thistle-mcp` and require path `lib`. Its explicit 12-file payload contains seven
Ruby libraries, the executable, README, this contract and two license/provenance
files. Missing inputs refuse packaging. Tests, saved evidence and client config
are excluded. The private development publication block remains. Neither Core
nor Map activates the adapter or SDK. Dependency resolution/install is separate;
retain the resolved lock and exact Core/native/adapter hashes with actual evidence.

The [acceptance protocol](https://github.com/lost-in-the/thistle/blob/d2fea61b4087844920eb3058ae38364c9ffbc01c/mcp/test/fixtures/los146_reader/investigation_protocol.md)
and cards remain authored/unrun: installed exact pair/native/parser/reader
regressions, SDK protocol/lifecycle, fresh Rails/AR-free consumer, actual authorized
Codex or Claude investigation, A pinned after CURRENT B, late duplicates, partial
and complete traversal, direct Reader equality and fresh narrative recipient.
Pure doubles and syntax/JSON checks are source evidence only. No installation,
client/provider, support, full replacement, qualification or publication result
is implied. Future authoritative Core semantics must progressively complete the
feature-planning/mailing investigations; this initial interface cannot become a
permanent generic browsing substitute.
