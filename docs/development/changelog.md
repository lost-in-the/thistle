# Conflict-free release notes

Write one small fragment for each noteworthy change. Parallel PRs add separate
files; the release owner alone edits the consolidated changelog. Describe the
user or maintainer outcome, relevant compatibility changes, and any action needed.
Explain in the PR when a change needs no release note.

| Package | Pending notes | Consolidated history | Towncrier scope |
| --- | --- | --- | --- |
| Core gem | `changelog/` | `CHANGELOG.md` | `--dir .` |
| Map gem | `map/changelog/` | `map/CHANGELOG.md` | `--dir map` |

A change affecting both packages gets a note in each. Releasing core consumes no
Map notes, and releasing Map consumes no core notes. The same shared
`towncrier.toml` defines the format for both.

## Author a fragment

Use Towncrier's native `<issue-or-PR>.<type>.md`, such as `26.build.md`.
For multiple notes with the same issue and category, use its native numeric
counter: `26.build.1.md`, `26.build.2.md`. Claim distinct filenames when agents
work on the same issue. The issue identifier stays numeric so generated links
point to the actual GitHub issue or PR.

| Type | Heading |
| --- | --- |
| `added` | Added |
| `build` | Build |
| `changed` | Changed |
| `dependencies` | Dependencies |
| `documentation` | Documentation |
| `fixed` | Fixed |
| `performance` | Performance |
| `security` | Security |
| `testing` | Testing |
| `upgrade-notes` | Upgrade Notes |

Write nonempty UTF-8 Markdown prose; Towncrier supplies the bullet and heading.
Keep paragraphs concise and do not add a release heading or an initial bullet.
Use inline code and links where useful. Keep fragments flat and use real regular
files; symlinks, nested directories, and special files are refused. README files
explain the directory and are never consumed.

Create the file directly or use the standard command, substituting the actual
issue number and content. For another note in the same category, add
`--sub-issue 1`; use `--dir map` for a Map note:

```sh
python3 -m towncrier create --config towncrier.toml --dir . --no-edit \
  --content "Describe the outcome." 123.fixed.md
```

When there is no issue, Towncrier can generate a unique orphan filename from
`+.fixed.md`; it omits the issue link. Prefer linking the bounded work item when
one exists. Ordinary PRs leave `CHANGELOG.md` and `map/CHANGELOG.md` unchanged.

## Install and check

Use Python 3.11 or later on the existing Linux development/CI environment. This
four-package tool environment is development-only; it adds no Ruby runtime or
gem dependency. Use a virtual environment to avoid modifying system Python:

```sh
python3 -m venv /tmp/thistle-notes-env
. /tmp/thistle-notes-env/bin/activate
python3 -m pip install --require-hashes -r .github/requirements-notes.txt
```

The lock pins Towncrier 26.9.0 and all three dependencies, permits only wheels,
and records hashes from exact PyPI releases. Review dependency updates and
regenerate their hashes together. A missing or mismatched wheel fails installation;
there is no unpinned source-build fallback.

From the repository root, run the guard and both native strict previews. The
fixed dummy version/date make these previews repeatable; they declare no release:

```sh
python3 .github/scripts/check-notes.py
python3 -m towncrier build --draft --version 0.0.0 --date 1970-01-01 --config towncrier.toml --dir .
python3 -m towncrier build --draft --version 0.0.0 --date 1970-01-01 --config towncrier.toml --dir map
```

`ignore = []` makes native `build` reject invalid fragment names and categories.
The small guard adds strict UTF-8/nonempty checks and refuses unsafe filesystem
entries, redirected paths, or an altered ignore policy. It parses no fragment
names and renders or removes nothing. Towncrier owns category parsing, duplicate
detection, deterministic ordering, rendering, and consumption.

Do not substitute `towncrier check` for these checks: that command tests whether
a branch added a fragment and can skip when its consolidated changelog changed.
CI runs the guard, both previews, and focused automation regressions without
starting Ruby, Rails, or Rust for note-only changes. To run just these integration
tests locally in the installed tool environment:

```sh
python3 -m unittest discover -s tests/automation -p test_notes.py -v
```

## Prepare one package's release notes

Use the authorized release-preparation branch and a clean working tree. Coordinate
one writer for the branch/index and note directories; validation is not a lock
against concurrent edits. Choose the exact reviewed package version and date,
including a RubyGems prerelease string when appropriate. Set
`THISTLE_NOTES_VERSION` and `THISTLE_NOTES_DATE` explicitly before the next block.

Validate **both packages completely before any release-preparation write**. The
following shell block stops at the first failure and then folds only core;
change only the final `--dir .` to `--dir map` to prepare Map:

```sh
(
  set -eu
  : "${THISTLE_NOTES_VERSION:?Set the reviewed package version}"
  : "${THISTLE_NOTES_DATE:?Set the reviewed release date as YYYY-MM-DD}"
  test -z "$(git status --porcelain)"
  python3 .github/scripts/check-notes.py
  python3 -m towncrier build --draft --version 0.0.0 --date 1970-01-01 --config towncrier.toml --dir .
  python3 -m towncrier build --draft --version 0.0.0 --date 1970-01-01 --config towncrier.toml --dir map
  python3 -m towncrier build --yes --version "$THISTLE_NOTES_VERSION" --date "$THISTLE_NOTES_DATE" --config towncrier.toml --dir .
  git diff --cached
)
```

Towncrier writes and stages that package's changelog, then removes its consumed
fragments. Review the staged changes and exact version/date before committing
the preparation PR. Input validation failures leave files unchanged; the later
write/stage/delete steps are not a crash-atomic filesystem transaction. Recover
a failed preparation in the isolated branch before retrying.

Preparation does not bump gem versions, commit, tag, push, publish gems, or create
a GitHub release. Coordinate version metadata in the same reviewed preparation
change. Build and qualify the exact prepared commit using the
[release flow](pr-ci-release.md); verify the selected package has its matching
dated heading and no pending fragments at that candidate SHA. The other package
may retain valid pending notes. Tagging and publication require their separate
authorization and accepted evidence.

Keep previously published beta/RC sections as history. Unlike Woods' current
preparer, this flow does not rewrite prerelease history into a later final
section. Write any final-release summary deliberately; do not introduce an
automatic history-rewriting tool without a concrete need.

## Choice and provenance

The owner authorized reuse of Woods' conflict-free release-note approach. Its
ten categories, separate authoring/consumption steps, and filesystem/text checks
inform this workflow. See Woods' [fragment implementation at the reviewed source
commit](https://github.com/lost-in-the/woods/blob/e7d692072cce79220e2ea7efce0625003f9dd792/lib/woods/release/fragments.rb)
and [release preparation guide](https://github.com/lost-in-the/woods/blob/e7d692072cce79220e2ea7efce0625003f9dd792/.claude/skills/release-flow/SKILL.md).
No Woods engine or release implementation was imported.

Towncrier supplies the established parser and renderer instead of maintaining a
second custom implementation. Its [multi-project configuration](https://towncrier.readthedocs.io/en/stable/monorepo.html)
supports the two package roots with one config; its [native commands](https://towncrier.readthedocs.io/en/stable/cli.html)
support nonmutating previews and explicit release folds. Native filenames avoid
a compatibility adapter for Woods' old `<type>_<slug>.md` convention. The choice
is a small development dependency and maintenance tradeoff, not a measured claim
that Towncrier is the fastest possible executable.
