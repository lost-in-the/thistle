# Frozen evaluator reference

The evaluator is preserved as [thistle-eval.git.bundle](thistle-eval.git.bundle),
SHA-256 `7d24cf43a1ca1c57456d2a009e70bec8cfea10895aff5f981c92ab448e6acb2d`.
Restore it into a sibling repository, not into the implementation tree:

```sh
git clone docs/handoff/thistle-eval.git.bundle ../thistle-eval
git -C ../thistle-eval rev-parse HEAD
```

Expected commit: `b81f5adc2c647083b6ce8688234012c6d2da0ee4`.
Read its `README.md`, `evaluate.py`, `compare.py`, both boundary probes,
`fixtures/ruby/expected.json`, and `policies/experiment-001.json` there.
The policy SHA-256 remains
`14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe`.

Links in the relocated implementation handoff that formerly pointed inside the
expanded evaluator now point here. Its source/history are not imported into the
candidate's source history. The hosted development lane selects the bundle from
bootstrap commit `317671367949111861a63d0c3635dec94533fc8e`, verifies its digest
and revision, and executes it from outside the implementation checkout.

This preserves a separately versioned controller and unchanged expectations.
It does not deploy independent authority: the candidate-owned workflow and
same-user hosted worker can still be modified or attacked by candidate code.
An independently controlled private evaluator/testbed, external required check,
resource-isolated workers and branch/ruleset enforcement remain launch blockers.
