# Reusable Rails host and installed journey

[LOS-139](https://linear.app/lost-in-the/issue/LOS-139) owns this repository-only
Rails app and the five commands in `testbed/host.py`: prepare, start, status,
test and stop. The app has one retained order, two items, an association, a
registered callback, routes and two distinct `Order` constant sites. Installed
Core publishes Gen A then CURRENT B from a run-owned source copy; a fresh Reader
and Map follow saved Gen A. This is a source implementation, not accepted host
execution. Root owns changed-scope review/runtime/integration, PM metadata and
Leah acceptance. All 17 launch requirements remain UNQUALIFIED.

## Boundaries and current inputs

| Boundary | Contents and rule |
| --- | --- |
| Persistent environment | Retained MySQL data/accounts, private 0600 credentials and prepared caches; stop compute without reset, rotation or wipe. |
| Canonical fixture | Versioned app/migration/seed/expected answers under `testbed/app`; no run changes the canonical source. |
| Current session/attempt | `work/sessions/TOKEN/attempts/ID/{app,store}`, temporary files, host log and atomic receipts. Each store is new and owner-checked; only that app copy receives the Gen A→B comment. |
| Immutable custody | Frozen current-session bundles and one indexed artifact copy referenced by digest; older failed/partial bundles remain historical evidence. |

The original LOS67 `public71-schema-v1`/`empty-v1`, its two empty tables,
accounts, credentials and failed-init history stay untouched. This app uses the
separate `thistle_los139_app_v1` schema with `los139-schema-v1`/`los139-seed-v1`.
The checked-in expected answers declare columns, rows, `items_order_id_idx` on
`order_id` and `fk_items_orders` from items.order_id to orders.id. Actual schema
is compared with those declarations; raw signatures are evidence, never an
instance-local `/work/schema.json` gate. A new artifact instance can reuse this
same retained schema without copying a gate file, resetting or reseeding it.

The first profile is explicitly **public Rails 7.1 compatibility**: Linux amd64,
Ruby3.4.12/ABI3.4.0, railties/Active Record/Action Pack7.1.6, public mysql2 0.5.7,
Connector/C3.4.9 and MySQL8.4.13, Rack3.2.7, Rouge4.6.1, Minitest5.25.4 and
Bundler2.6.9. It is a real Rails::Application with raw `active_record` and an
explicit private connection after GO, preserving Root's F01 remedy. No Rails
metagem/mail/storage/cable dependency or database.yml railtie hook is required.
Maintained CI remains Ruby4.0.9/3.4.12 + Rails8.1.4.

| Selected input | SHA-256 |
| --- | --- |
| Core 0.1.0.pre.3 | `469a6966b0cfb6f5b307fca52af206d8ce32aa5bf53052fda2cf03a7bce4b942` |
| Loaded native, 6,124,976 bytes | `4bee13087b17eb7aeb0e7ef606c7c0879d817e309e6acb2a09d520bd4c5f888e` |
| Original Core gemspec | `34949a0a21a1d1b8f84219d8bdd1b198e9eba5ffb2ced01ef70136b261351a08` |
| F05 Map 0.1.0.pre.3, source64eee68 | `1b9aad42d3b757617b268b0c1ed24e1e84c063837048c7de2ef9dab240f982c9` |
| Official native-ruby Puma8.0.2 archive, 265,216 bytes | `c8ed871dfbbe66448ea9ffd46692342d9804d4071522b52b5331b7b6e7b686fb` |
| Public mysql2 extension, 350,880 bytes | `4daad6688cd0f7fe990ed64c9df1d65d78d9327f315836d82ad62f4b046e2137` |
| Public Connector/C library, 549,096 bytes | `a373e8e8216e180e5dca24a4da6dbe7db34cc520c0693fc29319a37953a58fb2` |

The example selects signed parent `64eee68b736fc47369c30009a5eca022820d7caf`,
tree `6e56d58a94bc52de3ca607bc6b859e14f43cb61a`. It includes the incoming
byte/unknown-line fallbacks, outgoing details rendered once, and navigation to
Source's permitted final row. Root's current parent checks are source28/483
and changed-installed-Map12/238 passing; these are parent artifact evidence,
**not this Rails host's execution**. The earlier source77/Map68d tuple had
source26/461 and installed10/216 results; sourcea8/Map0144 had source27/472
and installed11/227. Preserve those dated scopes.

Historical supplied Map `3f18336f34cea30361aab62631c0dbe3ebd44f81832a7078259ae04f6fa498ff`
belongs to source40a. The intermediate byte-limit correction produced
Map `28fbb1378c5fd98860022c2b5776f4b250bacb276911253a007fea1f62d18216`
at source67f/tree2e9184, with source26/428 and installed10/183 checks.
Keep those original tuples and results separate.

Root merged parent PR115 as main `81336a5d0a6dc1da2e7631cedb03d6b03e842959`,
whose complete tree equals tested64. Root retargeted PR116 to that main base;
the author made no parent write, rebase or retarget. Parent CI/artifact results
remain their own tuples; new main CI and this host's runtime are separate gates.

The runtime is bound to the existing immutable image
`f377fb86ef51f1b4b31787dc58131ad453fe306e58b36296f29e76a98487c520`.
This is not a portable archive set. The old public71 lock
`e69cfb4eca75663e11c95516144d4f94d2729ef07ae81017875ae7cd4c56eee2`
(2,904 bytes) excludes Map/Puma and remains unchanged. Root separately prepares
an actual new host lock and Puma8.0.2 native/provider set under credential-free
controls. An available Puma archive does not establish build/install success.
No host/cohort result is inferred from that separate preparation.

Root's subsequent credential-free provider/Unix phase recorded a scoped PASS
(report2f1ecc9766d1ce6372ebd71f3c83515f4ed0c1ee2ada2b3907459b407d71d8e6,
index5d356986efcbf156260c636b0331518357c4906873c88ce6424bb94ae322157b).
The selected new lock is a4381c91145870d79d56371e5bc2d4796e78d0f9e637e855aa7daa2789c16f93;
the 3012-file dependency manifest is22be09e0933649c5084e3470db0564cb638c699b97b430e1b22b8e6d4f5dcebf;
defaults manifest4a0d87eb346216a64b94f270ecd86307d484d91ce943cf5adfeda9a0f48df650
binds58 genuine default specifications/1297 image files. Root observed four
literal Unix responses with peer127/originalHost, genuine selected providers
and private socket modes. Its whole-container peaks36,155,392B/14PIDs/0.444179
CPU-seconds are scoped observations, not host bridge or performance acceptance.
ManualV2 overallFAIL13ba33e4, continuationFAILfd85316 and the earlier envelope
mode failure remain unchanged. This source phase does not replay builds/probes;
actual Rails/Thistle/DB/TCP/harness/browser execution is still UNRUN.

## Private preparation contract

Use Python3.11+, GNU timeout, rootless Podman with cgroup v2 delegation, a user
systemd manager and maintained host socat. First admit a finite runtime window
and verify nobody owns the stopped retained MySQL directory. Its expected UUID
is `0fe59249-d501-11f1-964a-c4f5809f9f3d`; auto.cnf is read non-secretly before
start and the actual server UUID/version are checked after GO. No datadir chown,
initialize, DROP, automatic db:prepare or credential rotation is provided.

Copy `testbed/config.example.json` outside Git into a private0700 directory;
the config is0600. Fill required paths/hashes/sizes from actual non-secret
receipts. Use a new absent private instance directory. Choose a short path:
its full `work/sessions/TOKEN/http.sock` must fit Linux's 108-byte Unix pathname
limit; the controller rejects longer paths before effects. The account must own
and be able to reuse the retained data through rootless keep-id.

`mysql_image` accepts exactly `repository@sha256:DIGEST` or
`sha256:64-lowercase-hex`. An unprefixed image ID is not accepted. Local inspect
may report a bare or prefixed Id; comparison normalizes that serialization.
No pull, image startup initializer, host DB port or external network is used.

The dedicated credential directory contains only `database.json`, owned by the
operator,0600 in0700, outside the instance. It is mounted read-only at `/private`.
Its private keys are adapter=mysql2, database=thistle_los139_app_v1,
socket=/socket/mysql.sock, encoding=utf8mb4, username and password. Supply account
values through the authorized private mechanism. Only the explicitly admitted
new-app schema needs first-use DDL/index/FK/seed grants; reuse needs reads. This
runner creates no accounts and changes no grants. Values/hashes of credentials
never enter argv, stdout, logs or custody.

The prepared dependency home is read-only at `/dependencies`. Its external
JSON manifest maps each relative regular file to `{sha256,size}`; prepare/start
compare the actual inventory and reject links/special files. A second hashed
non-secret **default-provider manifest** binds the immutable image:

```json
{
  "specs": {
    "example-default": {
      "version": "REQUIRED_OBSERVED_VERSION",
      "gemspec_path": "/absolute/image/default/specification.gemspec",
      "gemspec_sha256": "REQUIRED_ACTUAL_SHA256"
    }
  },
  "files": {
    "/absolute/image/loaded/stdlib-file.rb": {"sha256": "REQUIRED_ACTUAL_SHA256", "size": 123}
  }
}
```

Root must supply actual default specification and loaded-feature identities;
these examples claim no installed provider. Non-default loaded gem roots must
resolve under `/work/gems` or `/dependencies`; same-version external roots fail.
Fixed admitted gem homes are set before initial library requires. Actual default
spec files and absolute image features are hash-checked; a default version named
in the lock must also agree. The manifest may cover the complete approved
immutable stdlib/default tree without loading this host to discover it. Relative
builtin feature names remain names, never invented paths to hash.

`host_source.commit/tree` declares the actual signed host source. Prepare checks
Git HEAD/tree, tracked app/control/host.py files and clean bytes/modes, rejecting
untracked/ignored extra files. Profile/state/begin receipts bind controller SHA,
app/control inventory and its digest. The cache key binds artifact/lock, prepared
dependencies/defaults, immutable image, OS/arch and Ruby ABI, not versions alone.

The loader extracts exact Core/Map gems without hooks or rebuilds: direct original
Core spec → raw native hash/size → complete marker → clear_paths/find_by_name.
LD_LIBRARY_PATH selects the exact supplied public Connector/C library. Producer
preflight checks the actual lock and loaded client/native paths/hashes. Consumer
activates only Core/Map/Rack/Rouge, checks its actual providers against the
producer's lock-checked projection, and refutes Rails, ActiveRecord, ActiveSupport
and their activated framework gems. No inherited RUBYOPT, repo -I, Bundler setup
or source-path fallback is used.

Fresh-machine setup must obtain the exact authorized retained image/artifact set
through existing trusted distribution and satisfy rootless data ownership. The
[platform prerequisites](platforms.md) and [candidate flow](pr-ci-release.md)
describe ordinary new builds from public RubyGems/Rails/mysql2/Connector/C; changed
bytes need their own profile/evidence. No complete portable archive, automatic
acquisition or other-platform bootstrap has been qualified here.

## Five commands and new-candidate reuse

After Root's Runtime PREEXEC admission, set THISTLE_HOST_CONFIG to the private
config path and run from the reviewed checkout:

```sh
python3 -B testbed/host.py prepare --config "$THISTLE_HOST_CONFIG"
python3 -B testbed/host.py start --config "$THISTLE_HOST_CONFIG" --initialize-empty
python3 -B testbed/host.py status --config "$THISTLE_HOST_CONFIG"
python3 -B testbed/host.py test --config "$THISTLE_HOST_CONFIG"
python3 -B testbed/host.py stop --config "$THISTLE_HOST_CONFIG"
```

Prepare copies verified source/inputs, starts no app/DB, and retains partial
preparation effects on failure. First use requires an explicitly provisioned
**empty new-app schema**; initialize-empty is refused after an initialization
attempt. Partial DDL stays partial and must be dispositioned, never reset.

Start verifies inputs/source and actual rootless OCI image/CPU/memory/swap/PID,
read-only mounts, namespaces, process limits, CapEff0 and NoNewPrivs1. It starts
a confined preflight worker first; framework/native/client/lock validation reads
no DB credential or connection. Only a valid actual cohort receipt permits DB
start and the separate app GO. MySQL probes explicit private RW /mysql-tmp as
its actual UID before exec, then the app verifies retained UUID/schema/seed.
Failed/malformed helpers stop dependent mutation; failed create effects are
reconciled by exact instance/token labels. Status performs reads/inspections
only and reports actual compute plus the last cleanup/custody result.

A session token is passed to run.rb host; its private session host.log and safe
failed-start diagnostics survive PID1 reuse and are retained. Python/Ruby polled
JSON uses same-directory temporary writes plus atomic exclusive publication;
immutable evidence is never overwritten. Mode0700/0600 is set from creation.

For normal reuse, repeat start/status/test/stop **without initialize-empty**.
For a later Map/source/cohort candidate, prepare a **new instance/config** with
its exact inputs and current host source, pointing at the same retained app
schema/account/credentials. Start without initialize-empty. No old schema.json,
new schema, reset or copied instance gate is needed; declared schema/index/FK/
seed checks must pass unchanged. Prior instances, stores and reports stay intact.

## Actual developer access and answers

Puma8.0.2 listens on the fresh session's filesystem Unix socket, with explicit
umask077/mode0600 in a token-owned0700 directory. Existing/stale/wrong objects
are rejected; the controller verifies actual type/UID/GID/mode/inode. Root
inspected the pinned official/sha-verified binder source: Unix REMOTE_ADDR starts
as127.0.0.1. Actual peer/Host is still checked by an internal health request.

The advertised URL is **host** http://127.0.0.1:19292/orders/1 (or configured
host_port), with Map at /map. Exact path: host-loopback TCP → bounded maintained
socat UNIX-CONNECT → private Puma Unix socket → Rails/Map. There is no relay.rb,
per-request Python/Go/podman-exec, worker TCP listener, DB forwarding, external
network, forwarded-header trust or Host/auth bypass. Root's actual127 Rails
allowlist and Map's loopback peer+Host gates stay intact. Internal probes use
that Unix socket and are labelled INTERNAL; they are not host/browser proof.
Host readiness uses the advertised URL without replacing its Host header.

Test captures A/B only in a fresh owner-checked attempt store/source copy. The
fresh framework-free Reader verifies fixture columns/associations/callbacks,
full controller+action+path+verb route identity, canonical pinned source bytes,
site roles/spans/lines, and saved integrity after CURRENT B. Map Rack/internal
Unix/host HTTP checks require the known origin id in Find, verified Check JSON,
pinned Source id/hash/lines and exact per-site origin/generation/line links with
two F05 rows. A hidden generation field plus200 cannot pass these oracles.

The host probe issues four concurrent requests, checks all five semantic pages
and three assets under bounded responses/deadlines, and records actual scope
memory/task peaks. The scope stays128MiB/no swap/one CPU/32 tasks, max8 socat
children,900s GNU timeout. Actual four-connection success, process RSS/resource
cost, Unix peer/Host and browser/human usability remain runtime gates; mocks do
not establish them or a speed improvement.

## Stop, custody and failure

Stop checks LoadState/ActiveState, including structured exit5/not-loaded, before
stopping host access. Never-created/GC'd/inactive scopes are valid absence only
with the actual host port unreachable; unexpected helper errors fail. Container
cleanup uses exact ID+instance/token/role ownership and actual running state,
not the startup isolation gate. Exact-ID absence counts removed; ownership
mismatch never authorizes stopping another resource.

All writer compute is stopped/confirmed first. Then a new frozen current-session
snapshot is copied and independently verified; only then may containers be
removed and absence proved. The final immutable INDEX excludes only itself and
includes source/controller identity, admission/cohort/cgroup/namespace/scratch,
internal/host endpoint/host log, attempts and final STOP/absence receipts. Exact
input/loaded artifacts use shared digest references, not one full copy per
attempt. A failed snapshot keeps its partial directory and stopped/raw effects;
a later stop takes a new custody attempt. A later session does not re-hash every
historic session or relabel an old failed/corrupt bundle.

STOPPED means actual compute absence. A command can still return nonzero for
incomplete custody; inspect last_stop/retained reports. Cleanup/custody success
is explicitly separate from failed start or failed journey outcomes. Test's
passed result is custody-pending until successful stop/index readback. Old
failures and partial attempts remain visible and unaccepted.

For an admitted controlled-failure probe, start normally, run test with
--inject-failure, expect nonzero/CONTROLLED_FAILURE, then status must independently
observe compute absent and retained data/accounts/credentials unchanged. Inspect
both exit codes and final indexes. Missing results or incomplete cleanup never
become a pass; original public67 failures remain FAIL and no LOS69 replay occurs.

OCI requests two CPUs,2GiB/no swap,256 PIDs,600s CPU,32MiB FSIZE and900s wall.
Inherited helper FSIZE matches OCI; output has a separate8MiB cap. Helpers have
30s defaults, producer/consumer120s, and finite readiness/guard deadlines.
The active session plus fixed gem/loaded caches are sampled at two-second
intervals against512MiB; older session work is excluded. Only disappearing
ephemeral files tolerate ENOENT; other monitor errors fail stop. These are
monitored ceilings, not filesystem/global quotas. Retained history/state metadata
still grows and needs a separate explicit retention decision.

## Review and runtime handoff

The original full R1 at c9/tree1a229/base77 was NOT ACCEPTABLE for runtime.
Its report SHA9b9b72cec3cb30aeaecdcc05b76390a35c14bbbadbbd89716b142a21682acbf4,
875.5s analysis overrun and setup/report-mode gaps are preserved. Root's F01
source remedy at e67 is retained, not claimed boot-tested. The stable
[F01–F13 disposition ledger](../../testbed/R1-DISPOSITIONS.md) names corrections,
source checks and remaining obligations. One changed-scope R2 belongs to Root.

This author phase permits only guarded controller mocks, stdlib-only helper
checks and syntax. It runs no Rails/app/Thistle/native/gem build/install/capture/
DB/server/container/browser workload and reads no DB secret values. No new
runtime lease, evaluator approval, launch qualification or publication is implied.

After R2 disposition, Root must admit exact source/artifact/cohort/private-resource
inputs, prove real DB-free boot and Unix API/peer/Host, actual provider/client
loading, first use, STOPPED reuse, changed-Map fresh-instance reuse, four parallel
host requests/assets with tasks/RSS, controlled failure/nonzero/absence/KEEP,
and final independent raw/index audit. Hosted affected CI and Leah's acceptance
remain separate. The fixture/runner/docs stay outside shipped gem file lists and
runtime dependencies;116.testing is repository Map-test infrastructure metadata.
