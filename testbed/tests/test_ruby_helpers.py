"""Stdlib Ruby controller helpers only, explicitly no framework/product runtime."""
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
        self.assertEqual(5, len(report['checks']))
        self.assertIn('no SQL/framework/product runtime', report['scope'])
