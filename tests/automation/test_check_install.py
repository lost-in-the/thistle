"""Harmless subprocess coverage of the portable installed-contract orchestration.

No gems, Rails, native code, build tools, or product tests run. Evaluate the actual
post-install fragment against synthetic files and tiny Ruby producer/consumer
scripts; installation, native/toolchain observation, and Core tests are stubbed.
"""
import hashlib
import fnmatch
import json
import os
from pathlib import Path
import shutil
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / "tools/check_install.rb"
RUBY = shutil.which("ruby")


class PlatformReceiptTests(unittest.TestCase):
    def test_platform_upload_keeps_success_and_failure_contract_receipts(self):
        workflow = (ROOT / ".github/workflows/ci.yml").read_text()
        upload = workflow.split("- name: Preserve platform receipts", 1)[1].split("  required:", 1)[0]
        self.assertIn("if: always()", upload)
        patterns = re.findall(r"^\s+(pkg/install-check-\S+)$", upload, re.MULTILINE)
        for name in (
            "report.json", "native-observation.json", "installed-inputs.json", "core-fixture-inputs.json",
            "model-producer.json", "model-producer.json.stderr",
            "map-installed-smoke.json", "map-installed-smoke.json.stderr",
            "callback-inputs.json", "callback-producer.json", "callback-producer.json.stderr",
            "callback-consumer.json", "callback-consumer.json.stderr",
            "core-tests.log", "core-tests.log.stderr", "installed-cli.log", "installed-cli.log.stderr",
            "development-Gemfile.lock", "consumer-Gemfile.lock", "thistle.gem",
        ):
            with self.subTest(name=name):
                self.assertTrue(any(fnmatch.fnmatchcase("pkg/install-check-attempt/" + name, pattern)
                                    for pattern in patterns), name)


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
      fixture = "engine/tests/fixtures/models.json"
      expected = File.binread(File.join(env.fetch("SOURCE"), fixture))
      raise "Core fixture missing or changed" unless File.binread(File.join(options.fetch(:chdir), fixture)) == expected
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

CALLBACK_PRODUCER = r'''
require "json"
require "fileutils"
require "digest"
fixture, root, store = ARGV
raise "Callback producer arguments changed" unless ARGV.length == 3
raise "Callback input inside checkout" if [__FILE__, *ARGV].any? { |p| p.start_with?(ENV.fetch("SOURCE") + "/") }
raise "Wrong callback fixture" unless File.read(File.join(fixture, "booted_app.rb")) == "# callback boot\n"
raise "Missing callback records" unless File.read(File.join(fixture, "records.rb")) == "# callback records\n"
module Rails; end
FileUtils.mkdir_p(store)
File.write(File.join(store, "producer-pid"), Process.pid.to_s)
File.write("callback-producer-args.json", JSON.generate(ARGV))
puts JSON.generate("generation" => "callback-generation", "native_sha256" => "fake-native",
  "fixture_source_sha256" => Digest::SHA256.file(File.join(fixture, "records.rb")).hexdigest)
'''

CALLBACK_CONSUMER = r'''
require "json"
raise "Callback consumer arguments changed" unless ARGV.length == 2
raise "Callback consumer inherited Rails" if defined?(Rails) || defined?(ActiveRecord)
raise "Callback consumer inside checkout" if [__FILE__, *ARGV].any? { |p| p.start_with?(ENV.fetch("SOURCE") + "/") }
store, receipt = ARGV
raise "Callback producer did not exit into a fresh consumer" if File.read(File.join(store, "producer-pid")) == Process.pid.to_s
raise "Callback receipt changed" unless JSON.parse(File.read(receipt)).fetch("generation") == "callback-generation"
File.write("callback-consumer-args.json", JSON.generate(ARGV))
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
        self.write("engine/tests/fixtures/models.json", '{"models":[]}\n')
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

    def callback_inputs(self):
        inputs = {
            "test/fixtures/callbacks/booted_app.rb": "# callback boot\n",
            "test/fixtures/callbacks/records.rb": "# callback records\n",
            "map/test/installed_callback_producer.rb": CALLBACK_PRODUCER,
            "map/test/installed_callback_consumer.rb": CALLBACK_CONSUMER,
        }
        for name, content in inputs.items():
            self.write(name, content)
        return inputs

    def callback_attempt(self, name):
        # Separate synthetic attempts never inherit another subcase's receipts.
        self.worker = self.root / ("consumer-" + name)
        self.output = self.source / "pkg" / name
        self.installed = self.worker / "bundle/gems/thistle"
        (self.installed / "lib/thistle").mkdir(parents=True)
        self.output.mkdir(parents=True)
        for package in ("core.gem", "map.gem"):
            (self.output / package).write_text(package)
        (self.installed / "lib/thistle/callback_observer.rb").write_text("# installed callback payload\n")
        return self.callback_inputs()

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

    def test_core_known_answer_fixture_is_staged_and_hashed_before_contracts(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        relative = "engine/tests/fixtures/models.json"
        expected = (self.source / relative).read_bytes()
        self.assertEqual((self.worker / relative).read_bytes(), expected)
        self.assertEqual(self.read_json("core-fixture-inputs.json"), {
            relative: hashlib.sha256(expected).hexdigest()
        })
        self.assertEqual(self.read_json("installed-inputs.json")["core_fixture_inputs"],
                         self.read_json("core-fixture-inputs.json"))

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

    def test_legacy_payload_ignores_callback_source_and_keeps_prior_smoke(self):
        self.callback_inputs()
        self.write("lib/thistle/callback_observer.rb", "# source only\n")
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        report = self.read_json("report.json")
        self.assertEqual(report["callback_journey"], "not_applicable_to_selected_package")
        self.assertEqual(report["callback_fixture_inputs"], {})
        self.assertIsNone(report["callback_producer_receipt_sha256"])
        self.assertIsNone(report["callback_consumer_receipt_sha256"])
        self.assertFalse((self.output / "callback-producer.json").exists())
        self.assertEqual(json.loads((self.worker / "consumer-args.json").read_text()), [])

    def test_callback_payload_runs_separate_journey_without_changing_model_argv(self):
        source_inputs = self.callback_attempt("success")
        self.model_inputs()
        self.installed_model()
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        for name, args in (
            ("consumer-args.json", ["model-store", "model-producer.json"]),
            ("callback-producer-args.json", ["callback-fixture", "callback-source", "callback-store"]),
            ("callback-consumer-args.json", ["callback-store", "callback-producer.json"]),
        ):
            self.assertEqual(json.loads((self.worker / name).read_text()), [str(self.worker / arg) for arg in args])
        report = self.read_json("report.json")
        self.assertEqual(report["callback_journey"], "passed")
        expected = {}
        for path, content in source_inputs.items():
            staged = path.replace("test/fixtures/callbacks/", "callback-fixture/").removeprefix("map/test/")
            expected[staged] = hashlib.sha256(content.encode()).hexdigest()
        self.assertEqual(report["callback_fixture_inputs"], expected)
        self.assertEqual(self.read_json("callback-inputs.json"), expected)
        for key, name in (
            ("callback_producer_receipt_sha256", "callback-producer.json"),
            ("callback_consumer_receipt_sha256", "callback-consumer.json"),
        ):
            self.assertEqual(report[key], hashlib.sha256((self.output / name).read_bytes()).hexdigest())
        self.assertEqual(report["native_sha256"], self.read_json("native-observation.json")["native_sha256"])
        self.assertEqual(report["consumer_lock_sha256"], hashlib.sha256((self.output / "consumer-Gemfile.lock").read_bytes()).hexdigest())
        self.assertTrue((self.worker / "cli-ran").exists())

    def test_callback_payload_missing_inputs_stops_before_producer_and_cli(self):
        for index, missing in enumerate(self.callback_inputs()):
            with self.subTest(missing=missing):
                self.callback_attempt("missing-" + str(index))
                (self.source / missing).unlink()
                result = self.invoke()
                self.assert_stopped(result)
                self.assertFalse((self.output / "callback-producer.json").exists())
                self.assertFalse((self.output / "callback-consumer.json").exists())

    def test_callback_process_failures_retain_evidence_and_stop_dependents(self):
        for stage in ("producer", "consumer"):
            with self.subTest(stage=stage):
                self.callback_attempt("failed-" + stage)
                self.write("map/test/installed_callback_" + stage + ".rb",
                           "puts 'partial callback'; warn 'callback failed'; exit 7\n")
                result = self.invoke()
                self.assert_stopped(result)
                receipt = "callback-" + stage + ".json"
                self.assertEqual((self.output / receipt).read_text(), "partial callback\n")
                self.assertEqual((self.output / (receipt + ".stderr")).read_text(), "callback failed\n")
                self.assertEqual(len(self.read_json("callback-inputs.json")), 4)
                if stage == "producer":
                    self.assertFalse((self.output / "callback-consumer.json").exists())
                else:
                    self.assertEqual(self.read_json("callback-producer.json")["generation"], "callback-generation")

    def test_callback_receipt_refusals_prevent_cli_and_passing_report(self):
        cases = (
            ("producer-native", "producer", CALLBACK_PRODUCER.replace('"fake-native"', '"different-native"')),
            ("producer-fixture", "producer", CALLBACK_PRODUCER.replace(
                'Digest::SHA256.file(File.join(fixture, "records.rb")).hexdigest', '"0" * 64')),
            ("consumer-native", "consumer", CALLBACK_CONSUMER.replace('"fake-native"', '"different-native"')),
            ("consumer-status", "consumer", CALLBACK_CONSUMER.replace('"passed"', '"failed"')),
            ("producer-json", "producer", "puts 'invalid receipt'\n"),
            ("consumer-json", "consumer", "puts 'invalid receipt'\n"),
            ("input-change", "consumer", CALLBACK_CONSUMER + '\nFile.write(__FILE__, "changed")\n'),
        )
        for name, stage, code in cases:
            with self.subTest(name=name):
                self.callback_attempt(name)
                self.write("map/test/installed_callback_" + stage + ".rb", code)
                result = self.invoke()
                self.assert_stopped(result)
                self.assertTrue((self.output / ("callback-" + stage + ".json")).exists())
                if stage == "producer":
                    self.assertFalse((self.output / "callback-consumer.json").exists())


if __name__ == "__main__":
    unittest.main()
