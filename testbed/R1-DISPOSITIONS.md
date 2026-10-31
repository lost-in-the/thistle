# LOS139 R1 same-author correction ledger

R1 reviewed **c9d0b2158acd680e8313940e7e47728711bc990f**,
tree1a229cb5dac9514739ebe94789f69b2462f3368d, base77c871274de68985a5964d2206b8a637824db97c.
Its verdict remains **NOT ACCEPTABLE for runtime** at that tuple. Report SHA-256:
`9b9b72cec3cb30aeaecdcc05b76390a35c14bbbadbbd89716b142a21682acbf4`.
The reported875.5s analysis overrun, setup/control limits and initial report-mode
gap remain recorded. No old review or test/package result is relabelled.

Root handed this author signed e67c766e37b1a7837ef5122c18fb9dd0a03d6cb7,
tree8fbdbce351a2e3debabd969552db5e9b47036203, parentsc9+64eee68.
Root's P0 raw-AR remedy, actual127 Host allowlist and selected Map1b9 binding are
preserved. Protected six F05 files stay exactly64eee68. Root merged PR115 as
main81336a5d0a6dc1da2e7631cedb03d6b03e842959 (complete tree equals64) and
retargeted PR116; the author made no parent write, local merge, rebase or retarget.

“Source corrected” below is the author's proposed disposition for ONE changed-
scope R2 owned by Root. It is not independent approval or runtime acceptance.
Root retains review/runtime/integration; PM metadata; Leah acceptance.

| Stable ID | Author disposition and concrete change | Focused evidence / remaining gate |
| --- | --- | --- |
| F01 P0 | **Root source remedy preserved.** `active_record` without its database.yml railtie, no dependent config.active_record field; private explicit connection remains after GO. | Syntax/source inspection only. Exact-cohort DB-free Rails boot remains Root's runtime gate. Stubbed metadata tests do not establish it. |
| F02 P1 | **Source corrected.** Token passed to host wrapper; `SessionLog` owns a fresh session host.log, opens inside rescue and retains safe failed-start diagnostics. PID reuse never selects an old session log. | Stdlib-only Ruby helper checks second start in the same PID, old log preservation, failed-start receipt and exclusive/private modes. Full app stop/start still unrun. |
| F03 P1 | **Source corrected.** Literal fixture index/FK identities in expected.json; actual columns/indexes/FKs/rows/schema/seed compared with declarations. Removed instance-local schema.json gate; raw signature is evidence only. | Actual database verifier with declared-metadata stubs passes from two empty instance directories and refuses missing index/wrong FK. No SQL/DB was executed. New Map instance reuse of the real retained schema remains runtime. |
| F04 P1 | **Source corrected.** Query LoadState/ActiveState; structured exit5/not-found/inactive and GC races are idempotent only with actual unreachable port. Unexpected helper errors fail. | Actual stop_access tests, not blanket cleanup patches: not-loaded, inactive, GC, unexpected exit and reachable-port negatives. Real systemd/port cleanup remains runtime. |
| F05 P1 | **Source corrected.** Cleanup uses exact ID+instance/token/role ownership and actual state/absence, independently of startup isolation. Failed isolation still cleans owned resources; foreign ownership refuses. | Controller tests cover failed create after effect, full-isolation mismatch, external removal, inspect error/recovery and foreign resource refusal. Actual Podman effects remain runtime. |
| F06 P2 | **Source corrected.** Confirm all writers stopped before snapshot; independently verify frozen bytes before rm; then prove absence and seal final index/STOP. New custody attempt on retry preserves old partial/failure. | Ordered stop→snapshot→rm test, one-shot copy failure/no rm, retry without old-partial promotion, missing results and failed cleanup. Actual exec timeout/whole-container stop still runtime. |
| F07 P2 | **Source simplified.** Private Puma Unix socket with explicit077/0600 and700 session directory; direct maintained socat UNIX-CONNECT, no relay.rb/_relay/per-request Python+Go. Actual socket identity and owned TCP listener checks remain. Four parallel host requests include semantic pages and assets. | Source command/socket-negative and parallel orchestration tests. Root's separate provider/literal-Unix2f1ecc97 scoped PASS supports API/provider/peer/Host/private modes only; real Rails/Map host TCP, bridge task/RSS and browser behavior remain OPEN. No host performance claim. |
| F08 P2 | **Source corrected.** Find requires exact result ID/generation; Check parses verified integrity; Source requires selected identity/hash/lines; site links require exact origin/generation/line and two rows across Rack/internal Unix/host HTTP. | Python and stdlib Ruby negatives reject200+hidden-generation/no-match, failed Check and missing source/sites. Native/installed known answers remain runtime; no stub refusal is called a native result. |
| F09 P2 | **Source corrected.** Final session custody contains controller/app/control source identity, declared commit/tree, admission/cohort/cgroup/namespace/scratch/internal+host endpoint/log receipts, raw attempts and STOP/absence. Git-backed source check rejects untracked/ignored extra app/control files. | Custody payload/index assertion and undeclared-source regression; independent frozen/final readbacks. Root's actual full installed/raw audit remains required. |
| F10 P3 | **Source corrected.** Python/Ruby polled JSON uses private temporary writes plus atomic exclusive link; mutable latest state uses atomic replace. Immutable receipts cannot be overwritten. | Controlled partial-write test proves final path stays absent until complete, with0600 creation; exclusive JSON tests preserve original content. Power-loss/directory durability is not qualified. |
| F11 P3 | **Source corrected/bounded.** Current session only; shared artifact blobs and indexed references; no all-history session hashing. Two-second active-session/fixed-cache disk sampling and coarse receipt polls replace50ms full-work walks/inspect floods. | Multiple attempts/sessions reuse shared bytes; old corruption remains failed but does not block new session; partial custody remains history. Selected current artifact integrity is rechecked; state/history metadata still grows. No FS/global quota or measured speed claim. |
| F12 P3 | **Source corrected.** Fixed homes before initial require; non-default roots strictly/work/gems or/dependencies. Defaults bind actual gemspec/version/hash and absolute immutable-image feature hashes. Consumer only activates needed Core/Map/Rack/Rouge, refutes ActiveSupport/Rails/AR and uses the producer's lock-checked projection. | Stdlib helper rejects same-version external provider, default hash drift, basename prefix escape, ActiveSupport and builtin-as-file. Root's separate actual provider/default manifest2f1ecc97 is scoped PASS, not host execution. Full loaded host/consumer identities remain runtime. |
| F13 P3 | **Source corrected.** Note renamed116.testing for this actual PR; repository-only testing infrastructure stays outside shipped gems/runtime dependencies. Removed time-relative wording; immutable MySQL image formats match normalized comparison. | Notes filesystem/text and documentation checks; immutable image serialization regression. No Woods engine/code imported; pinned conceptual precedent/license caveat retained. |

## Source check attempts and limits

This is a newly named author source/mock phase, not a reset of old runtime or
review clocks. Ordinary GNU timeout30s+kill5 guards static checks/unit invocations;
per-unit60s, aggregate guarded-check300s and controlled-artifact8MiB ceilings.
Private check outputs use0700 directories/0600 exclusive files from creation.
No quota, independent evaluator or protected execution claim is made.

- S1: an intermediate Python AST check refused an indentation error before tests
  or product execution. Corrected the source indentation; the next parse passed.
- S2:22 adapted controller tests PASS0.680s on the intermediate correction.
- S3:38 current controller/std-helper tests PASS1.150s, including five Ruby helper
  groups. These are new source tuples; prior12/15/22 at old commits stay separate.
- S4:41 tests PASS1.263s before the final published-index identity guard.
- S5:42 tests PASS1.256s;22 Ruby/Gemfile syntax checks, shell syntax, notes
  precheck and whitespace checks PASS. All26 guarded commands completed in
  1.599s; conservative prior-check debit10s keeps the aggregate below300s.
  Private final receipt index SHA-256
  `5461d1c26e78d73dff18a1f0245bac24c7bb92a5fa2a0e97cf89b374c90a535a`
  was independently reopened. The final handoff supplies its local location.
  Nothing in these mocks/syntax checks runs Rails/app/Thistle/native/gem install/
  build/capture/DB/container/server/browser code. Only stdlib controller helpers
  and explicit metadata/process stubs execute. No DB secret values are read.

## Separate preparation and acceptance

Root's manualV2 report13ba33e4 remains overall FAIL at a trusted builtin-path
probe bug, despite an actual successful Puma build and completed input manifests.
Continuationfd85316 and initial0644-envelope failure also remain failed attempts.
Root's later literal-Unix/provider phase is **scoped PASS**, report
`2f1ecc9766d1ce6372ebd71f3c83515f4ed0c1ee2ada2b3907459b407d71d8e6`,
index `5d356986efcbf156260c636b0331518357c4906873c88ce6424bb94ae322157b`.
It reused locka438/dependencies22be/defaults4a0d without repeated builds; actual
Puma/Nio/public mysql2/client/Rack/Rouge/defaults and four literal Unix peer/Host
responses passed. Its whole-container peaks are not host bridge/performance
acceptance. Source/app/Rails/Thistle/DB/TCP/browser were UNRUN in that phase.

Next owner is Root: ONE changed-scope R2, then separately admitted physical
Runtime PREEXEC, real DB-free boot, first use, same-instance reuse, new-artifact
instance reuse of retained schema, actual host answers/parallel assets/resource
cost, controlled failure/absence/KEEP and independent final payload/index audit.
Hosted affected CI and Leah acceptance remain open. All17 remain UNQUALIFIED.

## Root scoped R2 correction

The independent changed-scope R2 reviewed signed258f81d/f27855c. Its report
`32071a8c8938e774c06fee5139236f704165b2b6c17acaf7938d68e9d40ce23e`
remains **NOT ACCEPTABLE for runtime at258**. Its827s analysis exceeded the
300s target. The exclusive0600 report was retained unchanged; no review or CI
result is relabelled as execution of the corrected source.

Root took the released worktree for this small batch and applied the review's
specific remedies, without another author or review panel:

- **LOS139-R2-F01 P1 / R1-F08 host leg:** JSON decoding runs only for the Check
  page's exact unlabelled `pre.check-data`. F05's labelled literal syntax block
  is never decoded as JSON on Links/incoming. A positive regression uses the
  actual ConstantOccurrence markup, with both recorded site links; a labelled
  fake integrity result cannot satisfy Check.
- **LOS139-R2-F02 P3:** stop reloads persisted state after both final-index
  success and failure. Failed finalization preserves shared evidence and the
  partial custody entry; a later stop takes a new attempt without overwriting it.
- **LOS139-R2-F03 P3:** read-only FAILED/STOPPING status returns the last stop
  and observed exact-owned container states, including stopped retained compute.
  A completed no-op stop verifies no owned compute and preserves its meaningful
  receipt. Failed custody still retries rather than taking the no-op path.
- **R1-F04 residual:** start refuses an occupied loopback port before creating
  containers. A later bind race remains a truthful runtime failure; this check
  does not reserve the port or authorize touching a foreign listener.

Five new regressions fail on the fixed258 controller before the correction.
The corrected source passes47 controller/std-helper tests in1.388s, with no
framework/product/native/DB/socket/server/container workload. Root's scoped
source disposition resolves these precise findings; it is not an independent
post-correction approval or a runtime result. The original R1/R2 reports and
their source identities remain unchanged.

The parser still makes one bounded HTML pass, with less JSON work on site pages.
Error-path custody adds one state reload, not another history or artifact scan.
Failure status inspects at most the two owned role IDs and does not mutate them.
No Core/Map package, schema, Reader, access rule, source cap or fixture answer
changed. Current-head affected CI and actual full-host admission/execution remain
required. Person-performed usability and all17 qualification remain separate.
