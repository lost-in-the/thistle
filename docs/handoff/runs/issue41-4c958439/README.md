# Issue 41: Canopy generated-source development validation

This is candidate development evidence, not protected qualification or private
application confirmation. The tested source head is
`4c9584392b0c92cb956bf4f306d2598f5cd81da8`, based on
`b53d64c6edf46e30b81b1c2cf91e94f4bb2f408e`. Independent advisory design/performance
and security/evidence reviews examined that head and these retained observations.
Their dispositions and subsequent corrections are recorded below; final candidate
acceptance remains pending. All capability rows remain unqualified.

## Workload and identities

The source is a disposable archive of Canopy testbed revision
`ed205379c477c3c379cddd6d5e615299fdce2dfd`; no app code or database was run.
The generator SHA-256 is
`8b3b2a1212bd6a9ea65d1f290487b265fd992b95e732de8b9e88fd74532e9d78`, seed
20261024. The common tree used 1500 models, 400 controllers, 200 jobs, 100
mailers and 12 packs. The full tree used 11000/400/200/100/12 respectively.
The common generator tree hash was
`8e19cd1cc1de3656fcb91dc2ca5c4f4156fdd1fb4f97e5d32588c528fcfdf138`.
To fit the unchanged file cap while exercising more generated source, adjacent
generated model files were paired and concatenated in the disposable full tree;
the retained transformation script SHA-256 is
`8184974ac80ad05ef7907cfcb738bcd88391f5f130c2d38c696bf2e7a4b493ca` and its
private mapping manifest SHA-256 is
`dbc4c79a1ffead69495e895c3e1ec335c5314dadcde29acf93d6d3157715eb49`. The
generator's pre-transformation tree hash was
`67fa20bb06b83a466572ac5eacef42cfbdda1ac6865311d5a7aca10e14e3216e`.
All 6,386 captured full-tree file digests matched the transformed source, 6,260
under generated packs. The private captured-source checksum manifest SHA-256 is
`1fc2ad9331b8fefee57209724152bdd68cf1b50cee48a0be9cc11c324e1dc660`.

The exact baseline Core and Map gem SHA-256s are
`581a20b8cb31fd8c3ad4f322cae40936b0b303f238e6c0874aa6dc44897eae5f` and
`8baf7d5b3854eb2df98d29a64e7ed28c5f02055abe7184aa2f26ca5828c365c2`.
The candidate Core gem SHA-256 is
`b5de17d335ccae22e60bb28e0323ec57c9355f92b9a7e3da2cd524024cd40c9a`; it used
the same exact Map gem. Loaded native SHA-256s were baseline
`a72f84997ea8c11d23b5a61fa773bd0b911653527f7e1f742ab0ea3ad6470ee7` and
candidate `b82d6e596b6fa17613152e01f4fe4ab2fe73355e8cd8a619e95441ea364f7f49`.
The actual installed binaries and gem bytes are retained privately with the
receipts. The Rust lock SHA-256 is
`7676db6a01a1d261e209217dd113f18dd29849de2b000c4175d03be7e3c5ec11`; the
CI policy hash is `2affcd264b417bcdd43324fe930947fd0af2dadbb1e8acb069a6e2127e6115c5`.
Workflow helper and measurement wrapper hashes are respectively
`d0542cd03cc4626eaca4ffa6d63c7cfc91513633d2c246cdc71c47af1e5d368c` and
`5cf37b9b382ee4bb0f214fcd38254f462fb7ad5ec6a392d27b07ef3f4af89cbc`.
The installed Map smoke helper hash is
`52fda5f7550a7655b755ba6f7f99a28b685e847c25bb1d69fbd301abdf066db1`.

## Results and limits

The rootless container image ID was
`f377fb86ef51f1b4b31787dc58131ad453fe306e58b36296f29e76a98487c520`
(digest `sha256:162d10fd66f5b30181b44a739f0c0721f1cededb215964c64cb7297ccf594ce6`),
with Ruby 3.4.12, Rust 1.90.0, Prism 1.9.0 and Rouge 4.6.1. It had no network,
owner home, sockets or credentials mounted. Hosted source CI used Rouge 4.7.0;
these manual installed measurements used 4.6.1 and do not cover that newer version.
Each measured process had a 4 GiB
memory and 256 PID cgroup limit, confirmed inside the container, and a 180 s
subprocess deadline. Output size was not independently capped. Python's
`getrusage(RUSAGE_CHILDREN)` recorded process peak RSS; it is not an enforced RSS
budget. Host load and swap were active, so these are observational timings,
not controlled speed claims. Private receipts and artifacts are retained under
the owner’s restricted `thistle-41-run` cache; the exact local locator is held
in the coordinator receipt. Generated sources are separately private.
The saved launchers used an image tag; the recorded current image ID/digest does
not retrospectively bind each historical attempt. The retained bundle also lacks
a complete per-attempt resolved dependency lock. Neither gap is an inferred pass
or a reproducibility claim.

The installed candidate reported 450,264 visited nodes on the common tree and
2,680,436 on the full tree, using a 5,000,000 node override on the latter. The
full tree had 6,386 files and 90,390 facts; its snapshot occupied 86,240,330
bytes. The encoded facts payload was 66,852,777 bytes, only 256,087 bytes below
the unchanged 64 MiB limit. Three candidate runs each captured and published,
then opened in a fresh process and completed Find, Source, Links, Check and Map
Source. Capture wall
times were 29.07, 29.39 and 28.12 seconds, peak RSS 1,888,612, 1,888,904 and
1,888,220 KiB. Fresh-reader/Map times were 7.39, 7.12 and 6.95 seconds, peak
RSS 1,790,388, 1,790,544 and 1,790,836 KiB. Results and selected source digests
matched across attempts. Readers were closed before Map. The accepted baseline
refused the same full input at `max_nodes`; no speed ratio is computed against
that refusal.

The reader phase includes full facts export, JSON serialization and hashing as
well as Find, Source, Links, Check and Map. Its RSS is not attributable to opening
the reader alone. Phase times include Ruby startup and helper work, excluding
container startup. The selected Source/Map fact is in an unchanged nongenerated
file; a paired generated-model known-answer check remains for the final audit.

Three alternating common-tree pairs completed the same workflow. Baseline
capture/reader seconds were 10.22/1.64, 9.72/1.64 and 9.73/1.66; candidate
times were 9.81/1.67, 10.29/1.68 and 9.82/1.65. Common capture peaks ranged
404,616–405,048 KiB and reader peaks 390,452–428,344 KiB. Each had 2,446 files
and 19,950 facts. Facts, selected Find, Source and Links digests and Map status
matched across all six; generation/producer metadata differed intentionally.
The separately installed candidate Map smoke passed. The first source-tree Ruby
test invocation failed to locate the extension; copying the built extension into
the private test tree resolved it. The complete installed runs above used the
actual installed extension, not that test copy.

An additional release-mode instrumented source probe measured the existing
preflight search-cache construction on the full snapshot: 68.5–69.2 ms across
three fresh processes, stopping the timer before cache destruction. Process
peak RSS rose approximately 19.3 MiB from immediately before to after construction;
this is a high-water difference, not an isolated allocation measurement. Its
accounting weight was 85,427,146 bytes; that weight is not a process-memory bound.
This isolated probe is not an installed binary benchmark and does not establish
the full-job overhead. The 5M ceiling
is provisional; these results exercise 2.68M nodes, not 5M, and the unchanged
100,000-fact and reader budgets can still refuse other trees. Wider support,
private-app confirmation, output limits and final review dispositions remain open.
The instrumented private `store.rs` SHA-256 was
`9ea015bf0ade64b38c86c339c5f3d8dd524fde41486b3ca41c1eb32579e567bb`.

## Review dispositions

The original full-workflow launcher could mask a container failure with its
logging pipeline status. It is preserved unchanged, SHA-256
`8ade58c64a508e85aa954a99b7ce5de99f189546dbc097a7bdabc64e197ef5cf`.
All six retained full-candidate phase receipts independently report exit zero
and matching generation bindings; no observed false success was found. The
baseline refusal remains unsuccessful. These observations do not excuse reuse
of the faulty launcher.

A separately retained corrected launcher saves and returns each container exit,
stops before inspection on capture failure, refuses existing attempt labels and
uses the current full image ID. Its SHA-256 is
`4aa6888f1ad5a1375f6d8d660772aff3819610080f1803d423757d86bab49816`.
Harmless stubs exercised capture failure (exit 7, inspection skipped), inspection
failure (exit 9 propagated) and success (exit 0). No campaign was replayed and no
earlier helper or receipt was overwritten. The new image pin changes future
collection only; it does not repair historical image or lock provenance.

The reviewed code also retained the caller's mutable limits hash. A subsequent
Ruby-only correction copies/freezes canonicalized keys and shares key validation
between direct, split and Rails entry points, while native numeric policy and
the combined native path remain unchanged. Focused tests reproduced two old-code
failures; the corrected Core suite passed 12 tests/158 assertions and capture/Rails
suites passed 14/72. A two-file test also covers cumulative visited nodes at the
exact budget and refusal one below it with `CURRENT` preserved. Those local tests
used copied corrected Ruby code with the retained native extension. The Canopy
receipts above remain bound to `4c958439`; fresh source and exact installed-pair
checks on both modern cohorts are required for the corrected candidate.

The gemspec excludes `docs/handoff/`, so adding this report alone does not alter
the packaged source set. The Ruby corrections do alter it. Rebuilt packages must
retain their own actual byte identities rather than inherit the hashes above.
