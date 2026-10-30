# Develop and install on macOS or Linux

Thistle uses a Rust core and a CRuby C extension. Build the extension on the same
OS, architecture and Ruby ABI that will load it. A Linux `.so` cannot be reused
on macOS, and a macOS `.bundle` cannot be reused in a Linux container. Use separate
checkouts/build outputs when switching environments.

The current source-build routes are Linux and macOS. Windows, other Unix systems,
precompiled gems and the complete launch support matrix remain unqualified.
Exact development Ruby/Rails versions live in [the CI policy](https://github.com/lost-in-the/thistle/blob/main/.github/ci-policy.json).
The minimum is Ruby 3.4; routine tests use Rails 8.1.4. Runtime observation in other
Rails versions still needs its own evidence. Static capture does not boot Rails.

## Native macOS

Install Xcode Command Line Tools (`xcode-select --install` if absent), Homebrew
and a Ruby version manager. The following uses mise without modifying global
versions or shell startup files. From this checkout:

```sh
brew install llvm@18
ruby_version=$(ruby -rjson -e 'puts JSON.parse(File.read(".github/ci-policy.json")).fetch("primary").fetch("ruby")')
mise install "ruby@$ruby_version" rust@1.90.0
export LIBCLANG_PATH="$(brew --prefix llvm@18)/lib"
export BUNDLE_PATH="$PWD/.bundle/gems"
mise exec "ruby@$ruby_version" rust@1.90.0 -- bundle install
mise exec "ruby@$ruby_version" rust@1.90.0 -- bundle exec rake test native map
mise exec "ruby@$ruby_version" rust@1.90.0 -- bundle exec rake installed
```

Other version managers are fine when they provide the selected Ruby, its headers,
Bundler and Rust 1.90.0 on `PATH`. `THISTLE_CARGO` may select an explicit Cargo
executable. Apple's C compiler is sufficient; `LIBCLANG_PATH` selects the separate
libclang library used to generate Prism bindings, not a replacement system compiler.

## Native Linux

Use the selected Ruby and Rust versions with their development headers, a C
compiler, `make` and libclang 18. On Ubuntu 24.04, the native system prerequisites
are available as `build-essential libclang-18-dev pkg-config`. Set
`LIBCLANG_PATH=/usr/lib/llvm-18/lib`, then run the same Bundler/Rake commands.
Cargo builds use the locked vendored crates offline; Ruby dependency installation
needs RubyGems access initially. The root Gemfile.lock is intentionally local.

## Dedicated Linux container

The root Dockerfile supplies Ubuntu 24.04, the primary Ruby version, Rust 1.90.0,
libclang 18, development gems and the hash-locked release-note tools. Its upstream
Ruby and Rust image references are pinned by digest. It checks Ruby against the
CI policy rather than silently using a different cohort.

```sh
docker build -t thistle-development .
docker run --rm --init --network none --cpus 4 --memory 4g --pids-limit 256 \
  --cap-drop ALL --security-opt no-new-privileges thistle-development
docker run --rm --init --network none --cpus 4 --memory 4g --pids-limit 256 \
  --cap-drop ALL --security-opt no-new-privileges thistle-development \
  bundle exec rake installed
```

Build requires network access. Checks run as an unprivileged user with no network,
host mounts, forwarded credentials or Docker socket. `.dockerignore` allows only
project inputs and excludes native outputs, local gems, Git metadata and captures.
Rebuild after source edits; Docker reuses unchanged toolchain layers. This avoids
mixing macOS objects with Linux builds. Retain a named container and use `docker cp`
if you need its `pkg/install-check-*` reports before removing it. The disposable
container is development isolation, not an independent evaluator or release worker.

The image supports its published amd64/arm64 variants; execute checks on each
architecture before making a support claim. Emulation success is not a native
performance result. Update image pins with the CI policy and verify upstream
runtime/OS compatibility when updating Ruby or Rust.

## Install in a Ruby or Rails application

Build and install the core source gem; Map is optional. When using Map, install
the matching Map source gem: its gemspec requires an exact core version.
Nothing is published to a registry. Package versions are defined by their gemspecs.

```sh
mkdir -p pkg
gem build thistle.gemspec --output pkg/thistle-0.1.0.pre.3.gem
gem install pkg/thistle-0.1.0.pre.3.gem

# Optional Map views, paired with the core version above:
(cd map && gem build thistle-map.gemspec --output ../pkg/thistle-map-0.1.0.pre.3.gem)
gem install pkg/thistle-map-0.1.0.pre.3.gem
```

Run installation under the destination application's Ruby and native toolchain.
RubyGems may download missing runtime dependencies such as Rouge.
For an application managed by Bundler, copy the core artifact (and the matching
Map artifact, if used) to its `vendor/cache` using those canonical versioned
filenames, add `gem "thistle", "= 0.1.0.pre.3"` in its development group (and
optionally `gem "thistle-map", "= 0.1.0.pre.3"`), then run `bundle install` in that
application. Bundler compiles the extension for that application's environment.
The private publishing restriction remains in place. Do not copy a compiled
extension from another Ruby or container. The gem's Ruby requirement and an
application's Rails dependency resolution must both be satisfied.

Use `bundle exec thistle capture ./app --output ./.thistle` for static source, or
explicitly call `Thistle.capture(root: Rails.root.to_s, output: store, rails: Rails.application)`
inside a trusted, already booted Rails runner. Loaded application observations use
that process's authority; they are not an evaluation endpoint or automatic boot.
See the [Map mounting/access guide](https://github.com/lost-in-the/thistle/blob/main/map/README.md) before exposing its views.

## Paths and checks

Store paths reject symlinks at every ancestor, including macOS's `/tmp` and `/var`
aliases. Choose a physical path, such as `/private/tmp/my-store`, or obtain the
physical parent with `File.realpath(Dir.tmpdir)` before appending a new store name.
Do not resolve an arbitrary store symlink to bypass this protection. Rake's test
environment canonicalizes only the trusted temporary fixture root. If invoking
Cargo or test files directly, first set a physical `TMPDIR`:

```sh
export TMPDIR="$(ruby -rtmpdir -e 'puts File.realpath(Dir.tmpdir)')"
cargo test --locked --offline --manifest-path engine/Cargo.toml
```

`rake test` compiles the native bridge and runs Ruby contracts; `rake native` runs
Rust tests; `rake map` runs Map tests against the compiled core. `rake installed`
builds a new source-gem pair, installs the resolved cached dependencies into a
fresh temporary application bundle using `bundle install --local`, reuses the current core/parser/reader regressions and
the installed Map smoke, and exercises the installed CLI. Its worker is outside
the checkout, receives only build inputs, and is removed afterward. Package and
actually loaded native digests, compiler versions and both development/consumer
locks remain in
`pkg/install-check-*/report.json`; failed attempts leave no passing report. These
are candidate-owned development checks, not protected qualification. A missing
cached dependency is an explicit failure; use `bundle cache` to populate it.

Linux parser/reader subprocess tests enforce a 2 GiB address-space ceiling plus
CPU and wall deadlines. macOS rejects `RLIMIT_AS`; those tests retain CPU/wall
deadlines but do not claim a process memory ceiling. The Docker command supplies
a whole-container memory limit. Broader hostile-parser and crash-durability
qualification remains separate; passing tests does not establish power-loss recovery.

Ordinary product PRs require primary-cohort source/installed checks on Apple
Silicon macOS (`macos-15`), alongside the existing selected Linux cohorts. Main
pushes, explicit full/manual CI and merge groups select both Apple Silicon and
Intel (`macos-15-intel`). Docs-only PRs intentionally skip product/platform work;
docs-only main pushes still select both architectures. Missing, failed, cancelled
or unexpectedly skipped selected macOS work fails the aggregate required check.
Historical Linux candidate/evaluator artifacts keep their existing formats and
scope; new platform receipts do not relabel them.
