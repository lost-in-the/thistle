# Genuine Rails 7.1.6 evidence (LOS-67)

This source candidate extends the existing model, association, registered-save
callback and route-constraint observation families to exact Rails/Active Record
7.1.6. Rails 8.1.4 remains the regression control and maintained CI default.
This document is a contract and execution plan, **not a runtime/support receipt**.
All 17 launch capabilities remain unqualified. Root owns integration, substantive
review, current CI and settled-package validation; Leah owns applicable acceptance.
The PM owns Linear metadata and acceptance tracking.

## Framework boundary and alternatives

Ruby observes bounded primitives; Rust independently admits exact AR versions
7.1.6 and 8.1.4 at observation and saved-fact validation. Callback normalization
copies the observed version instead of writing an 8.1.4 label. Native allowlists
cannot authenticate a process or detect a dishonest producer; they reject
unsupported declared layouts and invalid semantic/provenance fields. Genuine
runtime evidence additionally requires actual loaded gem/native identities.
No capture, parser or schema format changes are made.

The framework sources establish these narrow compatibility decisions:

* [7.1.6 AbstractAdapter](https://github.com/rails/rails/blob/v7.1.6/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb)
  and [ConnectionPool](https://github.com/rails/rails/blob/v7.1.6/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb)
  expose connection-bound schema reflection. Use `with_connection` for the old
  layout, preserving its lease cleanup, rather than the 8.1 pool-cache API.
  Effective owner checks reject overridden boundary readers. Schema/cache and
  adapter internals still operate under the supplied application's authority.
* [7.1.6 Inheritance](https://github.com/rails/rails/blob/v7.1.6/activerecord/lib/active_record/inheritance.rb)
  distinguishes an unset abstract ivar from an explicit flag. Only an effective
  framework-owned predicate permits interpreting the primitive stored flag;
  unset means false there. Overrides and opaque storage stay unknown. Unknown
  abstract status does not trigger schema access.
* [7.1.6 class_attribute](https://github.com/rails/rails/blob/v7.1.6/activesupport/lib/active_support/core_ext/class/attribute.rb)
  stores values in generated public reader closures. Compare the effective
  `__callbacks` reader must be a pure captured-value block: only the captured
  argument load and return instructions are accepted, with no sends or branches.
  A fresh probe cannot be compared by identity because 7.1 recompiles declarations.
  The VM projection of a rejected getter is additional source-inspection work,
  not a measured heap/RSS bound. 8.1.4 keeps its existing private-reader identity
  guard. An overridden `_save_callbacks`
  is never called; overridden 7.1 storage becomes unavailable. Unsupported VMs
  without RubyVM instruction sequences also remain unavailable. No callback,
  condition, custom default, association scope or dispatch body is evaluated.
* [7.1.6 mapper constraints](https://github.com/rails/rails/blob/v7.1.6/actionpack/lib/action_dispatch/routing/mapper.rb)
  retain the existing wrapper/read shape. Existing exact types, opaque values
  and family byte/count budgets remain in force; observing a constraint does
  not establish a matching/executed request.

A tiny Ruby version declaration prevents drift across the three owned observers.
Rust deliberately keeps its independent allowlist. Reusing the framework APIs
and existing bounded copier is preferable to a dependency or general adapter
layer for two exact layouts. A public callback accessor without a code guard,
VERSION spoofing, broad truthiness conversion, all-version duck typing and
eager loading would erase uncertainty or execute application code. They are
rejected alternatives. Reconsider these decisions only for a separately reviewed
actual cohort/layout or a demonstrated guard limitation.

The added work is constant version/owner checks and one schema lease per concrete
model on 7.1, plus a getter VM-code projection per 7.1 model or one 8.1 callback
reader-code probe per observer instance. Inventory,
column, association and callback work remains bounded by existing fact/entry/byte
limits; no new process-wide cache or FFI crossing is added. Adapter checkout and
schema introspection can establish connections, run setup/session statements and
read database metadata. Read-only intent does not prove those have no effects.
No latency, RSS, throughput, complete-session cost or broad adapter result is claimed.

## Finite validation handoff — not yet executed

The current grant is source/research/light static only. No heavy slot is held.
Native compilation, installation, Rails capture and database work wait for Root's
separate finite technical resource allocation. Preserve all attempts and stop
dependent steps on failure; do not download/install an unknown fork.

1. Root binds a reviewed candidate and disposable isolated fixture to exact
   Ruby/platform, Rails/AR/AS/actionpack, adapter gem/fork commit/patch, native
   adapter/client build, server/cluster settings and tool identities. Hash the
   candidate inputs, gem/native bytes, lock/dependencies and fixture. Use private
   disk-backed input/TMP/log directories (0700, files 0600), explicit deadlines,
   process/CPU/RSS/PID/log/disk bounds and cleanup. No credentials for release,
   evaluator policy or production are present in candidate execution.
2. Run focused native model/callback admission and saved-fact refusal tests. Their
   synthetic primitive version mutations test admission only; they are not genuine
   Rails evidence. Run affected 8.1.4 observer/capture/publication regressions as
   the control, preserving its prior accepted package identities.
3. In genuine 7.1.6, select `test/test_rails71_evidence.rb` explicitly with
   `THISTLE_RAILS71_EVIDENCE=1` and an owner-provided private JSON config path in
   `THISTLE_RAILS71_DATABASE_CONFIG`. Without selection this dedicated lane skips;
   a skip is missing evidence. With selection, a missing config or wrong loaded
   gem/runtime version fails. No version constants are replaced.
   Set `THISTLE_RAILS71_LOG_DIR` to a fresh existing 0700 private attempt directory;
   producer/consumer stderr is retained in exclusively created 0600 files, at most
   4 MiB each. An outer runtime bound must also cap child output/process memory;
   these post-capture diagnostic checks are not an execution resource sandbox.
4. The isolated fixture owner pre-provisions ONLY harmless known-answer tables:
   `thistle_rails71_orders` with integer primary key `id`, nullable string `type`,
   `state varchar(255) NOT NULL DEFAULT 'new'`; `thistle_rails71_items` with integer
   primary key `id` and nullable integer `order_id`. Leave
   `thistle_rails71_missing` absent. The test itself makes no schema/record writes.
   The test requires Mysql2Adapter configuration but cannot prove private fork
   identity or isolation from a config string; the trusted runtime owner must
   establish both BEFORE any connection. Record setup/session/schema-introspection
   statements actually exercised. Never point this at production.
5. Normal `Thistle.capture` publishes known columns/defaults, associations,
   inherited registration versus effective method owner, unevaluated conditions,
   string/segment and opaque route constraints. An override probe refuses unknown
   abstract/storage reads without invoking overrides. Missing schema preserves
   association evidence. A static second capture advances CURRENT; a separate
   fresh no-Rails process opens the saved generation and retrieves known answers
   and Check. The child uses the parent's actually loaded Core library path;
   source and installed invocations must keep separate applicability identities.
6. Root runs current affected CI and ONE settled changed-package acceptance with
   the required native/parser/reader-boundary and relevant Map checks. Record
   exact selected generation, source/fact/native/package hashes, input manifest,
   commands, attempts and results. The author does not accept qualification.

Existing 8.1.4 negative/budget/opaque regressions remain required. The new lane
does not establish complete inventories, autoload coverage, 7.2 compatibility,
all-adapter behavior or execution effects. No eager load/count-based inference is
introduced. Broader failure, packaging or Map evidence remains Root's gate.

## Concrete support-evidence gap

The declared target uses Rails/AR 7.1.6, Mysql2Adapter and mysql2 0.5.6 with a
private encoding patch, with Percona XtraDB Cluster 8.0.27-18.1 / Galera WSREP
26.4.3 (MySQL 8.0 compatible). MariaDB Connector/C 3.4.9 is the client library;
it does not make the server MariaDB. Trilogy is not the adapter. Reported
Ruby 4.0.5/aarch64-linux remains an input claim.

The exact private fork commit, encoding patch/build identity, gem and loaded
native artifact hashes, plus an authorized isolated fixture/environment have
not been supplied. Root coordinates those artifacts separately; no private fork
or application source, production connection, session/schema/record mutation or
new host/credential access is authorized here. Stock mysql2 0.5.6 cannot substitute
for that fork. Stock MySQL 8.0.45 single-node is a separate tuple whose results
cannot qualify the older clustered target. SchemaPool test doubles do not prove
actual adapter behavior. Rails 7.1/7.2 EOL compatibility is bounded; maintained
8.1.4 CI policy is unchanged and 7.2 has no inferred pass.
