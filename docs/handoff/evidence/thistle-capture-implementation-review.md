# Thistle capture implementation and boundary review

## Decision

APPROVE the current native capture foundation for private implementation work after the concrete correctness and parser-stack fixes below. This is not product parity, hostile-parser qualification, production security approval, or launch approval.

The capture implementation owns source inventory and syntax extraction in Rust, using the pinned established Prism 1.9.0 C parser through its Rust bindings. Ruby remains a gem facade and the explicitly invoked Rails route observer. No Woods engine code was read or reused. The interim Ruby static producer was removed.

## Implemented behavior

- Descriptor-relative native source traversal pins each directory, uses openat and O_NOFOLLOW for components, refuses unsafe paths, skips symlinks explicitly, and bounds entries, depth, files, source bytes, nodes, facts, relationships, diagnostics, and encoded fact payload.
- Rust captures Ruby declarations and lexical source locations without evaluating application code. Unresolved relationships, skipped dynamic scopes, unsupported encodings, parse errors, and missing runtime evidence remain explicit.
- Rust source is available as exact content and file facts, including the native engine's own source. Rust symbols, types, macro expansion, and semantic call graphs are explicitly unavailable.
- Rails route observations run only when a caller supplies an application. They do not claim source coherence, recognized request behavior, constraint semantics, or execution evidence. Runtime facts have no invented source positions.
- Static and runtime producers share one global facts, links, diagnostics, and encoded evidence budget. Runtime checks happen before accumulating an oversized batch.

## Findings resolved

1. **Whole-file endpoints:** newline-terminated files used an inclusive final content line alongside an exclusive end byte. The strict schema rejected valid captures. File and Prism node coordinates now consistently describe the half-open endpoint. Regression cases cover empty, no-final-newline, newline-terminated, and multibyte sources without weakening validation.
2. **Singleton ownership:** self inside a method is runtime-dependent; constants and mixins inside a singleton class do not belong to the ordinary namespace. The producer now omits unverified declarations and relationships, marks coverage partial, and reports dynamic_scope. Ordinary class-level singleton methods remain available.
3. **Merged runtime limits:** native max_links did not originally account for subsequently added route links. The Ruby boundary now passes residual counts and encoded-byte capacity to the route observer and refuses oversized combined results.
4. **C parser stack:** Prism's expression guard is 10,000 and its regexp guard is 4,096; its AST destructor also recurses. max_nodes is evaluated after parsing and cannot protect the parser's earlier recursion. Before mitigation, 10–20 KiB deeply nested inputs caused SystemStackError on the Ruby main thread and timeouts from Ruby worker threads. Capture now runs parsing and AST destruction on one explicitly sized 64 MiB Rust worker stack, with one active native capture per process and busy responses for contention.
5. **Core publication review:** a post-CURRENT-rename directory fsync failure cannot honestly promise the prior pointer remained current. The core integrator changed that condition to commit_uncertain. The encoded reader budget is described as encoded data, not a physical heap/RSS cap.

## Executed evidence

- Native capture tests cover no source execution, actual lexical facts, pinned directory descriptors surviving ancestor replacement, syntax/symlink incompleteness, hard limits, half-open source positions, and singleton ownership.
- The integrator reported the combined Ruby native/Rails suite passing 21 tests and 187 assertions before the permanent parser tests were added.
- The permanent parser boundary file independently passed 3 tests and 24 assertions, with no failures, errors, or skips. Its subprocesses impose CPU, address-space, wall-time, and core-dump limits around actual native calls.
- Twenty additional bounded subprocess cases exercised both Ruby main and worker-thread callers: nested parentheses at 1k/10k/100k depth, 10k arrays, 3k nested method definitions, malformed nesting, 250k infix expressions, 250k/1m call chains, and 10k regexp nesting. All exited normally with captured/partial evidence or explicit limit_exceeded. No timeout or crash remained in those cases. Observed elapsed times include Ruby startup and do not establish comparative performance.
- A standalone self-capture found native source and reported engine=rust/parser=1.9.0 with no Ruby Prism features loaded. Ruby Prism 0.19.0 loaded first also coexisted successfully with native Prism 1.9.0. Dynamic symbol inspection showed the extension exporting Init_thistle_native, with static dependency symbols hidden by the configured linker option.

## Remaining limits

The larger native stack is a tested mitigation for the reproduced failures, not proof of C memory safety or a general resource sandbox. Established C parser fuzzing, sanitizers, broader malformed-input campaigns, and separately controlled process isolation are still required. The gem call has no enforced CPU deadline or asynchronous cancellation; external process workers are needed when hard wall-time/CPU/memory authority matters. The configured 64 MiB stack is a stack size/reservation, not a statement of RSS. The core reader budget counts encoded data, while decoded objects and temporary query/serialization allocations require separate memory measurement.

The current source/build path is a Linux private milestone. It is not a declaration that other promised launch platforms can be dropped. Full Rails evidence families, effective Ruby resolution, immutable runtime boot/source coherence, incremental recomputation, semantic retrieval, and a Rust semantic analyzer are not silently implied by these tests.

## Frozen identities

- `engine/src/capture.rs`: `be1f7e88f314f0c3b99be74ee7583fca18bbcb8822cafa7e15ec5cbc03fd4841`
- `engine/src/capture_children.rs`: `93e82ae2bce5d2e8e67500b1740c8f1507122a81448172aa4749de81a82a2c36`
- `lib/thistle/capture.rb`: `b58a7596d139f5dfed64979c033eb643a43fb8ee45f66985a1721447f34d84d2`
- `lib/thistle/rails_capture.rb`: `7f8d108ce33724232555670607a89e80d4f0195de51b654a70787572f8d845b2`
- `test/test_capture.rb`: `b2c3d551b9369c5ca2e44b1f6d205c636800fc736f4174e2fecea3ac473c11a9`
- `test/test_rails_capture.rb`: `147df0f215bc6feec10801f60f9351971bbf2ceb40359d4fa202fa8879863248`
- `test/test_parser_boundary.rb`: `9d93a9665c09ec81590edb7c005bbbeb6e8b96fa03da56bb52fbc0fe0737bb54`
- `lib/thistle/thistle_native.so`: `e8b2225a559993f8b499142cd2e6c7fac48ec28d09003bad16083214a4f22705`

The native extension hash above exactly matches thistle-capture-parser-probes-v2.json. Product changes after that artifact need the relevant checks rerun. The source/fixture files are preserved in the implementation workspace; this review is an intermediate development record.
