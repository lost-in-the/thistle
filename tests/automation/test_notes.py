"""Check our filesystem boundary and real Towncrier integration, not its internals."""
import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
GUARD = ROOT / ".github/scripts/check-notes.py"
SPEC = importlib.util.spec_from_file_location("check_notes", GUARD)
notes = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notes)
CATEGORIES = (
    "added", "build", "changed", "dependencies", "documentation", "fixed",
    "performance", "security", "testing", "upgrade-notes",
)


class NotesFixture(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        for name in ("towncrier.toml", "CHANGELOG.md", "map/CHANGELOG.md",
                     "changelog/README.md", "map/changelog/README.md"):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        self.git("init", "-q")
        self.git("config", "user.name", "Notes test")
        self.git("config", "user.email", "notes@example.invalid")

    def git(self, *args):
        return subprocess.check_output(
            ["git", "-C", str(self.root), *args], stderr=subprocess.PIPE,
        ).decode().strip()

    def write(self, name, body="A useful change.\n"):
        path = self.root / name
        path.write_bytes(body if isinstance(body, bytes) else body.encode())
        return path

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes()
                for p in self.root.rglob("*")
                if ".git" not in p.relative_to(self.root).parts and p.is_file()}

    def towncrier(self, package, *args, check=True):
        return subprocess.run(
            [sys.executable, "-m", "towncrier", "build", "--config", "towncrier.toml",
             "--dir", package, "--version", "0.1.0.pre.1", "--date", "2026-10-28", *args],
            cwd=self.root, text=True, capture_output=True, check=check,
        )

    def checked_fold(self, package):
        # Exercise the documented sequence: every precheck finishes before a write.
        subprocess.run([sys.executable, str(GUARD)], cwd=self.root,
                       check=True, capture_output=True)
        for scope in (".", "map"):
            self.towncrier(scope, "--draft")
        return self.towncrier(package, "--yes")


class FilesystemTests(NotesFixture):
    def test_real_flat_utf8_inputs_pass(self):
        self.write("changelog/26.fixed.md", "Preserve café input.\n")
        self.write("map/changelog/26.changed.md")
        self.assertEqual(notes.validate(self.root), 4)

    def test_symlinks_nested_directories_and_special_files_fail_before_read(self):
        for directory in ("changelog", "map/changelog"):
            for kind in ("symlink", "directory", "fifo"):
                with self.subTest(directory=directory, kind=kind):
                    path = self.root / directory / "26.fixed.md"
                    if kind == "symlink":
                        path.symlink_to(self.root / "CHANGELOG.md")
                    elif kind == "directory":
                        path.mkdir()
                    else:
                        os.mkfifo(path)
                    try:
                        with self.assertRaisesRegex(ValueError, "regular file"):
                            notes.validate(self.root)
                    finally:
                        path.rmdir() if kind == "directory" else path.unlink()

    def test_directory_ancestor_and_output_symlinks_are_refused(self):
        for name in ("map", "changelog", "map/changelog", "towncrier.toml",
                     "CHANGELOG.md", "map/CHANGELOG.md"):
            with self.subTest(name=name):
                path = self.root / name
                saved = path.with_name(path.name + ".saved")
                path.rename(saved)
                path.symlink_to(saved)
                try:
                    with self.assertRaisesRegex(ValueError, "symlink"):
                        notes.validate(self.root)
                finally:
                    path.unlink()
                    saved.rename(path)

    def test_blank_and_invalid_utf8_are_refused_in_both_packages(self):
        for directory in ("changelog", "map/changelog"):
            for body in (b"", b" \n\t", b"Invalid \xff text"):
                with self.subTest(directory=directory, body=body):
                    path = self.write(f"{directory}/26.fixed.md", body)
                    try:
                        with self.assertRaises((ValueError, UnicodeError)):
                            notes.validate(self.root)
                    finally:
                        path.unlink()

    def test_config_cannot_redirect_checked_inputs_or_outputs(self):
        path = self.root / "towncrier.toml"
        original = path.read_text()
        for before, after in (
            ('directory = "changelog"', 'directory = "../elsewhere"'),
            ('filename = "CHANGELOG.md"', 'filename = "../outside.md"'),
            ('template = "towncrier:default.md"', 'template = "other.md"'),
            ('ignore = []', 'ignore = ["*.md"]'),
            ('[tool.towncrier]', '[tool.towncrier]\nsection = [{path = "../outside"}]'),
        ):
            with self.subTest(after=after):
                path.write_text(original.replace(before, after, 1))
                with self.assertRaisesRegex(ValueError, "reviewed flat package layout"):
                    notes.validate(self.root)
        path.write_text(original)


class TowncrierTests(NotesFixture):
    def test_drafts_are_deterministic_nonmutating_and_include_all_ten_categories(self):
        for category in reversed(CATEGORIES):
            self.write(f"changelog/26.{category}.md", f"Core {category} note.\n")
        self.write("changelog/26.build.1.md", "A separate build note.\n")
        self.write("map/changelog/26.changed.md", "Map-only note.\n")
        before = self.snapshot()
        core = self.towncrier(".", "--draft").stdout
        self.assertEqual(core, self.towncrier(".", "--draft").stdout)
        self.assertEqual([line for line in core.splitlines() if line.startswith("### ")],
                         ["### " + category.replace("-", " ").title() for category in CATEGORIES])
        self.assertIn("A separate build note.", core)
        self.assertIn("issues/26", core)
        self.assertNotIn("Map-only note", core)
        mapped = self.towncrier("map", "--draft").stdout
        self.assertIn("Map-only note", mapped)
        self.assertNotIn("Core added note", mapped)
        self.assertEqual(self.snapshot(), before)
        self.assertEqual(self.git("diff", "--cached"), "")

    def test_native_strict_parser_refuses_unknown_categories_and_duplicate_notes(self):
        invalid = self.write("changelog/26.unknown.md")
        result = self.towncrier(".", "--draft", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid news fragment name", result.stderr)
        invalid.unlink()
        self.write("changelog/26.build.md")
        self.write("changelog/26.build")
        result = self.towncrier(".", "--draft", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("multiple files", result.stderr)

    def test_fold_consumes_only_selected_package_without_committing(self):
        self.write("changelog/26.build.md", "Core build note.\n")
        self.write("map/changelog/26.changed.md", "Map change note.\n")
        self.git("add", "-A")
        self.git("commit", "-qm", "notes fixture")
        head = self.git("rev-parse", "HEAD")
        before = self.snapshot()
        self.checked_fold(".")
        self.assertIn("## 0.1.0.pre.1 (2026-10-28)", (self.root / "CHANGELOG.md").read_text())
        self.assertFalse((self.root / "changelog/26.build.md").exists())
        self.assertEqual({k: v for k, v in self.snapshot().items() if k.startswith("map/")},
                         {k: v for k, v in before.items() if k.startswith("map/")})
        core_after = (self.root / "CHANGELOG.md").read_bytes()
        self.checked_fold("map")
        self.assertFalse((self.root / "map/changelog/26.changed.md").exists())
        self.assertIn("Map change note.", (self.root / "map/CHANGELOG.md").read_text())
        self.assertEqual((self.root / "CHANGELOG.md").read_bytes(), core_after)
        self.assertTrue((self.root / "changelog/README.md").is_file())
        self.assertTrue((self.root / "map/changelog/README.md").is_file())
        self.assertEqual(self.git("rev-parse", "HEAD"), head)

    def test_invalid_other_package_stops_fold_without_changing_any_files(self):
        self.write("changelog/26.build.md", "Keep the valid core note.\n")
        for name, body in (("26.changed.md", b"Bad \xff input"),
                           ("26.unknown.md", b"Unknown category")):
            with self.subTest(name=name):
                invalid = self.write(f"map/changelog/{name}", body)
                before = self.snapshot()
                index_before = self.git("diff", "--cached")
                with self.assertRaises(subprocess.CalledProcessError):
                    self.checked_fold(".")
                self.assertEqual(self.snapshot(), before)
                self.assertEqual(self.git("diff", "--cached"), index_before)
                invalid.unlink()


if __name__ == "__main__":
    unittest.main()
