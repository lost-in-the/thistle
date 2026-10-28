#!/usr/bin/env python3
"""Candidate-owned CI routing and artifact accounting; never release authority."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

SCHEMA = 1
SHA = re.compile(r"^[0-9a-f]{40}$")
CORE_FILES = (
    "engine/Cargo.toml", "engine/Cargo.lock", "thistle.gemspec",
    "lib/thistle.rb", "ext/thistle_native/extconf.rb",
    "rust-toolchain.toml", ".cargo/config.toml", "Gemfile", "Rakefile",
)
MAP_FILES = ("map/thistle-map.gemspec", "map/lib/thistle/map.rb")
PACKAGE_FILES = ("README.md", "LICENSE", "THIRD_PARTY.md")
CORE_ROOTS = ("engine/", "lib/", "ext/", "exe/", "test/", ".cargo/")


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def sha256(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def exists_at(root, revision, name):
    return subprocess.run(
        ["git", "-C", str(root), "cat-file", "-e", f"{revision}:{name}"],
        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    ).returncode == 0


def parse_changed_paths(raw):
    """Parse --name-status -z, keeping BOTH names of a rename/copy."""
    tokens = raw.decode("utf-8", errors="surrogateescape").split("\0")
    if tokens and tokens[-1] == "":
        tokens.pop()
    paths, cursor = [], 0
    while cursor < len(tokens):
        status = tokens[cursor]
        cursor += 1
        if not re.fullmatch(r"[ACDMRTUXB](?:[0-9]+)?", status):
            raise ValueError("Unrecognized git diff status")
        count = 2 if status[0] in "RC" else 1
        if cursor + count > len(tokens):
            raise ValueError("Truncated git diff record")
        paths.extend(tokens[cursor:cursor + count])
        cursor += count
    return sorted(set(paths))


def doc_only(path):
    suffix = PurePosixPath(path).suffix.lower()
    # A script or fixture under docs is still executable/input work.
    return suffix in (".md", ".rst", ".txt") and (
        "/" not in path or path.startswith(("docs/", "map/docs/"))
    )


def planning_only(path):
    return path in (".github/PULL_REQUEST_TEMPLATE.md", ".github/pull_request_template.md") or (
        path.startswith(".github/ISSUE_TEMPLATE/") and PurePosixPath(path).suffix in (".yml", ".yaml")
    )


def classify(paths, present, base_present=False, force=False, base_map_present=False):
    present = set(present)
    have_core = set(CORE_FILES) <= present
    some_core = bool(set(CORE_FILES) & present)
    have_map = set(MAP_FILES) <= present
    some_map = bool(set(MAP_FILES) & present)
    if some_core and not have_core:
        raise ValueError("Partial core tree: import or restore every required source/build file")
    if some_map and not have_map:
        raise ValueError("Partial Map tree: source and gem specification must coexist")
    if some_map and not have_core:
        raise ValueError("Map integration requires the native core source")
    if base_present and not have_core:
        raise ValueError("Source deletion cannot turn a product checkout into bootstrap mode")
    if base_map_present and not have_map:
        raise ValueError("Map deletion cannot turn its product lane into a skipped check")
    if have_core and not set(PACKAGE_FILES) <= present:
        raise ValueError("Required source-gem package metadata is missing")
    product_paths = tuple(CORE_ROOTS) + ("map/", "Gemfile", "Rakefile", "thistle.gemspec", "rust-toolchain.toml")
    if not have_core and any(p.startswith(product_paths) for p in paths):
        raise ValueError("Product paths changed but the source tree is absent")
    core = have_core and force
    map_check = have_map and force
    reasons = []
    for path in paths:
        if doc_only(path) or planning_only(path):
            continue
        if path.startswith("map/"):
            map_check = have_map
            reasons.append("map")
        else:
            # Workflow, test, dependency, packaging and unknown paths fail closed
            # to the complete applicable product lane after source restoration.
            core = have_core
            map_check = have_map
            reasons.append("core-or-control")
    return {
        "schema": SCHEMA,
        "mode": "source" if have_core else "bootstrap",
        "core": bool(core),
        "map": bool(map_check),
        "product": bool(core or map_check),
        "paths": paths,
        "reasons": sorted(set(reasons)),
        "qualification": "not_established_by_candidate_ci",
    }


def event_base(root, event_name, event):
    if event_name == "pull_request":
        base = event.get("pull_request", {}).get("base", {}).get("sha", "")
    elif event_name == "merge_group":
        base = event.get("merge_group", {}).get("base_sha", "")
    elif event_name == "push":
        base = event.get("before", "")
    elif event_name in ("workflow_dispatch", "schedule"):
        return None
    else:
        raise ValueError("Unsupported event; do not infer a partial check set")
    if base == "0" * 40:
        return None
    if not SHA.fullmatch(base):
        raise ValueError("Missing or invalid base commit")
    git(root, "rev-parse", "--verify", f"{base}^{{commit}}")
    return base


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def plan(args):
    root = args.source.resolve()
    event = json.loads(args.event.read_text())
    event_name = os.environ.get("GITHUB_EVENT_NAME", args.event_name or "")
    base = event_base(root, event_name, event)
    head = git(root, "rev-parse", "HEAD").decode().strip()
    if not SHA.fullmatch(head):
        raise ValueError("Unsupported source identity")
    if base:
        paths = parse_changed_paths(git(root, "diff", "--name-status", "-z", "--find-renames", base, head))
    else:
        paths = git(root, "ls-files", "-z").decode("utf-8", "surrogateescape").rstrip("\0").split("\0")
    present = {name for name in CORE_FILES + MAP_FILES + PACKAGE_FILES if (root / name).is_file()}
    # Checking ALL markers in the base catches complete source-tree removal.
    base_present = bool(base and any(exists_at(root, base, name) for name in CORE_FILES))
    base_map_present = bool(base and any(exists_at(root, base, name) for name in MAP_FILES))
    full = args.full or event_name in ("workflow_dispatch", "schedule", "merge_group", "push")
    result = classify(paths, present, base_present, force=full, base_map_present=base_map_present)
    result.update({"source_sha": head, "base_sha": base, "event": event_name})
    write_json(args.output, result)
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            for name in ("mode", "source_sha", "core", "map", "product"):
                value = result[name]
                output.write(f"{name}={str(value).lower() if isinstance(value, bool) else value}\n")
    print(json.dumps(result, indent=2))


def required_results(needs):
    errors = []
    for name in ("plan", "metadata"):
        if needs.get(name, {}).get("result") != "success":
            errors.append(f"{name} must succeed")
    outputs = needs.get("plan", {}).get("outputs", {})
    selected = outputs.get("product")
    mode = outputs.get("mode")
    if selected not in ("true", "false") or mode not in ("bootstrap", "source"):
        errors.append("Planner outputs missing or invalid")
    if selected == "true" and needs.get("product", {}).get("result") != "success":
        errors.append("Selected product lane must succeed; skipped/cancelled is not a pass")
    if selected == "false" and needs.get("product", {}).get("result") not in ("skipped", "success"):
        errors.append("Unexpected product failure")
    if mode == "bootstrap" and selected != "false":
        errors.append("Bootstrap cannot claim a product check")
    return errors


def required(args):
    needs = json.loads(os.environ.get("THISTLE_NEEDS", "{}"))
    errors = required_results(needs)
    mode = needs.get("plan", {}).get("outputs", {}).get("mode", "unknown")
    product = needs.get("plan", {}).get("outputs", {}).get("product", "unknown")
    summary = (
        f"## CI result\n\nMode: **{mode}**. Product lane selected: **{product}**.\n\n"
        "This check reports candidate-owned development feedback. "
        "Bootstrap/metadata success is not native-product, installed-artifact, "
        "independent-evaluator, benchmark, or release qualification.\n"
    )
    if errors:
        summary += "\n" + "\n".join(f"- {message}" for message in errors) + "\n"
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as output:
            output.write(summary)
    print(summary)
    if errors:
        raise ValueError("Required CI failed")


def safe_file(root, relative):
    if not isinstance(relative, str) or not relative or "\\" in relative:
        raise ValueError("Invalid artifact path")
    parts = PurePosixPath(relative)
    if parts.is_absolute() or any(part in (".", "..") for part in parts.parts):
        raise ValueError("Artifact path must be a normalized relative path")
    if any(part.startswith(".") for part in parts.parts):
        raise ValueError("Hidden artifact paths are not included by the uploader")
    if str(parts) != relative:
        raise ValueError("Artifact path must be canonical")
    current = root
    for part in parts.parts:
        current = current / part
        if current.is_symlink():
            raise ValueError("Artifact symlinks are forbidden")
    if not current.is_file():
        raise ValueError("Artifact file missing")
    if current.stat().st_size > 200 * 1024 * 1024:
        raise ValueError("Artifact exceeds the bounded manifest input size")
    return current


def command_version(command):
    return subprocess.check_output(command, text=True, stderr=subprocess.STDOUT).strip()


def create_manifest(root, directory, expected_sha, observations=None):
    if not SHA.fullmatch(expected_sha):
        raise ValueError("Expected source must be a full lowercase SHA")
    actual = git(root, "rev-parse", "HEAD").decode().strip()
    if actual != expected_sha:
        raise ValueError("Checked-out source does not match expected source")
    git(root, "diff", "--quiet", "--exit-code", "HEAD", "--")
    files = []
    for item in sorted(directory.rglob("*")):
        if item.is_symlink():
            raise ValueError("Artifact symlinks are forbidden")
        if item.is_file() and item != directory / "manifest.json":
            relative = item.relative_to(directory).as_posix()
            path = safe_file(directory, relative)
            files.append({"path": relative, "bytes": path.stat().st_size, "sha256": sha256(path)})
    names = {record["path"] for record in files}
    if not {"thistle.gem", "Gemfile.lock", "build-observation/thistle_native.so"} <= names:
        raise ValueError("Core package, resolved dependencies and native build observation are required")
    if (root / "map/thistle-map.gemspec").is_file() and "thistle-map.gem" not in names:
        raise ValueError("Map package missing for this source")
    return {
        "schema": SCHEMA,
        "source_sha": actual,
        "source_tree": git(root, "rev-parse", "HEAD^{tree}").decode().strip(),
        "workflow_definition_sha": os.environ.get("THISTLE_WORKFLOW_SHA"),
        "run_id": os.environ.get("GITHUB_RUN_ID"),
        "run_attempt": os.environ.get("GITHUB_RUN_ATTEMPT"),
        "workflow": os.environ.get("GITHUB_WORKFLOW"),
        "event": os.environ.get("GITHUB_EVENT_NAME"),
        "scope": "candidate_owned_development",
        "external_qualification": "not_attached",
        "publication_authorized": False,
        "native_scope": "checkout_build_observation_not_installed_source_gem_identity",
        "installed_loaded_native_sha256": None,
        "reproducible_package_bytes": "not_claimed",
        "map_package_required": (root / "map/thistle-map.gemspec").is_file(),
        "build_observations": observations or {},
        "files": files,
    }


def verify_manifest(directory, manifest, expected_sha):
    if not isinstance(manifest, dict):
        raise ValueError("Manifest must be an object")
    if not SHA.fullmatch(expected_sha) or manifest.get("source_sha") != expected_sha:
        raise ValueError("Candidate source identity mismatch")
    if manifest.get("schema") != SCHEMA or manifest.get("scope") != "candidate_owned_development":
        raise ValueError("Unsupported manifest scope")
    if manifest.get("publication_authorized") is not False:
        raise ValueError("This verifier never authorizes publication")
    if (manifest.get("external_qualification") != "not_attached"
        or manifest.get("native_scope") != "checkout_build_observation_not_installed_source_gem_identity"
        or manifest.get("installed_loaded_native_sha256") is not None
        or manifest.get("reproducible_package_bytes") != "not_claimed"):
        raise ValueError("Candidate manifest cannot claim external or installed-native authority")
    if type(manifest.get("map_package_required")) is not bool:
        raise ValueError("Map package requirement must be explicit")
    records = manifest.get("files")
    if not isinstance(records, list) or not records:
        raise ValueError("Missing artifact records")
    seen = set()
    for record in records:
        if not isinstance(record, dict) or set(record) != {"path", "bytes", "sha256"}:
            raise ValueError("Invalid artifact record")
        name = record["path"]
        if not isinstance(name, str):
            raise ValueError("Artifact path must be text")
        if name in seen:
            raise ValueError("Duplicate artifact path")
        seen.add(name)
        path = safe_file(directory, name)
        if type(record["bytes"]) is not int or record["bytes"] != path.stat().st_size:
            raise ValueError("Artifact length mismatch")
        if not re.fullmatch(r"[0-9a-f]{64}", str(record["sha256"])) or sha256(path) != record["sha256"]:
            raise ValueError("Artifact digest mismatch")
    actual = set()
    for path in directory.rglob("*"):
        if path.is_symlink():
            raise ValueError("Artifact symlinks are forbidden")
        if path.is_file() and path != directory / "manifest.json":
            actual.add(path.relative_to(directory).as_posix())
    if seen != actual:
        raise ValueError("Missing or unlisted artifact files")
    if not {"thistle.gem", "Gemfile.lock", "build-observation/thistle_native.so"} <= seen:
        raise ValueError("Required candidate artifact files absent")
    if manifest["map_package_required"] and "thistle-map.gem" not in seen:
        raise ValueError("Required Map package absent")
    return True


def manifest_command(args):
    root, directory = args.source.resolve(), args.artifacts.resolve()
    observations = {
        "ruby": command_version(["ruby", "--version"]),
        "cargo": command_version(["cargo", "--version"]),
        "rustc": command_version(["rustc", "--version", "--verbose"]),
        "cc": command_version(["cc", "--version"]),
        "rails_requirement": os.environ.get("THISTLE_RAILS_VERSION"),
        "libclang_path": os.environ.get("LIBCLANG_PATH"),
        "cargo_lock_sha256": sha256(root / "engine/Cargo.lock"),
        "toolchain_file_sha256": sha256(root / "rust-toolchain.toml"),
    }
    result = create_manifest(root, directory, args.expected_sha, observations)
    write_json(directory / "manifest.json", result)
    verify_manifest(directory, result, args.expected_sha)
    print(json.dumps(result, indent=2))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    p = commands.add_parser("plan")
    p.add_argument("--source", type=Path, default=Path("."))
    p.add_argument("--event", type=Path, default=Path(os.environ.get("GITHUB_EVENT_PATH", "event.json")))
    p.add_argument("--event-name")
    p.add_argument("--full", action="store_true")
    p.add_argument("--output", type=Path, default=Path("ci-plan.json"))
    p.set_defaults(function=plan)
    p = commands.add_parser("required")
    p.set_defaults(function=required)
    p = commands.add_parser("manifest")
    p.add_argument("--source", type=Path, default=Path("."))
    p.add_argument("--artifacts", type=Path, required=True)
    p.add_argument("--expected-sha", required=True)
    p.set_defaults(function=manifest_command)
    p = commands.add_parser("verify")
    p.add_argument("--artifacts", type=Path, required=True)
    p.add_argument("--expected-sha", required=True)
    p.set_defaults(function=lambda a: verify_manifest(
        a.artifacts.resolve(), json.loads((a.artifacts / "manifest.json").read_text()), a.expected_sha
    ))
    args = parser.parse_args()
    try:
        args.function(args)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        print(f"Thistle pipeline refused: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
