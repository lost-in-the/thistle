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

The main branch began as a bootstrap handoff with Git bundles. Source restoration
and experiment work already exist on named Codex branches. Before importing a
bundle or recreating a task, inspect its issue, branch, and PR status. An old
snapshot is historical evidence; newer accepted evidence must retain its own
identity and scope.

After source restoration, follow the implementation README for the pinned Rust
toolchain, Ruby development headers, C compiler, libclang, and locked vendored
dependencies. Preserve every vendored source file, including legitimate directories
named `target`. Run checks against the source and artifact actually under review.

## Submit a change

Use an isolated worktree and a branch named `codex/<issue>-<short-name>` or an
equivalent descriptive branch. Link the issue in a draft PR as soon as the change
is coherent. Keep the PR focused on one acceptance outcome, include attributable
check results, and identify the responsible reviewer. Update the issue after
review and verification rather than treating PR creation as completion.

Thistle requires a Rust core distributed as a Ruby gem. Woods engine code and a
console are outside scope; authorized Map reuse preserves its license and
provenance. Public release is a separate qualified and authorized operation.
