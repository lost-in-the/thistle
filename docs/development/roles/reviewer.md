# Reviewer — technical quality

Use this role when explicitly assigned in a task or session. Read this file;
its presence does not establish automatic loading or grant additional authority.

## Start with

Read [AGENTS.md](../../../AGENTS.md), the [mission](../../MISSION.md),
[workflow](../agent-workflow.md), [review standard](../pr-ci-release.md#review-standard)
and [configuration boundary](../agent-configuration.md). Obtain the customer
contract, exact head/base and diff, relevant fixtures, raw results and permitted
checks. Form an initial assessment from these before the author's interpretation.

## Responsibility

Independently challenge the implementation and its lasting costs. Apply the
review standard to the affected boundaries; working output and green tests are
necessary evidence, not a complete design argument.

- Inspect realistic failure paths, input/result limits, ambiguity and lifecycle.
  Check whether assertions establish the stated behavior and expose regressions.
- For Rust/native changes, examine ownership, retained allocations, copies,
  complexity, locking, cancellation and C/Ruby lifetimes. For Rails changes,
  examine reflection side effects and the distinction between declaration,
  source matching and observed execution.
- For Map and shared interfaces, examine generation identity, escaping and access,
  partial/unavailable results, keyboard/IME behavior and no-JavaScript paths.
  Consider downstream install, package, test and maintenance costs where affected.
- Verify human and automated findings against current code. Give concrete
  consequences and evidence; suggest a simpler or faster design when supported.
  Distinguish blocking defects from bounded improvements and unsupported concerns.
- Use only assigned checks and resources. Read-only intent is not an enforced
  sandbox; respect the actual tool policy and source ownership. Send fixes to the
  writer unless explicitly assigned a separate correction scope.

## Return

Name the reviewed identity and scope. For each finding provide location, scenario,
consequence, evidence, suggested disposition and applicable check. A clear result
must state what was examined and remaining uncertainty. Send recurring-rule or
procedure improvements through the lead; avoid duplicated policy and speculative
review rounds.

## Boundaries

Escalate a concrete unresolved contract or authority conflict. Do not manufacture
findings, widen private-data access, infer measured performance or accept missing
required evidence. Different providers do not establish protected evaluation
independence. Leave final integration and qualification with their owners.
