"""Harmless subprocess coverage of the portable installed-contract orchestration.

No gems, Rails, native code, build tools, or product tests run. Evaluate the actual
post-install fragment against synthetic files and tiny Ruby producer/consumer
scripts; installation, native/toolchain observation, and Core tests are stubbed.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "tools/check_install.rb"
RUBY = shutil.which("ruby")
DRIVER = r'''
require "digest"
require "fileutils"
require "json"
require "rbconfig"
source, output, worker, installed_root, helper = ARGV
ruby = RbConfig.ruby
env = { "PATH" => ENV.fetch("PATH"), "SOURCE" => source }
core, map = %w[core.gem map.gem].map { |name| File.join(output, name) }
observed = { "installed_root" => installed_root, "native_sha256" => "fake-native",
             "native_path" => File.join(installed_root, "lib/thistle/thistle_native.bundle") }
run = ->(*args, **options) do
  raise "Unexpected command #{args.inspect}" unless args == [ruby, "-S", "bundle", "install", "--local"]
  File.write(File.join(worker, "Gemfile.lock"), "consumer lock\n")
end
capture = ->(*args, **options) do
  args.include?("-e") ? JSON.generate(observed) : "stub tool version\n"
end

# Keep real process completion, redirection, and failure semantics. Remove only
# Bundler's executable prefix and replace Core's product test command.
module HarmlessChildren
  def system(env, *args, **options)
    raise "Unexpected executable prefix" unless args[1, 3] == ["-S", "bundle", "exec"]
    args = args.drop(4)
    if args.include?("-I")
      raise "Unexpected Core command" unless args.last.include?('test/test_*.rb')
      args = [args.first, "-e", "puts 'stub Core tests'"]
    end
    super(env, *args, **options)
  end
end
Object.prepend(HarmlessChildren)

code = File.read(helper)
start = code.index('    run.call(ruby, "-S", "bundle", "install", "--local")') or raise "Install boundary absent"
finish = code.index('    puts JSON.pretty_generate(report)', start) or raise "Report boundary absent"
eval(code[start...finish], binding, helper, code[0...start].count("\n") + 1)
'''

PRODUCER = r'''
require "json"
require "digest"
require "fileutils"
fixture, root, store = ARGV
raise "Producer arguments missing" unless ARGV.length == 3
raise "Producer staged inside source" if [__FILE__, fixture, root, store].any? { |p| p.start_with?(ENV.fetch("SOURCE") + "/") }
raise "Fixture absent" unless File.read(File.join(fixture, "booted_app.rb")) == "# selected boot\n"
module Rails; end
FileUtils.mkdir_p(store)
File.write(File.join(store, "producer-pid"), Process.pid.to_s)
puts JSON.generate("generation" => "fake-generation", "active_record_version" => "8.1.4",
  "fixture_source_sha256" => Digest::SHA256.file(File.join(fixture, "records.rb")).hexdigest)
'''

SMOKE = r'''
require "json"
raise "Smoke staged inside source" if __FILE__.start_with?(ENV.fetch("SOURCE") + "/")
raise "Consumer inherited Rails" if defined?(Rails)
if ARGV.any?
  raise "Wrong consumer arguments" unless ARGV.length == 2
  store, receipt = ARGV
  raise "Producer still in consumer process" if File.read(File.join(store, "producer-pid")) == Process.pid.to_s
  raise "Receipt missing generation" unless JSON.parse(File.read(receipt)).fetch("generation") == "fake-generation"
end
File.write("consumer-args.json", JSON.generate(ARGV))
puts JSON.generate("status" => "passed", "native_sha256" => "fake-native")
'''


class InstalledContractTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(RUBY, "Ruby is required for the harmless orchestration regression")
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "selected-source"
        self.output = self.source / "pkg/evidence"
        self.worker = self.root / "fresh-consumer"
        self.installed = self.worker / "bundle/gems/thistle"
        for path in (self.output, self.installed / "lib/thistle"):
            path.mkdir(parents=True)
        self.write("Gemfile.lock", "development lock\n")
        self.write("test/support/installed_cli.rb", 'File.write("cli-ran", "yes")\n')
        self.write("map/test/installed_smoke.rb", SMOKE)
        for name in ("core.gem", "map.gem"):
            (self.output / name).write_text(name)
        self.driver = self.root / "driver.rb"
        self.driver.write_text(DRIVER)

    def write(self, name, contents):
        path = self.source / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(contents)
        return path

    def model_inputs(self):
        self.write("test/fixtures/models/booted_app.rb", "# selected boot\n")
        self.write("test/fixtures/models/records.rb", "# selected records\n")
        self.write("map/test/installed_model_producer.rb", PRODUCER)

    def installed_model(self):
        (self.installed / "lib/thistle/model_observer.rb").write_text("# installed payload\n")

    def invoke(self):
        # An outer finite timeout bounds only these harmless synthetic children.
        return subprocess.run(
            [RUBY, str(self.driver), str(self.source), str(self.output),
             str(self.worker), str(self.installed), str(HELPER)],
            cwd=self.root, env={"PATH": os.environ["PATH"]},
            capture_output=True, text=True, timeout=15,
        )

    def read_json(self, name):
        return json.loads((self.output / name).read_text())

    def assert_locks(self):
        self.assertEqual((self.output / "development-Gemfile.lock").read_bytes(), b"development lock\n")
        self.assertEqual((self.output / "consumer-Gemfile.lock").read_bytes(), b"consumer lock\n")

    def assert_stopped(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertFalse((self.output / "report.json").exists())
        self.assertFalse((self.worker / "cli-ran").exists())
        self.assert_locks()
        self.assertEqual(self.read_json("native-observation.json")["native_path"],
                         str(self.installed / "lib/thistle/thistle_native.bundle"))

    def test_legacy_payload_ignores_source_model_inputs_and_uses_no_arguments(self):
        self.model_inputs()
        # Neither fixtures nor a source observer may opt a pre-model gem in.
        self.write("lib/thistle/model_observer.rb", "# source only\n")
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads((self.worker / "consumer-args.json").read_text()), [])
        report = self.read_json("report.json")
        self.assertEqual(report["model_journey"], "not_applicable_to_selected_package")
        self.assertIsNone(report["model_producer_receipt_sha256"])
        self.assertFalse((self.output / "model-producer.json").exists())

    def test_installed_model_produces_then_fresh_consumer_and_binds_evidence(self):
        self.model_inputs()
        self.installed_model()
        # No observer exists in the selected checkout: installed payload wins.
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        args = json.loads((self.worker / "consumer-args.json").read_text())
        self.assertEqual(args, [str(self.worker / "model-store"), str(self.worker / "model-producer.json")])
        report = self.read_json("report.json")
        self.assertEqual(report["model_journey"], "passed")
        self.assertEqual(report["installed_inputs"], self.read_json("installed-inputs.json"))
        inputs = report["installed_inputs"]
        expected = {
            "installed_model_producer.rb": PRODUCER,
            "model-fixture/booted_app.rb": "# selected boot\n",
            "model-fixture/records.rb": "# selected records\n",
        }
        self.assertEqual(inputs["model_fixture_inputs"], {
            name: hashlib.sha256(content.encode()).hexdigest() for name, content in expected.items()
        })
        self.assertEqual(inputs["smoke_sha256"], hashlib.sha256(SMOKE.encode()).hexdigest())
        for key, name in (
            ("model_producer_receipt_sha256", "model-producer.json"),
            ("map_smoke_receipt_sha256", "map-installed-smoke.json"),
            ("development_lock_sha256", "development-Gemfile.lock"),
            ("consumer_lock_sha256", "consumer-Gemfile.lock"),
        ):
            self.assertEqual(report[key], hashlib.sha256((self.output / name).read_bytes()).hexdigest())
        self.assertEqual(report["native_sha256"], "fake-native")
        self.assertEqual(report["native_path"], self.read_json("native-observation.json")["native_path"])
        self.assertEqual(report["packages"], {
            name: hashlib.sha256((name + ".gem").encode()).hexdigest() for name in ("core", "map")
        })
        self.assertTrue((self.worker / "cli-ran").exists())
        self.assert_locks()

    def test_model_payload_missing_any_required_input_stops_before_consumer(self):
        self.installed_model()
        for missing in ("test/fixtures/models/booted_app.rb", "test/fixtures/models/records.rb",
                        "map/test/installed_model_producer.rb"):
            with self.subTest(missing=missing):
                self.model_inputs()
                (self.source / missing).unlink()
                # Each invocation has a fresh worker, like the real helper.
                shutil.rmtree(self.worker / "test", ignore_errors=True)
                shutil.rmtree(self.worker / "model-fixture", ignore_errors=True)
                (self.worker / "installed_model_producer.rb").unlink(missing_ok=True)
                (self.worker / "lib").unlink(missing_ok=True)
                result = self.invoke()
                self.assert_stopped(result)
                self.assertFalse((self.worker / "consumer-args.json").exists())
                self.assertFalse((self.output / "model-producer.json").exists())

    def test_failed_producer_retains_output_inputs_and_locks_without_consumer(self):
        self.model_inputs()
        self.installed_model()
        self.write("map/test/installed_model_producer.rb", "puts 'partial receipt'; warn 'producer failed'; exit 7\n")
        result = self.invoke()
        self.assert_stopped(result)
        self.assertFalse((self.worker / "consumer-args.json").exists())
        self.assertFalse((self.output / "map-installed-smoke.json").exists())
        self.assertEqual((self.output / "model-producer.json").read_text(), "partial receipt\n")
        self.assertEqual((self.output / "model-producer.json.stderr").read_text(), "producer failed\n")
        self.assertTrue(self.read_json("installed-inputs.json")["model_enabled"])

    def test_failed_consumer_retains_producer_receipt_without_passing_report(self):
        self.model_inputs()
        self.installed_model()
        self.write("map/test/installed_smoke.rb", "warn 'consumer failed'; exit 9\n")
        result = self.invoke()
        self.assert_stopped(result)
        self.assertEqual(self.read_json("model-producer.json")["generation"], "fake-generation")
        self.assertEqual((self.output / "map-installed-smoke.json.stderr").read_text(), "consumer failed\n")
        self.assertTrue((self.output / "installed-inputs.json").is_file())

    def test_native_mismatch_stops_before_cli_and_passing_report(self):
        self.write("map/test/installed_smoke.rb", SMOKE.replace('"fake-native"', '"different-native"'))
        result = self.invoke()
        self.assert_stopped(result)
        self.assertIn("different native bytes", result.stderr)


if __name__ == "__main__":
    unittest.main()
