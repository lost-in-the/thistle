"""Durable names in first-party active tests; historical prose is not scanned."""
import ast
from pathlib import Path
import re
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
ACTIVE_ROOTS = ("test", "tests/automation", "testbed/tests", "map/test", "mcp/test", "engine/tests")
TICKET = re.compile(r"(?:^|[^a-z0-9])(?:los|issue|pr)[_-]?\d+(?=$|[^a-z0-9])", re.I)
# Deliberately check declaration heads rather than searching arbitrary prose.
# Python uses its AST so examples in docstrings are not declarations.
DECLARATIONS = {
    ".rb": re.compile(r"^\s*(?:(?:class|module)\s+|def\s+(?:self\.)?)([\w:!?]+)|^\s*([A-Z]\w*)\s*=", re.M),
    ".rs": re.compile(r"^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?(?:fn|mod|struct|enum|trait|const|static)\s+(\w+)", re.M),
    ".js": re.compile(r"^\s*(?:export\s+)?(?:async\s+)?(?:function|class|const|let|var)\s+(\w+)", re.M),
}
DECLARATIONS[".mjs"] = DECLARATIONS[".js"]
DECLARATIONS[".rake"] = DECLARATIONS[".rb"]
INLINE_RUST_TEST = re.compile(
    r"^\s*#\[(?:test|cfg\(test\))\]\s*(?:#\[[^\n]*\]\s*)*"
    r"(?:async\s+)?(?:fn|mod)\s+(\w+)", re.M)


def ticket_name(name):
    # Include CamelCase namespaces such as TestLos143 and Los143Fixture.
    separated = re.sub(r"([a-z0-9])([A-Z])", r"\1_\2", name)
    return bool(TICKET.search(separated))


def declared_names(path, inline_rust=False):
    text = path.read_text()
    if inline_rust:
        return INLINE_RUST_TEST.findall(text)
    if path.suffix == ".py":
        return [node.name for node in ast.walk(ast.parse(text, filename=str(path)))
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef))]
    pattern = DECLARATIONS.get(path.suffix)
    return [next(group for group in match.groups() if group)
            for match in pattern.finditer(text)] if pattern else []


def naming_violations(root):
    paths = {path for directory in ACTIVE_ROOTS for path in (root / directory).rglob("*")
             if path.is_file() and "__pycache__" not in path.parts}
    paths.update((root / "engine/src").rglob("*.rs"))
    violations = []
    for path in sorted(paths):
        relative = path.relative_to(root)
        if any(ticket_name(part) for part in relative.parts):
            violations.append(f"{relative}: ticket-based path")
        if path.suffix in (*DECLARATIONS, ".py"):
            inline_rust = relative.parts[:2] == ("engine", "src") and not path.name.endswith("_tests.rs")
            violations.extend(f"{relative}: ticket-based declaration {name}"
                              for name in declared_names(path, inline_rust) if ticket_name(name))
    return violations


class NamingTests(unittest.TestCase):
    def test_active_first_party_names_describe_behavior(self):
        self.assertEqual(naming_violations(ROOT), [])

    def test_ticket_paths_and_declared_test_helpers_are_refused(self):
        cases = (
            ("test/fixtures/los143_source/README.md", "fixture"),
            ("map/test/issue_143_reader.rb", "# attribution only\n"),
            ("engine/tests/pr143_cards.json", "{}"),
            ("test/fixture.rb", "module Los143Fixture\nend\n"),
            ("test/helper.rb", "def test_issue_143_source\nend\n"),
            ("engine/src/source_tests.rs", "fn pr143_source() {}\n"),
            ("engine/src/source.rs", "#[test]\nfn issue_143_source() {}\n"),
            ("tests/automation/test_source.py", "def test_los143_source(): pass\n"),
            ("test/journey.mjs", "async function issue_143_source() {}\n"),
        )
        for name, text in cases:
            with self.subTest(name=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                path = root / name
                path.parent.mkdir(parents=True)
                path.write_text(text)
                self.assertTrue(naming_violations(root))

    def test_semantic_cohorts_and_historical_mentions_are_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            files = {
                "test/fixtures/source_freshness/README.md": "Introduced in LOS143 / issue_143 / PR143.",
                "test/fixtures/rails71/records.rb": "module Rails71Fixture\nend\n",
                "test/test_source.rb": "# LOS143 attribution\ndef test_source_freshness\n  'los143_old_receipt'\nend\n",
                "tests/automation/test_source.py": '"""def test_los143_old_example(): pass"""\ndef test_source_freshness(): pass\n',
                "docs/handoff/los143_old.md": "historical evidence",
                "engine/vendor/test_issue_143.rb": "def issue_143_upstream\nend\n",
                "changelog.d/143.fixed.md": "PR-numbered fragment",
            }
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            self.assertEqual(naming_violations(root), [])


if __name__ == "__main__":
    unittest.main()
