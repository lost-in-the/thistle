"""Stdlib/Bundler introspection helpers; no framework/product runtime or setup."""
import json
import os
from pathlib import Path
import subprocess
import unittest


class RubyControllerHelpers(unittest.TestCase):
    def test_stdlib_only_controller_helpers(self):
        source = Path(__file__).with_name('ruby_controller_test.rb')
        result = subprocess.run(['ruby', str(source)], stdin=subprocess.DEVNULL, capture_output=True,
                                env={key: os.environ[key] for key in ('PATH', 'HOME') if key in os.environ},
                                timeout=10, check=False)
        self.assertEqual(0, result.returncode, result.stderr.decode())
        report = json.loads(result.stdout)
        self.assertEqual('passed', report['status'])
        self.assertIn('auth_provider_static_vs_loaded_mapping_directory_and_hash', report['checks'])
        self.assertIn('cold_lock_projection_without_setup_resolution_or_framework', report['checks'])
        self.assertIn('no SQL/framework/product runtime', report['scope'])
