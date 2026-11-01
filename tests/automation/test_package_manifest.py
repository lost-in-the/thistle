"""Disposable RubyGems selectors/archives and installed documentation links.

Only gemspecs/version files are evaluated. Archive payloads are harmless stubs,
not product packages; no extension compilation, dependency install or Rails runs.
Keep this outside Core's copied test/test_*.rb installed-consumer suite.
"""
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import tempfile
import unittest
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[2]
CORE_DOCS = tuple("docs/development/" + name + ".md" for name in (
    "platforms", "tagged-call-encoding", "loaded-model-evidence", "callback-evidence",
    "find-evidence", "route-constraints", "model-references", "recorded-domain-access",
    "fact-identity", "model-brief-markdown", "source-comprehension", "job-mail-template", "route-actions", "passage", "model-neighborhood", "source-freshness", "generation-comparison",
))
MAP_DOCS = ("docs/MODELS.md", "docs/REUSE.md", "docs/investigations.md", "docs/source-comprehension.md", "docs/job-mail-template.md", "docs/route-actions.md", "docs/passage.md", "docs/model-neighborhood.md")
CORE_INPUTS = (
    "lib/thistle/version.rb", "lib/thistle.rb", "exe/thistle", "ext/thistle_native/extconf.rb",
    "ext/thistle_native/thistle_native.c", "engine/Cargo.toml", "engine/Cargo.lock",
    "engine/src/lib.rs", "engine/vendor/crate/.cargo-checksum.json",
    "engine/vendor/crate/LICENSE", "engine/vendor/crate/docs/guide.md",
    "engine/vendor/crate/src/target/source.rs", "engine/vendor/crate/fixture.o",
    "engine/vendor/crate/Makefile", "README.md", "CHANGELOG.md", "LICENSE",
    "THIRD_PARTY.md", "rust-toolchain.toml", ".cargo/config.toml",
)
MAP_INPUTS = (
    "lib/thistle/map/version.rb", "lib/thistle/map.rb", "assets/style.css",
    "examples/config.ru", "README.md", "CHANGELOG.md", "LICENSE.txt", "LICENSE.woods-map.txt",
)
EXCLUDED = (
    "docs/admin.md", "docs/admin.json", "docs/development/admin.md", "docs/handoff/source.rs",
    "engine/target/output.rs", "ext/thistle_native/target/output.rs",
    "ext/thistle_native/native.bundle", "ext/thistle_native/native.o",
    "ext/thistle_native/native.so", "ext/thistle_native/native.a",
    "ext/thistle_native/Makefile", "ext/thistle_native/mkmf.log",
    "ext/thistle_native/native.bundle.dSYM/Contents/Resources/DWARF/native",
)


@unittest.skipUnless(shutil.which("ruby"), "Ruby is needed for RubyGems selector checks")
class PackageManifestTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="package-manifest-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for package, spec, version, paths in (
            ("", "thistle.gemspec", "lib/thistle/version.rb", CORE_INPUTS + CORE_DOCS + EXCLUDED),
            ("map", "thistle-map.gemspec", "lib/thistle/map/version.rb",
             MAP_INPUTS + MAP_DOCS + ("docs/VALIDATION.md", "docs/browser.json")),
        ):
            directory = self.root / package
            for name in paths:
                path = directory / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text("# disposable fixture\n")
            for name in (spec, version):
                shutil.copyfile(ROOT / package / name, directory / name)
        self.expected = {"core": sorted(CORE_INPUTS + CORE_DOCS), "map": sorted(MAP_INPUTS + MAP_DOCS)}

    def ruby(self, script, *args):
        result = subprocess.run(
            [shutil.which("ruby"), "-e", script, *map(str, args)], cwd=self.root,
            env={key: value for key, value in os.environ.items()
                 if key in ("PATH", "HOME", "TMPDIR", "LANG")},
            text=True, capture_output=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        return result.stdout

    def test_selectors_preserve_build_vendor_notices_and_refuse_each_missing_document(self):
        selected = json.loads(self.ruby('''
require "json"
core = Gem::Specification.load("thistle.gemspec") or abort "Core spec refused"
map = Gem::Specification.load("map/thistle-map.gemspec") or abort "Map spec refused"
puts JSON.generate(core: core.files, map: map.files)
'''))
        self.assertEqual(selected, self.expected)
        # Probe only the disposable fixture, restoring every input before continuing.
        self.ruby('''
require "fileutils"
ARGV.each_slice(2) do |spec, path|
  File.rename(path, path + ".held")
  begin
    raise "Missing document admitted: #{path}" if Gem::Specification.load(spec)
  ensure
    File.rename(path + ".held", path)
  end
end
''', *[item for spec, paths in (("thistle.gemspec", CORE_DOCS),
                               ("map/thistle-map.gemspec", tuple("map/" + p for p in MAP_DOCS)))
      for path in paths for item in (spec, path)])

    def test_already_built_manifest_assertion_accepts_pair_and_stops_staging_on_mismatch(self):
        helper = (ROOT / "tools/check_install.rb").read_text()
        start = helper.index("    # Check actual payloads before staging")
        end = helper.index('    cache = File.join(worker, "vendor/cache")', start)
        # Run exactly the production assertion, followed by a staging canary.
        assertion = self.root / "assertion.rb"
        assertion.write_text(helper[start:end] + '\nFile.write("staged", "yes")\n')
        self.ruby('''
require "rubygems/package"
core_spec = Gem::Specification.load("thistle.gemspec") or abort
map_spec = Gem::Specification.load("map/thistle-map.gemspec") or abort
# These tiny archives contain only disposable stubs, never Thistle implementation.
core = File.expand_path(Gem::Package.build(core_spec))
map = Dir.chdir("map") { File.expand_path(Gem::Package.build(map_spec)) }
check = -> { eval(File.read(ARGV.fetch(0)), binding, ARGV.fetch(0)) }
check.call
raise "Valid pair did not reach staging" unless File.file?("staged")
[core_spec, map_spec].each do |spec|
  original = spec.files.dup
  [original.reject { |p| p == (spec == core_spec ? "docs/development/platforms.md" : "docs/MODELS.md") },
   original + [spec == core_spec ? "docs/admin.json" : "docs/browser.json"]].each do |files|
    File.delete("staged") if File.exist?("staged")
    spec.files = files
    if spec == core_spec
      core = File.expand_path(Gem::Package.build(spec))
    else
      map = Dir.chdir("map") { File.expand_path(Gem::Package.build(spec)) }
    end
    begin
      check.call
      raise "Bad manifest admitted"
    rescue RuntimeError => error
      raise unless error.message.start_with?("Installed document manifest differs for ")
    end
    raise "Staged after refusal" if File.exist?("staged")
  end
  spec.files = original
  if spec == core_spec
    core = File.expand_path(Gem::Package.build(spec))
  else
    map = Dir.chdir("map") { File.expand_path(Gem::Package.build(spec)) }
  end
end
''', assertion)


class InstalledDocumentLinkTests(unittest.TestCase):
    def test_links_resolve_inside_their_package_or_use_explicit_urls(self):
        for package, paths, inputs in (("", CORE_DOCS, CORE_INPUTS), ("map", MAP_DOCS, MAP_INPUTS)):
            members = set(paths + inputs)
            for name in ("README.md", *paths):
                text = (ROOT / package / name).read_text()
                text = re.sub(r"^```.*?^```[^\n]*", "", text, flags=re.MULTILINE | re.DOTALL)
                links = re.findall(r"\[[^\]\n]+\]\(([^)\s]+)\)", text)
                for target in links:
                    with self.subTest(package=package or "core", document=name, target=target):
                        url = urlsplit(target)
                        if url.scheme:
                            self.assertEqual(url.scheme, "https")
                            self.assertTrue(url.netloc)
                            continue
                        self.assertFalse(url.netloc)
                        # Resolve as an installed package: checkout siblings cannot satisfy a link.
                        parts = list(PurePosixPath(name).parent.parts)
                        for part in PurePosixPath(unquote(url.path)).parts:
                            if part == "..":
                                self.assertTrue(parts, "Link escapes installed package")
                                parts.pop()
                            elif part != ".":
                                parts.append(part)
                        resolved = "/".join(parts) if url.path else name
                        self.assertIn(resolved, members)
                        destination = ROOT / package / resolved
                        self.assertTrue(destination.is_file())
                        if url.fragment:
                            headings = re.findall(r"^#+\s+(.+)$", destination.read_text(), re.MULTILINE)
                            anchors = {re.sub(r"[^\w\- ]", "", h.lower()).replace(" ", "-") for h in headings}
                            self.assertIn(unquote(url.fragment), anchors)


if __name__ == "__main__":
    unittest.main()
