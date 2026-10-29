# Portable agent configuration

The [mission](../MISSION.md) governs intent. [AGENTS.md](../../AGENTS.md) is the
repository entry point; the [workflow](agent-workflow.md) owns coordination and
the [review, test, CI and release policy](pr-ci-release.md) owns those gates.
Keep one canonical source per shared rule and link to it from other entry points.

## Public contracts and private values

| Repository-owned, portable material | Local or private material |
| --- | --- |
| Mission, shared rules, review/test/CI/signing policy and documented setup contracts | Host paths, worktree locations, personal preferences and account arrangements |
| Useful portable skills or tool procedures, with explicit inputs and prerequisites | Local tool installations, signer and credential-store references, private sources |
| Sanitized examples using relative paths or named parameters | Transcripts, application captures, sensitive logs and credentials |

Shared setup must disclose required tools, versions, permissions and inputs.
Local configuration supplies environment-specific values and optional conveniences;
it cannot weaken shared gates or create an undisclosed contributor prerequisite.
Extract useful portable behavior
from a local procedure with parameters, rather than copying an entire personal
configuration. Do not reorganize configuration or add a skill/service solely to
increase the number of instructions or agents.

Keep required commit signing enabled and use the authorized configured signer.
If signing is denied, unavailable or times out, stop and report that owner
authorization is needed; never retry unsigned or disable signing. Signer and
credential-store references belong in local setup, not public examples.
After a timeout, inspect HEAD and status before any authorized retry: the commit
may already exist even if a later hook stalled.

Secrets belong only in the authorized secret-management mechanism, never in
instructions, examples or issue/PR text. A reference can also reveal private
infrastructure; sanitize it before sharing. Ignore rules are convenience, not
access control. Check tracked files, staged changes and generated artifacts,
including logs, archives, reports and package payloads, before sharing them.
Repository visibility does not authorize publication of restricted evidence.

For example, a portable procedure can take `THISTLE_CANDIDATE_DIR` as an explicit
input and state the required artifact identity. The local value and credentials
stay outside the checkout. Reuse the [existing validation command](pr-ci-release.md#running-and-inspecting-the-flow)
rather than copying its implementation or privately supplying a missing gate.

## Instruction discovery: verify the actual runtime

The official [Codex AGENTS.md contract](https://learn.chatgpt.com/docs/agent-configuration/agents-md)
documents this discovery order:

- Global guidance comes from `CODEX_HOME` (default `~/.codex`): the first nonempty
  `AGENTS.override.md`, otherwise `AGENTS.md`.
- Project discovery walks from the project root, normally the Git root, to the
  starting working directory; without a root it checks only that directory.
  Each directory contributes at most one file: `AGENTS.override.md`, then
  `AGENTS.md`, then configured `project_doc_fallback_filenames` in order.
- Deeper guidance appears later and overrides earlier guidance. Empty files are
  skipped; `project_doc_max_bytes` limits the combined instructions (32 KiB by
  default). New runs rebuild the chain; a TUI session normally builds it at launch.

A nested or archive `AGENTS.md` applies along its directory path, not globally.
Linking a document makes it discoverable to readers; it does not make its text
automatically loaded instructions.

Separate three kinds of evidence when checking setup:

- **Official contract:** cite the runtime's documentation and relevant version.
- **Observed session:** record the starting directory, applicable files,
  overrides, discovery settings and guidance actually supplied to the agent.
  A harness may inject instructions; distinguish that observation from native
  filesystem discovery. Keep the report sanitized in the issue/PR.
- **Unverified adapter:** leave T3, another provider or a wrapper's loading
  behavior unverified until its contract and actual session establish it.
  Never infer discovery from an arbitrary role filename or skill directory.

Inspect the supplied session and relevant settings without exposing private
configuration. File presence alone does not prove loading. A coordinator can
explicitly assign a useful role or procedure by reference; this requires no
invented autoload mechanism. Keep any future adapter setup explicit about what
it reads, when it refreshes and how a contributor verifies it.
