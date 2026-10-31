# Reusable Rails host and installed journey

[LOS-139](https://linear.app/lost-in-the/issue/LOS-139) owns this developer fixture.
`testbed/host.py` implements the five lifecycle commands with Python's standard
library and rootless Podman. A small real Rails app provides one retained order,
two items, a save callback, two routes and two distinct nonreceiver `Order`
references. Installed Core captures it; a fresh Rails/AR-free Reader and Map
follow its saved generation after CURRENT advances. This is development evidence,
with Leah retaining acceptance and Root owning runtime admission, independent
review and integration. It is outside both gem file lists and runtime dependencies.

## Three persistent and disposable boundaries

| Boundary | Owner and contents | Mutation rule |
| --- | --- | --- |
| Persistent environment | Operator's retained MySQL data, accounts, private 0600 credentials, exact installed gem/native cache | Stop compute and keep state. No DB initialization, account rotation, DROP, wipe or implicit `db:prepare`. |
| Canonical fixture | This repository's `testbed/app/`, explicit migration, seeds and independently declared `expected.json` | Versioned source; prepare copies it once, and later source drift refuses. It never becomes a run's mutable working tree. |
| Per-run evidence | Private instance `work/sessions/SESSION/attempts/ID/{app,store}`, saved store, raw results, logs, loaded binaries, lock and retained indexes | Only this run-owned source copy receives the Gen A→B comment edit. Canonical app and retained rows do not change during tests. |

The original public71 `empty-v1` fixture, its two empty tables and failed-init
history are separate retained evidence. This app requires the distinct schema
`thistle_los139_app_v1`. Its `los139-schema-v1`/`los139-seed-v1` contents are
defined by the checked-in migration/seeds/expected answers. A failed partial
DDL attempt stays partial; a subsequent start refuses it. Recovery needs a
specific owner disposition, never automatic reset or seed replacement.

## Exact first profile and inputs

The named `public-rails71-compatibility-v1` profile requires Linux amd64,
Ruby 3.4.12/ABI 3.4.0, Rails 7.1.6, public mysql2 **0.5.7**, public Connector/C
**3.4.9**, MySQL **8.4.13**, Rack 3.2.7, Rouge **4.6.1**, Minitest 5.25.4
and Bundler 2.6.9. Rouge is explicitly activated because an unconstrained image
lookup can select 5.1.0. Puma is pinned to **8.0.2**, official native-ruby archive
SHA `c8ed871dfbbe66448ea9ffd46692342d9804d4071522b52b5331b7b6e7b686fb`
(265,216 bytes), runtime dependency nio4r ~>2.0. Root acquired that archive
separately; its native build/install remains UNRUN. It was not previously
installed in f377. The maintained CI primary/minimum remain Ruby
4.0.9/3.4.12 + Rails 8.1.4. This profile claims no modern-cohort result.

The first runtime image is the existing local immutable image ID
`f377fb86ef51f1b4b31787dc58131ad453fe306e58b36296f29e76a98487c520`.
It is an **image-bound installed profile**, not a portable archive set. The
selected tuple is checked before candidate execution:

| Input | SHA-256 |
| --- | --- |
| Core 0.1.0.pre.3 source gem | `469a6966b0cfb6f5b307fca52af206d8ce32aa5bf53052fda2cf03a7bce4b942` |
| Actually loaded Core native, 6,124,976 bytes | `4bee13087b17eb7aeb0e7ef606c7c0879d817e309e6acb2a09d520bd4c5f888e` |
| Original Core gemspec | `34949a0a21a1d1b8f84219d8bdd1b198e9eba5ffb2ced01ef70136b261351a08` |
| F05 Map from source 40a2809419987b824d5a7abccbd14c666fc249a5 | `3f18336f34cea30361aab62631c0dbe3ebd44f81832a7078259ae04f6fa498ff` |

The operator supplies a **new actual host lock** containing Map and Puma, an
exact preassembled installed dependency home mounted read-only at `/dependencies`,
its external file-identity manifest, a locally present immutable MySQL image
and retained data directory. The original public71 lock
`e69cfb4eca75663e11c95516144d4f94d2729ef07ae81017875ae7cd4c56eee2`
(2,904 bytes) contains rackup2.3.1 and excludes Puma and Map. Keep it unchanged;
it cannot represent the new host resolution. Root separately admits new lock
resolution and credential-free Puma native build; this runner does neither.

The public mysql2 extension SHA is
`4daad6688cd0f7fe990ed64c9df1d65d78d9327f315836d82ad62f4b046e2137`
(350,880 bytes); public Connector/C library SHA is
`a373e8e8216e180e5dca24a4da6dbe7db34cc520c0693fc29319a37953a58fb2`
(549,096 bytes). The library is an exact input selected via worker
`LD_LIBRARY_PATH=/input/artifacts`; loaded paths/hashes/version still require
runtime verification. A version-only cache match is refused: the cache key
includes artifacts, dependency manifest, lock, image, OS/arch and Ruby ABI. Observed
Ruby ABI/platform and loaded resolution are checked inside the worker before a
connection. The supplied lock is parsed as an exact resolution contract; it is
not represented as an already active Bundler lock. The parser uses the controlled
`/input/app/Gemfile` for context only. No `bundle setup`, inherited
`RUBYOPT`, `-I` or source-checkout fallback is used.

No package/client rebuild occurs. The loader extracts the exact source gems
without installation hooks, loads the **original spec directly**, restores the
verified native bytes/size, writes the extension's build-complete marker, clears
RubyGems paths, and only then looks up installed specifications. The installed
Map and Core paths must be in `/work/gems`; native and client identities must
match. Builtin relative feature names such as `enumerator`/`fiber` are recorded
as names; only actual absolute files are hashed.

The dependency manifest maps each relative file to `{"sha256":"...","size":123}`.
It lives outside the dependency tree. Prepare/start independently enumerate and
hash that entire read-only tree; symlinks and special files refuse. Assemble the
new host dependency set separately; never modify the original retained gem home.

On a fresh Linux machine the operator must obtain the exact authorized retained
image, MySQL image and artifact tuple through its existing trusted artifact
distribution, with matching data ownership and rootless cgroup-v2 support.
Ordinary new builds use the repository's [platform prerequisites](platforms.md)
and [candidate flow](pr-ci-release.md), public RubyGems/Rails and the public
mysql2/Connector/C providers; their changed bytes require a new reviewed profile.
There is no committed archive containing all f377 dependencies, no automatic
image acquisition/build, no new-machine bootstrap proof and no other-platform
result. An unavailable Puma, lock, client or image is a concrete preflight gap,
not permission to fetch/install/recompile or substitute the host's Connector/C.

## Private setup

Use Python 3.11+ on Linux, GNU timeout, rootless Podman with delegated cgroup
v2, a user systemd manager and maintained host socat with its exact binary hash
in the private profile. An owner first admits a finite execution window and proves the retained
MySQL resource is stopped. No service may already own that data directory.
The retained server UUID must be
`0fe59249-d501-11f1-964a-c4f5809f9f3d`; the app observes it again after connection.
Retained data must be writable by the admitted rootless keep-id UID/GID.
The harness never chowns existing data to make a run pass.

Copy `testbed/config.example.json` to a private 0700 directory outside Git and
set its file mode to 0600. Replace all `REQUIRED_*` fields and zero sizes from
actual nonsecret manifests/files. `instance` names a **new, absent** private
directory beneath an existing parent. Its input copies, locks, logs and retained
receipts persist across sessions. No personal absolute path is checked in.

`mysql_image` is a locally present immutable `repository@sha256:DIGEST` (preferred)
or image ID whose inspect receipt matches the configured identity. `mysqld`
is the actual absolute binary path in that image. No defaults/options file,
image startup initialization entrypoint, DB host port or external network is used.

The dedicated credential directory contains only `database.json` (0600, owned
by the operator). It is outside the instance and mounted read-only at `/private`.
Supply the following keys through the authorized private credential mechanism;
the table shows a format, with no account/password values:

| Key | Required value or source |
| --- | --- |
| `adapter` | `mysql2` |
| `database` | `thistle_los139_app_v1` |
| `socket` | `/socket/mysql.sock` |
| `username`, `password` | Dedicated app account, supplied privately |
| `encoding` | `utf8mb4` |

The DB administrator prepares only this empty app schema and its dedicated
account/grants under the separate runtime admission. First-use migration needs
table/index/foreign-key DDL and seed DML within that schema; reuse needs read
access. This runner creates no accounts and grants no privileges. Original
LOS67 schemas/accounts/credentials stay intact. No credential values or hashes
belong in configuration examples, argv, stdout, SQL logs or evidence indexes.

## Five commands

Set `THISTLE_HOST_CONFIG` to the private configuration path. After runtime
admission, from the repository root:

```sh
python3 -B testbed/host.py prepare --config "$THISTLE_HOST_CONFIG"
python3 -B testbed/host.py start --config "$THISTLE_HOST_CONFIG" --initialize-empty
python3 -B testbed/host.py status --config "$THISTLE_HOST_CONFIG"
python3 -B testbed/host.py test --config "$THISTLE_HOST_CONFIG"
python3 -B testbed/host.py stop --config "$THISTLE_HOST_CONFIG"
```

`prepare` copies and verifies canonical sources/artifacts. It starts no process
or DB and preserves partial effects on failure. `--initialize-empty` is an
explicit first-use app-schema action: it is refused after an initialization
attempt. Subsequent sessions use `start` without that switch. There is no
implicit schema creation, DB initialization or migration on reuse.

`start` validates source/artifact/lock/credential modes and retained UUID before
creating compute. Podman helpers must succeed with valid structured output.
The controller checks actual image IDs, rootless cgroup v2, precise bind mounts,
read-only root, dropped capabilities, no-new-privileges, no published ports,
finite CPU/memory/swap/PID settings, actual process namespaces and `/proc`/
cgroup limits before writing GO. The boot process checks its own namespace IDs
against that receipt before loading candidate gems or connecting. An incomplete
preflight cannot start dependent compute/connect/GO. A failed create is reconciled
by exact instance/lease labels before cleanup; an uncertain inventory stays failed.

Readiness requires the actual retained schema/seed checks, booted Rails and a
real TCP request to the known order controller. `status` performs only reads and
read-only Podman inspections; it verifies actual instance-owned compute against
the state record instead of trusting a stale RUNNING/STOPPED flag.

The developer endpoint is **host** `http://127.0.0.1:19292/orders/1` (or the
explicit profile `host_port`), with Map at `/map`. Exact topology: host loopback
→ bounded socat listener → fixed Podman-exec stdio → worker loopback TCP
`127.0.0.1:9292` → Puma/Rack. Socat owns listening/forking; a fixed Ruby stdio
pump crosses the namespace boundary. It accepts no target/port/program input,
and adds no generic proxy framework or eval endpoint. The host listener has a
token-owned systemd scope: 128MiB/no swap, one CPU, 32 tasks, at most eight
connections and a 900s GNU timeout. Actual cgroup limits and a **host-side HTTP
known-answer probe** are required before start succeeds. Stop checks the scope
stopped and the host port is unreachable.

App and DB retain `--network=none`, separate PID/network namespaces and no
external networking. MySQL has only its private Unix socket, never a forwarded
DB port. Map receives an actual worker-loopback peer from the transport and an
unchanged loopback Host. The host listener accepts only loopback peers. There
is no forwarded-header trust, authentication adapter or Map access bypass.
Internal and host-side probes are distinct receipts. Source mocks establish
neither host reachability nor browser usability; Root must test the actual
host URL in its admitted runtime window.

`test` boots the real app from a new run-owned copy, checks controller output,
associations and callback registrations, captures Gen A, appends a comment only
to the run copy, captures Gen B, verifies CURRENT advance, and restores that run
copy in `ensure`. Each attempt owns a fresh store below its session/attempt path,
refuses an existing store and verifies its owner marker. The host selects only
that current session's exact attempt store and records its saved generation.
Earlier stores/selections remain in older session directories. A separate Ruby
process with no Rails/AR opens Gen A. It checks
fixture-derived columns/association/route identities, source bytes/anchors, two
same-target sites, Links, integrity and pinned Source. Both Map Rack requests
and actual loopback HTTP Find/Source/Links/Check are retained separately. A
host-side Map probe must observe the same selected saved generation. Browser,
assistive-technology and human-use results remain unobserved until actually run.

`stop` retains/indexes evidence, stops only exact instance/lease-owned compute,
checks it stopped, removes containers and confirms absence. Data, accounts,
credentials, source, installed gems, locks and captures remain. A retention,
helper, inspection or cleanup error makes stop nonzero. Run-owned effects are
kept for diagnosis even when a failure prevents complete retention.

## Reuse and controlled failure

After one successful stop, repeat `start`, `status`, `test`, `stop` without
`--initialize-empty`. Actual UUID, schema columns/indexes/foreign keys, versioned
metadata and exact rows must still match; no silent reinitialization repairs
drift. Credential modes, canonical sources, installed artifact/lock resolution
and observed native/client identities are checked again.

For an admitted cleanup failure probe, start normally, then run:

```sh
python3 -B testbed/host.py test --config "$THISTLE_HOST_CONFIG" --inject-failure
python3 -B testbed/host.py status --config "$THISTLE_HOST_CONFIG"
```

The first command must return nonzero, retain `failure.json`, stop/remove
compute, and leave the retained fixture/credentials unchanged. The second must
independently observe STOPPED/absence. Inspect both exit codes; an expected
refusal is still a mutation attempt. Do not treat missing consumer/results or
an incomplete cleanup as success. Original failed-driver attempts remain FAIL;
this is a new procedure with a distinct candidate/attempt identity.

## Bounds, retention and troubleshooting

MySQL uses a separate private RW `/mysql-tmp` mount and explicit
`--tmpdir=/mysql-tmp`. Its fixed entrypoint verifies UID, writes/removes a
scratch probe and records the result **as the actual mysqld UID** before exec.
It never uses retained data as disposable scratch or assumes read-only-root
`/tmp` is writable. Startup requires the probe before GO; future runtime must
inspect it and verify cleanup/data preservation.

Runtime requests two CPUs, 2 GiB memory with zero swap, 256 PIDs, CPU 600s,
32 MiB file-size limits and a 900s OCI timeout per container. The host process
also exits at its lease deadline. A separate token-bound lease/disk monitor
stops compute at expiry or on a monitoring error. Inherited subprocess FSIZE
matches the OCI limit; helper output has a distinct 8 MiB cap. Helpers have
30s defaults, producer/consumer 120s limits, plus finite readiness deadlines.
Work disk monitoring uses a 512 MiB ceiling; ENOENT is tolerated only for
disappearing ephemeral entries, and other filesystem errors fail stop. These
are monitored work/process bounds, **not an enforced filesystem quota**, global
disk limit, performance result or promise about the retained database size.

Each attempt retains raw producer/consumer/native/client identities, the actual
loaded binary copies, cohort lock, exact input artifacts, manifests, source,
store, Map pages and logs before compute cleanup. `INDEX.json` hashes every
retained file except itself; a fresh enumeration/hash readback must agree.
Partial indexes and corruption block success. No private credential directory
is copied. Repeated sessions retain additional attempts and store generations;
operators must budget long-term disk growth and remove state only through an
explicit separate retention decision.

For failure, inspect the private `logs/`, `state.json` and attempt evidence;
public error output contains a fixed program/step, safe class and source-bound
error code. Ruby failures include at most one allowlisted control/app file and
line, never external paths, exception text, SQL, environment or inspected data.
The controlled failure has a distinct `CONTROLLED_FAILURE` receipt. Keep
failed attempts and current effects. Diagnose mismatched image/Puma/lock/client
identities, namespace permission/cgroup gaps, stopped DB ownership, schema drift
or retention failure rather than changing pins/limits or bypassing checks.
OCI timeout remains a bound if the host guard cannot run. Any missing required
isolation proof blocks candidate execution and is reported to Root.

## Source-phase evidence and next execution

The implementation phase permits only Python stdlib controller tests with a
mocked Podman boundary and Ruby syntax checks. It has not run Rails, loaded
candidate native code, built/installed gems, started DB/server/container,
connected, migrated, captured or opened a browser. Mocked reuse is a controller
regression, not proof of real retained-resource reuse.

Root's next finite runtime plan is: independently review the exact source/base;
prepare the new actual host lock and dependency set (including the separately
admitted Puma native build), verify client/image/transport inputs; record
Runtime PREEXEC identity/resource ownership and bounds; prove empty new app
schema/account authority and retained UUID; execute the five-command first use;
execute STOPPED→start→test→stop reuse; execute the controlled failure/absence
probe; audit retained raw payload/indexes and exact installed pair; then route
affected canonical CI and acceptance. No old public67 or LOS69 replay is part
of this plan. No new package acceptance, launch qualification, publication or
merge is implied by source checks.

## Implementation self-review

Correctness/lifecycle review found and addressed create-helper effects missing
from state, partial retention mistaken for completion, cross-attempt store reuse,
namespace-only developer reachability and read-only-root MySQL scratch failures.
Instance/token labels reconcile actual compute; indexes are re-read independently;
stores live under exact session/attempt owners; the host URL has its own probe;
the DB entrypoint probes its explicit scratch mount as the actual UID.

Security review checks fixed argv programs, env-i candidate processes, private
credential mounts outside capture/evidence, exact input/loaded identities, actual
namespaces/cgroups, no external networking/DB publication, token-owned finite
host access, unchanged Map peer/Host gates and sanitized source-local diagnostics.
This is author self-review, not independent approval or executed sandbox proof.

Cost/design review retained maintained Podman/Rails/Puma/socat mechanisms and
one fixture owner. The fixed stdio adapter exists only to cross the isolated
worker namespace without external networking or a new proxy framework. Hashing
dependency trees at admission costs O(input bytes); captures/readers and repeated
source expansion retain their existing costs. Each attempt retains a new store
and exact artifacts, so disk use grows; helper logs are selected since attempt
start to avoid copying all historic helper logs quadratically. No material speed,
RSS or global quota claim is made. Root must independently assess the composed
server/transport resource and lifecycle behavior, new lock/build applicability,
real cleanup and host reachability before accepting this source outcome.
