"""Keep later feature contracts off a selected historical package arm."""
import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("qualifier", ROOT / "tools/qualify_baseline.py")
qualifier = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(qualifier)


class QualificationJourneyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.source, self.output, self.consumer = [root / name for name in ("source", "output", "consumer")]
        for path in (self.source / "map/test", self.output, self.consumer):
            path.mkdir(parents=True)
        self.smoke = self.source / "map/test/installed_smoke.rb"
        self.smoke.write_text("# selected arm's smoke\n")

    def invoke(self, files):
        return qualifier.installed_smoke(self.source, self.output, Path("/ruby"),
                                         self.consumer, {"GEM_HOME": "/isolated"}, files)

    def model_fixture(self):
        fixture = self.source / "test/fixtures/models"
        fixture.mkdir(parents=True)
        for name in ("booted_app.rb", "records.rb"):
            (fixture / name).write_text("# harmless fixture\n")
        (self.source / "map/test/installed_model_producer.rb").write_text("# producer\n")

    def test_precreated_log_directory_is_allowed_but_attempt_receipts_are_preserved(self):
        log = self.output / "qualification.log"
        log.write_bytes(b"caller log\n")
        qualifier.prepare_output(self.output)
        identity = self.output / "build-identity.json"
        identity.write_bytes(b"retained failed attempt\n")
        with self.assertRaisesRegex(FileExistsError, "fresh output directory"):
            qualifier.prepare_output(self.output)
        self.assertEqual(identity.read_bytes(), b"retained failed attempt\n")
        self.assertEqual(log.read_bytes(), b"caller log\n")

    def test_historical_arm_uses_its_own_smoke_without_model_files_or_arguments(self):
        with patch.object(qualifier, "run_logged") as run:
            smoke, inputs, receipt = self.invoke({"lib/thistle.rb": "historical"})
        self.assertEqual(smoke.read_bytes(), self.smoke.read_bytes())
        self.assertEqual(run.call_args.args[0], [Path("/ruby"), smoke])
        self.assertEqual(run.call_count, 1)
        self.assertEqual((inputs, receipt), ({}, None))
        self.assertFalse((self.output / "model-fixture").exists())

    def test_model_package_runs_producer_then_fresh_smoke_with_bound_inputs(self):
        self.model_fixture()
        with patch.object(qualifier, "run_logged") as run:
            smoke, inputs, receipt = self.invoke({"lib/thistle/model_observer.rb": "candidate"})
        producer, consumer = run.call_args_list
        self.assertEqual(producer.args[0][1], self.output / "installed_model_producer.rb")
        self.assertEqual(consumer.args[0], [Path("/ruby"), smoke, self.output / "model-store", receipt])
        self.assertEqual(set(inputs), {"installed_model_producer.rb", "model-fixture/booted_app.rb", "model-fixture/records.rb"})
        self.assertTrue(all(qualifier.sha(self.output / path) == digest for path, digest in inputs.items()))
        self.assertEqual(consumer.kwargs, {"cwd": self.consumer, "env": {"GEM_HOME": "/isolated"}})

    def test_missing_model_fixture_fails_instead_of_downgrading_to_legacy_smoke(self):
        with patch.object(qualifier, "run_logged") as run:
            with self.assertRaises(FileNotFoundError):
                self.invoke({"lib/thistle/model_observer.rb": "candidate"})
        run.assert_not_called()

    def test_producer_failure_stops_dependent_smoke(self):
        self.model_fixture()
        with patch.object(qualifier, "run_logged", side_effect=subprocess.CalledProcessError(7, "producer")) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                self.invoke({"lib/thistle/model_observer.rb": "candidate"})
        self.assertEqual(run.call_count, 1)

    def callback_fixture(self):
        fixture = self.source / "test/fixtures/callbacks"
        fixture.mkdir(parents=True)
        for name in ("booted_app.rb", "records.rb"):
            (fixture / name).write_text("# harmless callback fixture\n")
        for name in ("installed_callback_producer.rb", "installed_callback_consumer.rb"):
            (self.source / "map/test" / name).write_text("# separate callback journey\n")

    def callbacks(self, files):
        return qualifier.installed_callbacks(self.source, self.output, Path("/ruby"),
                                              self.consumer, {"GEM_HOME": "/isolated"}, files)

    def test_callback_applicability_keeps_frozen_and_model_only_arms_unchanged(self):
        for files in ({}, {"lib/thistle/model_observer.rb": "selected"}):
            with patch.object(qualifier, "run_logged") as run:
                self.assertEqual(self.callbacks(files), ({}, None, None))
            run.assert_not_called()
        self.assertFalse((self.output / "callback-fixture").exists())

    def test_callback_package_uses_separate_producer_and_fresh_consumer(self):
        self.callback_fixture()
        with patch.object(qualifier, "run_logged") as run:
            inputs, receipt, result = self.callbacks({"lib/thistle/callback_observer.rb": "candidate"})
        producer, consumer = run.call_args_list
        self.assertEqual(producer.args[0], [Path("/ruby"), self.output / "installed_callback_producer.rb",
            self.output / "callback-fixture", self.output / "callback-source", self.output / "callback-store"])
        self.assertEqual(consumer.args[0], [Path("/ruby"), self.output / "installed_callback_consumer.rb",
            self.output / "callback-store", receipt])
        self.assertEqual(consumer.args[1], result)
        self.assertEqual(len(inputs), 4)
        self.assertTrue(all(qualifier.sha(self.output / path) == digest for path, digest in inputs.items()))
        self.assertEqual(consumer.kwargs, {"cwd": self.consumer, "env": {"GEM_HOME": "/isolated"}})

    def test_missing_callback_input_refuses_without_downgrading(self):
        with patch.object(qualifier, "run_logged") as run:
            with self.assertRaises(FileNotFoundError):
                self.callbacks({"lib/thistle/callback_observer.rb": "candidate"})
        run.assert_not_called()

    def test_callback_failure_propagates_and_stops_dependent_work(self):
        self.callback_fixture()
        with patch.object(qualifier, "run_logged", side_effect=subprocess.CalledProcessError(9, "producer")) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                self.callbacks({"lib/thistle/callback_observer.rb": "candidate"})
        self.assertEqual(run.call_count, 1)


if __name__ == "__main__":
    unittest.main()
