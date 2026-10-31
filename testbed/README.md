# Reusable Rails host

This repository-only fixture supplies five commands through `host.py`:
`prepare`, `start`, `status`, `test`, `stop`. See the
[operating contract](../docs/development/reusable-rails-host.md) for the private
input format, first-use schema grant, exact installed artifacts, finite runtime
admission, reuse/failure procedure and remaining execution gaps.

The first profile is **public Rails 7.1 compatibility**: Ruby 3.4.12,
Rails 7.1.6, public mysql2 0.5.7, Connector/C 3.4.9 and MySQL 8.4.13.
This is separate from the maintained CI Ruby 4.0.9/3.4.12 + Rails 8.1.4 policy.
The compatibility source does not reuse the earlier private-adapter fixture.

Harmless controller mocks and stdlib-only Ruby helper checks; no framework,
product, server or DB execution:

```sh
timeout --kill-after=5s 30s python3 -B -m unittest discover -s testbed/tests -v
```

The Ruby files are future runtime programs. A syntax check does not boot Rails,
load native code or establish installed acceptance. All 17 launch capabilities
remain unqualified.
