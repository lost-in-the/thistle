# Development tooling and cohort decisions

Reviewed **2026-10-28**. These are deliberate development choices, not permanent
defaults or launch qualification. Recheck the cited upstream state when changing
them. A historical baseline explains provenance; it does not justify a greenfield
default without a current fit, support and cost assessment.

## Ruby and Rails: current primary, one useful minimum

The exact pairs are owned by [`.github/ci-policy.json`](../../.github/ci-policy.json):

| Role | Ruby | Rails | Reason |
|---|---|---|---|
| Primary | 4.0.9 | 8.1.4 | Current stable Ruby and current stable Rails release; lead development on the environment the new project intends to serve. |
| Minimum | 3.4.12 | 8.1.4 | The other Ruby branch in normal maintenance; exercise its distinct Ruby/native boundary without an unnecessary Rails cross-product. |

Ruby's [downloads](https://www.ruby-lang.org/en/downloads/) and
[branch status](https://www.ruby-lang.org/en/downloads/branches/) identify Ruby
4.0 and 3.4 as normally maintained. Ruby 3.3 is security-only; Ruby 3.0 is EOL.
Rails announced [8.1.4](https://rubyonrails.org/2026/9/24/Rails-Version-8-1-4-has-been-released)
and explicitly described [7.2.4 as the final 7.2 release](https://rubyonrails.org/2026/9/24/Rails-Version-7-2-4-has-been-released).
The [Rails maintenance policy](https://rubyonrails.org/maintenance) lists security
coverage for 8.1 through October 10, 2027 and for 8.0 through November 7, 2026.
Starting a new default on 7.2, or adding a routine 8.0 row near its end of support,
has no demonstrated product benefit here.

Both gems now declare Ruby >=3.4. The Gemfile reads the primary Rails requirement
from the policy; an explicit `THISTLE_RAILS_VERSION` still selects a deliberate
test cohort. Exact patches make a run's intended inputs clear. Per-run locks and
manifests record actual resolution; this does not promise reproducible archives.
Linux remains the implementation's actual platform restriction.

PRs ordinarily use primary. Workflow, dependency, policy and Ruby/native-boundary
changes also test minimum. Main runs primary plus the separate minimum job;
scheduled/manual broad checks run both. The Rust-only unit suite runs on primary
once; both selected Ruby rows compile their own bridge and run applicable Ruby
and Map tests. A failed, cancelled or missing selected row cannot pass the
required aggregate. Release preparation builds one package pair and installs
those exact bytes on both declared pairs.

This is an explicit proposed support boundary for new candidates. Existing
historical evidence remains scoped to its original versions. The full launch
support and platform requirements still need accepted installed evidence; merely
changing the matrix or gemspec does not satisfy them.

### Why the original pair changed

The original source matrix used Ruby 3.3 / Rails ~>7.2. The hardened-baseline
commit `39f49d500ad941b01f9a839978f0fca599d812c6` pinned Ruby 3.3.13 / Rails 7.2.4,
and the [acceptance record](../handoff/BASELINE_ACCEPTANCE.md) records installed
checks and the selected artifacts on that pair. The first workflow draft reused
it for continuity without independently reviewing current support policy. That
was insufficient justification for this new project's routine default.

Keep Experiment 001's accepted packages, evaluator, policy and environment
identities. A current gem requiring Ruby >=3.4 cannot be substituted into its
Ruby 3.3 environment and called a replay. New work on the modern environment
needs new evidence; the earlier experiment's result is neither erased nor
silently broadened. The historical baseline workflow refuses current-policy
source before installing tools or compiling it.

The completed Experiment 001 workflow is
[retired outside active Actions](retired-workflows/README.md). Keeping its manual
dispatch with an exact historical-source allowlist was considered, but would add
preflight and failure-upload maintenance for a campaign that must not be replayed
as routine work. An inert copy plus exact original-source/run links preserves
provenance without a new executable guard or dependency. PR #27's maintained pin
updates remain separate from historical action identities. Reconsider an active
campaign only with a separately reviewed source/environment/policy decision.

## Changelogs: Woods' workflow, Towncrier's implementation

Keep the useful Woods model: each change owns a unique fragment; one release
owner consolidates notes. Use **Towncrier 26.9.0** for parsing, category grouping,
ordering, rendering and consumption. Its
[official documentation](https://towncrier.readthedocs.io/en/26.9.0/) supports
Markdown, explicit non-Python versions and independent packages sharing one
configuration. Core and Map have separate fragment directories and changelogs,
so preparing one package cannot consume the other's pending notes.

| Considered approach | Decision |
|---|---|
| Towncrier | Selected: established fragment workflow, configurable categories, explicit version/date, read-only preview, small Python tool environment already available to metadata CI. |
| Scriv | Capable, but broader dependencies and a looser authoring model do not improve this use case. |
| Changie | Good project support, but introduces a separate binary, YAML fragments and SemVer conventions that add adaptation to the current RubyGems prerelease spelling. |
| Reissue | Ruby-native, but build/version/commit hooks add coupling; its inspected fragment read/clear behavior needs substantive changes to preserve only-validated-input consumption. |
| Woods' implementation or a new custom fold | Adds ownership of parsing, history rewriting and deletion semantics without a demonstrated advantage over Towncrier. |

The inspected Woods policy is at
[`e7d69207...`](https://github.com/lost-in-the/woods/blob/e7d692072cce79220e2ea7efce0625003f9dd792/CONTRIBUTING.md#during-feature-work).
The adaptation keeps its ten useful categories and input-safety expectations;
Towncrier's native filenames are the new authoring format. Automatic folding of
old beta/RC history into a final section is not adopted: dated prerelease history
remains, and final-release notes are prepared explicitly.

Towncrier's inspected reader follows paths and replaces invalid UTF-8. A small
precheck therefore rejects non-regular/symlinked/nested inputs and invalid/empty
text before invoking it. This guard does not implement another renderer.
Always validate complete pending sets with strict draft rendering; the tool's
branch-presence `check` can intentionally skip when the consolidated changelog
changes, so it is not the sole validation gate.

The complete notes tool dependency set is pinned and hash-checked in
`.github/requirements-notes.txt`. It is development-only and ships in neither
gem. Measure installation and rendering cost before adding caching machinery or
claiming a speed advantage. See the [changelog guide](changelog.md) for commands,
package boundaries, staging behavior and release-readiness checks.

## GitHub actions: maintained runtime, immutable revision

The original pin check confirmed authoritative commit objects but missed obsolete
Node 20 declarations. GitHub's successful run still carried forced-Node-24
warnings. Passing CI was insufficient maintenance evidence.

| Action | Chosen release | Declared runtime |
|---|---|---|
| actions/checkout | v7.0.1 | Node 24 |
| actions/upload-artifact | v7.0.2 | Node 24 |
| actions/download-artifact | v8.0.2, existing pin retained | Node 24 |
| ruby/setup-ruby | v1.335.0, existing pin retained | Node 24 |

The [pin registry](../../.github/scripts/action-pins.json) records full SHAs,
versions and source metadata. The observed hosted runner 2.338.0 exceeds Node
24's 2.327.1 minimum. Keep `persist-credentials: false`, read-only permissions,
immutable artifact-ID downloads, digest mismatch failures and manifest checks.
Do not use a runtime-override flag to conceal an outdated action declaration.

## Rust and native dependencies: retain the declared contract for this change

Rust 1.90 is the explicit `rust-version` minimum and the pinned vendored build
contract. Preserve it and libclang 18 during this Ruby/Rails transition so that
failures have a bounded cause. The C extension uses public Ruby APIs; it has no
Magnus/rb-sys runtime dependency that forces the older Ruby cohort. Vendored
Prism 1.9 supports modern Ruby syntax, so no parser upgrade is required merely
to run on Ruby 4.0.

This is not a claim that Rust 1.90 produces the fastest possible build or binary.
Revisit it for an upstream security issue, a dependency/MSRV requirement, or a
measured build/runtime improvement in a separately reviewed change. Keep the
minimum compiler install contract distinct from performance claims.

## Capture parser grammar policy

Capture retains vendored ruby-prism 1.9.0 and its supported `parse()` interface.
Its null options select Prism's latest compatibility mode, currently CRuby 4.1;
a compile-time assertion against the public sys constants makes an alias change
or removal fail the build for explicit review. The direct sys dependency is
exactly pinned and already vendored. This guards the current behavior without
adding unsafe wrappers or modifying vendor checksums. Producer, Ruby coverage,
and syntax diagnostics report the effective policy; producer metadata binds it
into generation identity. Older manifests lacking it remain readable as unknown.

Host CI Ruby 3.4 and 4.0 are separate from source grammar. Compatibility mode
does not prove complete Ruby 4.1 language coverage. Alternative explicit typed
options in maintained Prism 2.1 would require a broader upgrade involving arena,
location, API and eager-error-vector changes; that cost is disproportionate to
this policy fix. An unsafe adapter to 1.9 private options would add ownership and
ABI maintenance risk. The retained guard requires reviewing parser upgrades and
checking upstream default semantics as well as the constants; it is not a runtime
negotiation or a configurable target. Reconsider for security fixes, needed syntax
features, supported explicit options, or a changed upstream default, with fresh
artifact and compatibility evidence.

## Maintenance rule

Every tool/version update records upstream maintenance/runtime status, actual
compatibility, CI resource/latency impact and why each retained cohort matters.
Inspect annotations as well as job conclusions. Dependabot proposes ordinary
action and notes-dependency updates; agents still review the release/runtime and
refresh the reviewed pin registry before accepting an action change.

Revisit Ruby/Rails policy when a new stable line appears, a dependency requires
it, or a selected line approaches the end of normal/security maintenance. A new
row needs a concrete supported customer pair or distinct failure risk. A custom
replacement needs measured or contractual benefit that justifies its ownership.
Do not carry a version forward just because a previous baseline used it, and do
not rotate a frozen experiment's inputs in place.
