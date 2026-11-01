"""Portable guidance contracts; no provider execution or general YAML/Markdown parser."""
from pathlib import Path
import re
import tempfile
import unittest
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[2]
PROCEDURES = ("plan", "build", "review", "check", "hand-off")
ROLES = ("overseer", "pm", "lead", "reviewer", "auditor")
ENTRIES = tuple(
    f"{root}/skills/thistle-{name}/SKILL.md"
    for root in (".agents", ".claude") for name in PROCEDURES
)
GUIDANCE = (
    "AGENTS.md", "CLAUDE.md", "README.md", ".entire/agent-guide.md",
    "docs/MISSION.md", "docs/PROJECT_SCOPE.md",
    *[f"docs/development/{name}.md" for name in (
        "agent-team", "agent-workflow", "agent-configuration", "pr-ci-release")],
    *[f"docs/development/roles/{name}.md" for name in ROLES],
    *ENTRIES,
)


def entry(text):
    """Validate our two-field plain-string format, not arbitrary valid YAML."""
    if not text.startswith("---\n"):
        raise ValueError("Missing opening frontmatter delimiter")
    header, delimiter, body = text[4:].partition("\n---\n")
    if not delimiter or not body.strip():
        raise ValueError("Missing closing frontmatter delimiter or instructions")
    # Restricted YAML character set: retain printable Unicode, with LF as the
    # only header separator. Tabs and raw controls are outside our entry format.
    if any(not (character == "\n" or "\x20" <= character <= "\x7e"
                or "\xa0" <= character <= "\ud7ff" or "\ue000" <= character <= "\ufffd"
                or "\U00010000" <= character <= "\U0010ffff") for character in header):
        raise ValueError("Forbidden header character (tabs and controls are not supported)")
    metadata = {}
    for line in header.splitlines():
        key, separator, value = line.partition(": ")
        if not separator or key not in ("name", "description") or key in metadata:
            raise ValueError("Expected unique name and description fields only")
        # Deliberately reject richer/ambiguous YAML instead of approximating it.
        if (not re.fullmatch(r"[A-Za-z][^\r\n]*", value)
                or value != value.strip() or re.search(r":(?:\s|$)|\s#", value)
                or value.lower() in ("true", "false", "yes", "no", "on", "off", "null")):
            raise ValueError("Expected unambiguous single-line plain string")
        metadata[key] = value
    if set(metadata) != {"name", "description"}:
        raise ValueError("Missing required metadata")
    if not re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*", metadata["name"]):
        raise ValueError("Invalid skill name")
    return metadata, body


def inline_links(text):
    # The guidance uses simple inline links. Anchors and external health are not checked.
    text = re.sub(r"^```.*?^```[^\n]*", "", text, flags=re.MULTILINE | re.DOTALL)
    return re.findall(r"\[[^\]\n]+\]\(([^)\s]+)\)", text)


def local_target(root, document, target):
    url = urlsplit(target)
    if url.scheme or url.netloc:
        return None
    path = (root / document).parent / unquote(url.path) if url.path else root / document
    path = path.resolve()
    if not path.is_relative_to(root.resolve()) or not path.is_file():
        raise ValueError(f"{document}: missing/outside local file target {target}")
    return path


def validate_contracts(root, guidance=GUIDANCE):
    entries = {}
    for document in ENTRIES:
        try:
            metadata, body = entry((root / document).read_text())
        except (OSError, ValueError) as error:
            raise ValueError(f"{document}: {error}") from error
        if metadata["name"] != Path(document).parent.name:
            raise ValueError(f"{document}: name does not match directory")
        entries[document] = metadata, body

    shared_wrapper = None
    for procedure in PROCEDURES:
        name = f"thistle-{procedure}"
        canonical = f".agents/skills/{name}/SKILL.md"
        wrapper = f".claude/skills/{name}/SKILL.md"
        metadata, body = entries[wrapper]
        if metadata != entries[canonical][0]:
            raise ValueError(f"{wrapper}: metadata differs from canonical entry")
        targets = [link for link in inline_links(body) if ".agents/skills/" in link]
        if (len(targets) != 1
                or local_target(root, wrapper, targets[0]) != (root / canonical).resolve()):
            raise ValueError(f"{wrapper}: expected one matching canonical target")
        normalized = body.replace(name, "thistle-PROCEDURE").strip()
        if shared_wrapper is not None and normalized != shared_wrapper:
            raise ValueError(f"{wrapper}: wrapper instructions diverge")
        shared_wrapper = normalized

    for document in guidance:
        for target in inline_links((root / document).read_text()):
            local_target(root, document, target)


class AgentContractTests(unittest.TestCase):
    def test_repository_entries_wrappers_and_guidance_file_targets(self):
        validate_contracts(ROOT)

    def test_restricted_metadata_accepts_either_field_order(self):
        for header in (
            "name: thistle-plan\ndescription: Plan café 東京 🙂.",
            "description: Plan café 東京 🙂.\nname: thistle-plan",
        ):
            with self.subTest(header=header):
                metadata, _ = entry(f"---\n{header}\n---\nInstructions.\n")
                self.assertEqual(metadata["name"], "thistle-plan")
                self.assertEqual(metadata["description"], "Plan café 東京 🙂.")

    def test_missing_duplicate_extra_or_malformed_metadata_is_refused(self):
        headers = (
            "name: thistle-plan",  # Missing description.
            "name: thistle-plan\nname: thistle-build\ndescription: Plan.",
            "name: thistle-plan\ndescription: Plan.\ntools: Read",
            "name: thistle-plan\ndescription:",
            "name: thistle-plan\ndescription: [unterminated",
            "name: thistle-plan\ndescription: Plan: invalid mapping",
            "name: thistle-plan\ndescription: Plan # implicit comment",
            "name: thistle-plan\ndescription: false",
            "name: thistle-plan\ndescription: 123",
            "name: thistle-plan\ndescription: |\n  Multiline",
            "name: Thistle-Plan\ndescription: Plan.",
        )
        for header in headers:
            with self.subTest(header=header), self.assertRaises(ValueError):
                entry(f"---\n{header}\n---\nInstructions.\n")
        for text in ("name: thistle-plan\n", "---\nname: thistle-plan\n",
                     "---\nname: thistle-plan\ndescription: Plan.\n---\n"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                entry(text)

    def fixture(self, root):
        for document in ENTRIES:
            path = root / document
            path.parent.mkdir(parents=True, exist_ok=True)
            name = path.parent.name
            body = (f"Load [canonical](../../../.agents/skills/{name}/SKILL.md).\n"
                    if document.startswith(".claude/") else "Canonical instructions.\n")
            path.write_text(f"---\nname: {name}\ndescription: Do bounded work.\n---\n\n{body}")

    def test_missing_entries_targets_metadata_and_wrapper_drift_are_refused(self):
        canonical = ".agents/skills/thistle-plan/SKILL.md"
        wrapper = ".claude/skills/thistle-plan/SKILL.md"
        cases = (
            (canonical, None, "No such file"),
            (wrapper, None, "No such file"),
            (canonical, ("name: thistle-plan", "name: thistle-wrong"), "directory"),
            (wrapper, ("description: Do bounded work.", "description: Different."), "metadata differs"),
            (wrapper, (".agents/skills/thistle-plan/SKILL.md", ".agents/skills/thistle-build/SKILL.md"), "canonical target"),
            (wrapper, ("[canonical](../../../.agents/skills/thistle-plan/SKILL.md)", "canonical"), "canonical target"),
            (wrapper, ("Load [canonical]", "Delegate work then load [canonical]"), "diverge"),
        )
        for document, mutation, message in cases:
            with self.subTest(document=document, mutation=mutation), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                self.fixture(root)
                validate_contracts(root, guidance=ENTRIES)
                path = root / document
                if mutation is None:
                    path.unlink()
                else:
                    path.write_text(path.read_text().replace(*mutation))
                with self.assertRaisesRegex(ValueError, message):
                    validate_contracts(root, guidance=ENTRIES)

    def test_raw_control_characters_in_matching_entries_are_refused(self):
        for character in ("\x00", "\x07", "\x7f", "\x80", "\x9f", "\t"):
            with self.subTest(character=repr(character)), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                self.fixture(root)
                # Both sides match: consistency must not hide malformed metadata.
                for directory in (".agents", ".claude"):
                    path = root / directory / "skills/thistle-plan/SKILL.md"
                    path.write_text(path.read_text().replace("Do bounded work.", f"Plan{character}bad"))
                with self.assertRaisesRegex(ValueError, "Forbidden header character"):
                    validate_contracts(root, guidance=ENTRIES)

    def test_simple_local_links_check_files_without_claiming_anchor_or_external_health(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            self.fixture(root)
            document = root / "guide.md"
            document.write_text("[file](guide.md#unverified-anchor) [external](https://example.invalid/)\n")
            validate_contracts(root, guidance=("guide.md",))
            document.write_text("[missing](missing.md)\n")
            with self.assertRaisesRegex(ValueError, "missing/outside local file"):
                validate_contracts(root, guidance=("guide.md",))
            document.write_text("[outside](../outside.md)\n")
            with self.assertRaisesRegex(ValueError, "missing/outside local file"):
                validate_contracts(root, guidance=("guide.md",))


if __name__ == "__main__":
    unittest.main()
