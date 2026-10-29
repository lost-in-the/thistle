# Contributing to Thistle

Start with a bounded issue in the [Thistle project](https://github.com/orgs/lost-in-the/projects/2).
Use the Work, Bug report,
Experiment, or Check form to state the outcome and the evidence that will finish
the work. Set its project Area, Target, Priority, and Status during triage.

- [Agent and project workflow](docs/development/agent-workflow.md): views, fields,
  claiming work, multi-agent ownership, status transitions, and handoffs.
- [PR, CI, and release flow](docs/development/pr-ci-release.md): short-lived
  branches, fast checks, artifact qualification, and controlled release promotion.
- [Agent instructions](AGENTS.md): required product and authority boundaries.

## Start from current work

The main branch began as a bootstrap handoff with Git bundles. Baseline restoration
landed through PR #1; the restored source and `docs/handoff/` now live on main.
Experiment 001 landed through PR #2; its completed workflow is retired with
provenance and historical evidence preserved. Before importing a
bundle or recreating a task, inspect current issues, branches, and PR status. An
old snapshot, including the [initial project setup record](docs/development/project-setup.md),
is historical evidence; newer accepted evidence must retain its own identity and
scope.

Follow the restored README for the pinned Rust
toolchain, Ruby development headers, C compiler, libclang, and locked vendored
dependencies. Preserve every vendored source file, including legitimate directories
named `target`. Run checks against the source and artifact actually under review.

## Submit a change

Use an isolated worktree and a branch named `codex/<issue>-<short-name>` or an
equivalent descriptive branch. Link the issue in a draft PR as soon as the change
is coherent. Keep the PR focused on one acceptance outcome, include attributable
check results, and identify the responsible reviewer. Update the issue after
review and verification rather than treating PR creation as completion.

Use the current Ruby/Rails pairs from `.github/ci-policy.json`; the development
Gemfile reads the primary Rails requirement there. Both gems require Ruby 3.4 or
later. [Development decisions](docs/development/decisions.md) records why each
tool/version was selected and when to reconsider it. Existing precedent is
evidence to evaluate, not an automatic reason to preserve a choice.

## Conflict-free release notes

Follow the [changelog guide](docs/development/changelog.md): add one unique
fragment per noteworthy change under `changelog/` for core or `map/changelog/`
for Map. Parallel PRs leave the consolidated changelogs to the release owner.
Towncrier validates and combines the fragments; the small input guard preserves
Woods' filesystem and UTF-8 checks. Explain in the PR when no note is warranted.
Keep release-note tooling in development dependencies, outside the shipped gems.

Thistle requires a Rust core distributed as a Ruby gem. Woods engine code and a
console are outside scope; authorized Map reuse preserves its license and
provenance. Public release is a separate qualified and authorized operation.
