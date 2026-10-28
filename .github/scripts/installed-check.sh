#!/usr/bin/env bash
# Candidate-owned orchestration of the existing frozen evaluator.
# No package rebuild: every cohort installs the same downloaded source-gem bytes.
set -euo pipefail

: "${EXPECTED_SHA:?}"
: "${SOURCE_DIR:?}"
: "${ARTIFACT_DIR:?}"
: "${EVIDENCE_DIR:?}"
: "${LIBCLANG_PATH:?}"

[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{40}$ ]] || exit 1
[[ "$(git -C "$SOURCE_DIR" rev-parse HEAD)" == "$EXPECTED_SHA" ]]
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$script_dir/pipeline.py" verify --artifacts "$ARTIFACT_DIR" --expected-sha "$EXPECTED_SHA"
mkdir -p "$SOURCE_DIR/pkg/hardened-baseline" "$EVIDENCE_DIR"
cp "$ARTIFACT_DIR/thistle.gem" "$SOURCE_DIR/pkg/hardened-baseline/thistle.gem"
cp "$ARTIFACT_DIR/thistle-map.gem" "$SOURCE_DIR/pkg/hardened-baseline/thistle-map.gem"

# This reuses the baseline/experiment evaluator and policy; it does not create
# another version of their checks. Changing them requires a separate policy review.
bootstrap_sha=317671367949111861a63d0c3635dec94533fc8e
bundle_sha=7d24cf43a1ca1c57456d2a009e70bec8cfea10895aff5f981c92ab448e6acb2d
evaluator_sha=b81f5adc2c647083b6ce8688234012c6d2da0ee4
git -C "$SOURCE_DIR" show "$bootstrap_sha:thistle-eval.git.bundle" > "$EVIDENCE_DIR/evaluator.git.bundle"
printf '%s  %s\n' "$bundle_sha" "$EVIDENCE_DIR/evaluator.git.bundle" | sha256sum --check --status
git clone --quiet "$EVIDENCE_DIR/evaluator.git.bundle" "$EVIDENCE_DIR/evaluator"
[[ "$(git -C "$EVIDENCE_DIR/evaluator" rev-parse HEAD)" == "$evaluator_sha" ]]

(cd "$SOURCE_DIR" && BUNDLE_CACHE_ALL=true bundle cache)
cp "$SOURCE_DIR/Gemfile.lock" "$EVIDENCE_DIR/cohort-Gemfile.lock"
python3 "$SOURCE_DIR/tools/qualify_baseline.py" \
  --source "$SOURCE_DIR" \
  --evaluator "$EVIDENCE_DIR/evaluator" \
  --output "$EVIDENCE_DIR/installed" \
  --ruby "$(command -v ruby)" \
  --toolchain "$HOME/.rustup/toolchains/1.90.0-x86_64-unknown-linux-gnu/bin" \
  --dependencies "$SOURCE_DIR/vendor/cache" \
  --libclang "$LIBCLANG_PATH"

cmp "$ARTIFACT_DIR/thistle.gem" "$SOURCE_DIR/pkg/hardened-baseline/thistle.gem"
cmp "$ARTIFACT_DIR/thistle-map.gem" "$SOURCE_DIR/pkg/hardened-baseline/thistle-map.gem"
python3 "$script_dir/pipeline.py" verify --artifacts "$ARTIFACT_DIR" --expected-sha "$EXPECTED_SHA"
git -C "$SOURCE_DIR" diff --quiet --exit-code HEAD --
