"""Small regression suite for expensive CI omissions and artifact trust mistakes."""
import argparse
import contextlib
import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("pipeline", ROOT / ".github/scripts/pipeline.py")
pipeline = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(pipeline)
SOURCE_FILES = set(pipeline.CORE_FILES + pipeline.PACKAGE_FILES)
ALL_FILES = SOURCE_FILES | set(pipeline.MAP_FILES + pipeline.MAP_PACKAGE_FILES)
POLICY = pipeline.load_policy(ROOT / pipeline.POLICY_PATH)


class RoutingTests(unittest.TestCase):
    def test_bootstrap_is_explicit_and_never_claims_product(self):
        result = pipeline.classify(["README.md", ".github/workflows/ci.yml"], {"README.md"})
        self.assertEqual(result["mode"], "bootstrap")
        self.assertFalse(result["product"])
        self.assertEqual(result["qualification"], "not_established_by_candidate_ci")

    def test_source_import_and_control_changes_run_all_applicable_checks(self):
        for changed in [["engine/Cargo.toml"], [".github/scripts/pipeline.py"], ["new-input.json"]]:
            with self.subTest(changed=changed):
                result = pipeline.classify(changed, ALL_FILES)
                self.assertTrue(result["core"] and result["map"] and result["product"])

    def test_map_only_runs_map_with_native_dependency_build(self):
        result = pipeline.classify(["map/lib/thistle/map.rb"], ALL_FILES)
        self.assertFalse(result["core"])
        self.assertTrue(result["map"])

    def test_docs_only_skips_product_but_executable_docs_do_not(self):
        self.assertFalse(pipeline.classify(["docs/guide.md", "README.md", "changelog/26.fixed.md"], ALL_FILES)["product"])
        self.assertTrue(pipeline.classify(["docs/probe.py"], ALL_FILES)["product"])
        self.assertTrue(pipeline.classify(["changelog/check.py"], ALL_FILES)["product"])

    def test_main_full_mode_runs_all_checks_even_for_docs(self):
        result = pipeline.classify(["docs/guide.md"], ALL_FILES, force=True)
        self.assertTrue(result["core"] and result["map"])

    def test_planning_forms_skip_product_but_workflow_and_unknown_controls_do_not(self):
        for path in [
            ".github/ISSUE_TEMPLATE/01-work.yml", ".github/PULL_REQUEST_TEMPLATE.md",
            "towncrier.toml", ".github/requirements-notes.txt",
            ".github/scripts/check-notes.py", "tests/automation/test_notes.py",
            "map/changelog/26.fixed.md", "map/CHANGELOG.md",
        ]:
            with self.subTest(path=path):
                self.assertFalse(pipeline.classify([path], ALL_FILES)["product"])
        for path in [".github/workflows/ci.yml", ".github/ISSUE_TEMPLATE/new-code.py"]:
            with self.subTest(path=path):
                self.assertTrue(pipeline.classify([path], ALL_FILES)["product"])

    def test_partial_or_removed_source_is_not_bootstrap(self):
        for present, keywords in [
            ({"engine/Cargo.toml"}, {}),
            (set(), {"base_present": True}),
            (set(pipeline.MAP_FILES), {}),
            (SOURCE_FILES | {pipeline.MAP_FILES[0]}, {}),
            (SOURCE_FILES, {"base_map_present": True}),
        ]:
            with self.subTest(present=present):
                with self.assertRaises(ValueError):
                    pipeline.classify(["README.md"], present, **keywords)

    def test_required_package_document_deletion_fails_closed(self):
        for name in pipeline.PACKAGE_FILES + pipeline.MAP_PACKAGE_FILES:
            with self.subTest(name=name), self.assertRaises(ValueError):
                pipeline.classify([name], ALL_FILES - {name})

    def test_map_notes_do_not_turn_a_bootstrap_checkout_into_partial_map(self):
        result = pipeline.classify(["map/CHANGELOG.md", "map/changelog/26.added.md"], {"map/CHANGELOG.md"})
        self.assertEqual(result["mode"], "bootstrap")
        self.assertFalse(result["product"])

    def test_rename_parser_preserves_old_and_new_paths(self):
        parsed = pipeline.parse_changed_paths(b"R100\0engine/src/store.rs\0docs/store.md\0M\0README.md\0")
        self.assertEqual(parsed, ["README.md", "docs/store.md", "engine/src/store.rs"])
        self.assertTrue(pipeline.classify(parsed, ALL_FILES)["core"])

    def test_malformed_diff_cannot_choose_a_partial_lane(self):
        for raw in [b"R100\0old\0", b"unknown\0path\0", b"M\0"]:
            with self.subTest(raw=raw), self.assertRaises(ValueError):
                pipeline.parse_changed_paths(raw)


class GitFixture(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / "source"
        self.root.mkdir()
        self.git("init", "-q")
        self.git("config", "user.name", "Automation test")
        self.git("config", "user.email", "automation@example.invalid")
        self.write(pipeline.POLICY_PATH, json.dumps(POLICY))

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.root), *args], stderr=subprocess.PIPE).decode().strip()

    def write(self, name, contents=None):
        file = self.root / name
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(contents or name + "\n")

    def commit(self):
        self.git("add", "-A")
        self.git("commit", "-qm", "fixture")
        return self.git("rev-parse", "HEAD")

    def source_commit(self):
        for name in ALL_FILES:
            self.write(name)
        self.write("engine/src/store.rs", "independent rename fixture\n" * 5)
        return self.commit()

    def route(self, base, event_name="pull_request", lane="ci"):
        event = Path(self.temp.name) / "event.json"
        event.write_text(json.dumps({"pull_request": {"base": {"sha": base}}, "before": base}))
        output = Path(self.temp.name) / "plan.json"
        args = argparse.Namespace(source=self.root, event=event, event_name=event_name, full=False, output=output, lane=lane)
        with patch.dict(os.environ, {"GITHUB_EVENT_NAME": event_name}, clear=True), contextlib.redirect_stdout(io.StringIO()):
            pipeline.plan(args)
        return json.loads(output.read_text())


class GitPlanTests(GitFixture):
    def test_pure_rust_pr_uses_primary_and_manual_runs_both(self):
        base = self.source_commit()
        self.write("engine/src/store.rs", "changed\n")
        self.commit()
        self.assertEqual(self.route(base)["matrix"], pipeline.cohort_matrix(POLICY, ["primary"], True))
        manual = self.route(base, "workflow_dispatch")
        self.assertTrue(manual["minimum_required"])
        self.assertEqual(manual["matrix"], pipeline.cohort_matrix(POLICY, ["primary", "minimum"], True))

    def test_native_boundary_rename_in_either_direction_selects_minimum(self):
        base = self.source_commit()
        self.git("mv", "engine/src/store.rs", "engine/src/lib.rs")
        middle = self.commit()
        self.assertTrue(self.route(base)["minimum_required"])
        self.git("mv", "engine/src/lib.rs", "engine/src/store.rs")
        self.commit()
        self.assertTrue(self.route(middle)["minimum_required"])

    def test_main_and_compatibility_partition_cohorts_without_repeating_primary(self):
        base = self.source_commit()
        self.write("Gemfile", "dependency change\n")
        self.commit()
        primary = self.route(base, "push")
        minimum = self.route(base, "push", "compatibility")
        self.assertEqual([r["cohort"] for r in primary["matrix"]["include"]], ["primary"])
        self.assertEqual([r["cohort"] for r in minimum["matrix"]["include"]], ["minimum"])
        self.assertFalse(minimum["matrix"]["include"][0]["package"])
        for event in ("schedule", "workflow_dispatch"):
            result = self.route(base, event, "compatibility")
            self.assertEqual(result["matrix"], pipeline.cohort_matrix(POLICY, ["primary", "minimum"]))

    def test_missing_policy_fails_even_for_a_docs_only_change(self):
        base = self.source_commit()
        (self.root / pipeline.POLICY_PATH).unlink()
        self.write("README.md", "changed\n")
        self.commit()
        with self.assertRaises(FileNotFoundError):
            self.route(base)

    def test_actual_rename_out_of_engine_still_routes_core(self):
        base = self.source_commit()
        (self.root / "docs").mkdir()
        self.git("mv", "engine/src/store.rs", "docs/store.md")
        head = self.commit()
        result = self.route(base)
        self.assertEqual(result["source_sha"], head)
        self.assertEqual(result["base_sha"], base)
        self.assertTrue(result["core"])
        self.assertIn("engine/src/store.rs", result["paths"])

    def test_complete_map_rename_cannot_skip_map(self):
        base = self.source_commit()
        self.git("mv", "map", "old-map")
        self.commit()
        with self.assertRaisesRegex(ValueError, "Map deletion"):
            self.route(base)

    def test_complete_core_deletion_cannot_reenter_bootstrap(self):
        base = self.source_commit()
        for name in pipeline.CORE_FILES + pipeline.MAP_FILES:
            (self.root / name).unlink()
        self.commit()
        with self.assertRaisesRegex(ValueError, "Source deletion"):
            self.route(base)

    def test_packaged_document_rename_cannot_hide_in_docs(self):
        base = self.source_commit()
        self.git("mv", "THIRD_PARTY.md", "old-license.md")
        self.commit()
        with self.assertRaisesRegex(ValueError, "package metadata"):
            self.route(base)

    def test_push_docs_runs_full_while_pull_request_docs_skips(self):
        base = self.source_commit()
        self.write("README.md", "changed\n")
        self.commit()
        self.assertFalse(self.route(base)["product"])
        self.assertTrue(self.route(base, "push")["product"])


class RequiredTests(unittest.TestCase):
    def needs(self, result="success", selected="true", mode="source", minimum=True):
        return {
            "plan": {"result": "success", "outputs": {
                "mode": mode, "product": selected, "minimum_required": str(minimum).lower(),
                "matrix": json.dumps(pipeline.cohort_matrix(POLICY, ["primary", "minimum"] if minimum else ["primary"], True)),
            }},
            "metadata": {"result": "success"},
            "product": {"result": result},
        }

    def test_selected_product_requires_success(self):
        self.assertEqual(pipeline.required_results(self.needs()), [])
        self.assertEqual(pipeline.required_results(self.needs(minimum=False)), [])
        for result in ["skipped", "cancelled", "failure", None]:
            with self.subTest(result=result):
                self.assertTrue(pipeline.required_results(self.needs(result=result)))

    def test_missing_or_duplicate_minimum_and_extra_package_builds_fail(self):
        for roles in (["primary"], ["primary", "primary"], ["minimum", "primary"], []):
            needs = self.needs()
            needs["plan"]["outputs"]["matrix"] = json.dumps(pipeline.cohort_matrix(POLICY, roles, True))
            self.assertTrue(pipeline.required_results(needs))
        needs = self.needs()
        rows = pipeline.cohort_matrix(POLICY, ["primary", "minimum"], True)
        rows["include"][1]["package"] = True
        needs["plan"]["outputs"]["matrix"] = json.dumps(rows)
        self.assertTrue(pipeline.required_results(needs))
        del needs["plan"]["outputs"]["matrix"]
        self.assertTrue(pipeline.required_results(needs))

    def test_missing_or_skipped_planner_metadata_fails(self):
        for name in ["plan", "metadata"]:
            for result in ["skipped", "cancelled", "failure"]:
                needs = self.needs()
                needs[name]["result"] = result
                self.assertTrue(pipeline.required_results(needs))
        self.assertTrue(pipeline.required_results({}))

    def test_bootstrap_cannot_claim_product_and_malformed_outputs_fail(self):
        self.assertEqual(pipeline.required_results(self.needs("skipped", "false", "bootstrap")), [])
        self.assertTrue(pipeline.required_results(self.needs(mode="bootstrap")))
        self.assertTrue(pipeline.required_results(self.needs(selected="maybe")))
        self.assertTrue(pipeline.required_results(self.needs(mode="unknown")))
        self.assertTrue(pipeline.required_results(self.needs("failure", "false")))


class CohortPolicyTests(unittest.TestCase):
    def test_boundary_dependencies_and_controls_select_minimum(self):
        for path in [
            pipeline.POLICY_PATH, "Gemfile", "Gemfile.lock", "thistle.gemspec", "map/thistle-map.gemspec",
            "engine/Cargo.lock", "engine/build.rs", "engine/src/lib.rs", ".cargo/config.toml",
            "rust-toolchain.toml", "ext/thistle_native/thistle_native.c", "lib/thistle.rb",
            "map/lib/thistle/map.rb", ".github/scripts/pipeline.py", ".github/workflows/ci.yml",
            "tests/automation/test_pipeline.py", "new-boundary.json",
        ]:
            with self.subTest(path=path):
                self.assertTrue(pipeline.needs_minimum([path]))
        self.assertFalse(pipeline.needs_minimum(["engine/src/store.rs", "changelog/26.build.md", "README.md"]))

    def test_policy_refuses_floating_versions_invalid_shape_and_inverted_floor(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "policy.json"
            cases = [[], {**POLICY, "extra": True}, {**POLICY, "schema": True}]
            for field, value in [("ruby", "4.0"), ("ruby", "4.1.0-preview1"), ("ruby", 4.0), ("rails", "~> 8.1"), ("rails", "= 8.1.4\nmalicious")]:
                changed = copy.deepcopy(POLICY)
                changed["primary"][field] = value
                cases.append(changed)
            changed = copy.deepcopy(POLICY)
            changed["minimum"]["ruby"] = POLICY["primary"]["ruby"]
            cases.append(changed)
            for value in cases:
                path.write_text(json.dumps(value))
                with self.subTest(value=value), self.assertRaises(ValueError):
                    pipeline.load_policy(path)

    def test_release_policy_emits_both_cohorts_without_package_rebuild_rows(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "output"
            with patch.dict(os.environ, {"GITHUB_OUTPUT": str(output)}, clear=True), contextlib.redirect_stdout(io.StringIO()):
                pipeline.release_policy(argparse.Namespace(source=ROOT))
            values = dict(line.split("=", 1) for line in output.read_text().splitlines())
            self.assertEqual(json.loads(values["primary"]), POLICY["primary"])
            self.assertEqual(json.loads(values["matrix"]), pipeline.cohort_matrix(POLICY, ["primary", "minimum"]))


class ManifestTests(GitFixture):
    def setUp(self):
        super().setUp()
        self.write("README.md")
        self.write("map/thistle-map.gemspec")
        self.head = self.commit()
        self.artifacts = Path(self.temp.name) / "artifact"
        self.artifacts.mkdir()
        for name in ["thistle.gem", "thistle-map.gem", "Gemfile.lock", "build-observation/thistle_native.so"]:
            target = self.artifacts / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(("fixture-" + name).encode())
        self.manifest = pipeline.create_manifest(self.root, self.artifacts, self.head)

    def verify(self, manifest=None):
        return pipeline.verify_manifest(self.artifacts, manifest or self.manifest, self.head)

    def test_exact_bytes_and_checkout_identity_round_trip(self):
        self.assertTrue(self.verify())
        self.assertEqual(self.manifest["source_tree"], self.git("rev-parse", "HEAD^{tree}"))
        self.assertIsNone(self.manifest["installed_loaded_native_sha256"])
        self.assertFalse(self.manifest["publication_authorized"])

    def test_wrong_source_and_dirty_source_are_rejected(self):
        with self.assertRaises(ValueError):
            pipeline.create_manifest(self.root, self.artifacts, "0" * 40)
        with self.assertRaises(ValueError):
            pipeline.verify_manifest(self.artifacts, self.manifest, "0" * 40)
        self.write("README.md", "uncommitted change\n")
        with self.assertRaises(subprocess.CalledProcessError):
            pipeline.create_manifest(self.root, self.artifacts, self.head)

    def test_changed_deleted_or_added_artifact_fails(self):
        target = self.artifacts / "thistle.gem"
        original = target.read_bytes()
        target.write_bytes(b"x" * len(original))
        with self.assertRaisesRegex(ValueError, "digest"):
            self.verify()
        target.unlink()
        with self.assertRaises(ValueError):
            self.verify()
        target.write_bytes(original)
        (self.artifacts / "unlisted.txt").write_text("extra")
        with self.assertRaisesRegex(ValueError, "unlisted"):
            self.verify()

    def test_nested_manifest_is_hashed_and_never_silently_excluded(self):
        nested = self.artifacts / "build-observation/manifest.json"
        nested.write_text("{}")
        with self.assertRaisesRegex(ValueError, "unlisted"):
            self.verify()
        manifest = pipeline.create_manifest(self.root, self.artifacts, self.head)
        self.assertIn("build-observation/manifest.json", [x["path"] for x in manifest["files"]])
        self.assertTrue(self.verify(manifest))

    def test_traversal_hidden_absolute_and_symlink_paths_fail(self):
        for name in ["../escape", "/etc/passwd", ".secret", "sub/.hidden", "sub/../escape", "sub//file", "sub\\file"]:
            with self.subTest(name=name), self.assertRaises(ValueError):
                pipeline.safe_file(self.artifacts, name)
        (self.artifacts / "linked").symlink_to(self.root / "README.md")
        with self.assertRaisesRegex(ValueError, "symlink"):
            pipeline.create_manifest(self.root, self.artifacts, self.head)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.verify()

    def test_duplicate_paths_invalid_record_types_and_missing_map_fail(self):
        duplicate = copy.deepcopy(self.manifest)
        duplicate["files"].append(duplicate["files"][0])
        with self.assertRaisesRegex(ValueError, "Duplicate"):
            self.verify(duplicate)
        for name, value in [("path", []), ("bytes", True), ("sha256", "bad")]:
            changed = copy.deepcopy(self.manifest)
            changed["files"][0][name] = value
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.verify(changed)
        (self.artifacts / "thistle-map.gem").unlink()
        changed = copy.deepcopy(self.manifest)
        changed["files"] = [x for x in changed["files"] if x["path"] != "thistle-map.gem"]
        with self.assertRaisesRegex(ValueError, "Map"):
            self.verify(changed)

    def test_candidate_cannot_claim_release_or_installed_native_authority(self):
        for name, value in [
            ("publication_authorized", True),
            ("external_qualification", "passed"),
            ("installed_loaded_native_sha256", "a" * 64),
            ("native_scope", "installed"),
            ("reproducible_package_bytes", "proven"),
        ]:
            changed = copy.deepcopy(self.manifest)
            changed[name] = value
            with self.subTest(name=name), self.assertRaises(ValueError):
                self.verify(changed)


class WorkflowBoundaryTests(unittest.TestCase):
    def test_external_actions_have_reviewed_full_sha_pins(self):
        pins = json.loads((ROOT / ".github/scripts/action-pins.json").read_text())["actions"]
        for path in (ROOT / ".github/workflows").glob("*.yml"):
            name, workflow = path.name, path.read_text()
            for use in re.findall(r"^\s*(?:-\s*)?uses:\s*(\S+)", workflow, re.M):
                if use.startswith("./"):
                    continue
                action, separator, revision = use.partition("@")
                with self.subTest(workflow=name, action=action):
                    self.assertEqual(separator, "@")
                    self.assertRegex(revision, r"^[0-9a-f]{40}$")
                    self.assertEqual(pins[action]["sha"], revision)
                    self.assertEqual(pins[action]["runtime"], "node24")
                    self.assertEqual(pins[action]["metadata"], f"https://github.com/{action}/blob/{revision}/action.yml")
            self.assertNotIn("pull_request_target:", workflow)
            self.assertNotIn("secrets: inherit", workflow)
            self.assertNotRegex(workflow, r"(?m)^\s*(?:contents|actions|id-token|pull-requests):\s*write")

    def test_aggregate_is_always_present_and_not_path_filtered(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        self.assertNotRegex(workflow, r"(?m)^\s*paths(?:-ignore)?:")
        required_job = workflow.split("  required:\n", 1)[1]
        self.assertIn("name: CI / required", required_job)
        self.assertIn("if: always()", required_job)
        self.assertIn("needs: [plan, metadata, product]", required_job)
        self.assertNotRegex(required_job, r"(?m)^\s*continue-on-error:")
        product_job = workflow.split("  product:\n", 1)[1].split("  required:\n", 1)[0]
        self.assertIn("fail-fast: false", product_job)
        self.assertIn("matrix: ${{ fromJSON(needs.plan.outputs.matrix) }}", product_job)
        self.assertNotRegex(workflow, r"(?m)^\s*continue-on-error:")

    def test_installed_verification_uses_artifact_id_without_rebuilding(self):
        workflow = (ROOT / ".github/workflows/release-candidate.yml").read_text()
        self.assertIn("artifact-ids:", workflow)
        self.assertIn("digest-mismatch: error", workflow)
        script = (ROOT / ".github/scripts/installed-check.sh").read_text()
        self.assertNotIn("gem build", script)
        self.assertIn("tools/qualify_baseline.py", script)
        self.assertIn('cmp "$ARTIFACT_DIR/thistle.gem"', script)
        self.assertIn('cmp "$ARTIFACT_DIR/thistle-map.gem"', script)


if __name__ == "__main__":
    unittest.main()
