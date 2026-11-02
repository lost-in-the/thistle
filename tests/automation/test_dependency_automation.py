"""Cheap policy invariants; official Renovate semantics are checked by the JS probe."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]


class DependencyAutomationTests(unittest.TestCase):
    def test_fixture_filter_cannot_be_or_bypassed_or_replace_preset_hygiene(self):
        config = json.loads((ROOT / 'renovate.json').read_text())
        self.assertEqual(config['includePaths'], ['!testbed/**'])
        self.assertNotIn('ignorePaths', config)
        self.assertEqual(config['extends'], ['config:recommended'])

    def test_ecosystems_have_one_explicit_proposal_owner(self):
        config = json.loads((ROOT / 'renovate.json').read_text())
        self.assertCountEqual(config['enabledManagers'],
                              ['bundler', 'cargo', 'dockerfile', 'rust-toolchain'])
        # Check the two existing YAML ownership declarations without introducing
        # a YAML dependency into the hash-locked notes environment.
        dependabot = (ROOT / '.github/dependabot.yml').read_text()
        self.assertCountEqual(re.findall(r'package-ecosystem:\s*(\S+)', dependabot),
                              ['github-actions', 'pip'])
        for ecosystem, directory in [('github-actions', '/'), ('pip', '/.github')]:
            self.assertRegex(dependabot, rf'package-ecosystem: {re.escape(ecosystem)}\n'
                                        rf'    directory: {re.escape(directory)}\n')

    def test_security_proposals_require_review_and_no_hidden_overrides(self):
        config = json.loads((ROOT / 'renovate.json').read_text())
        self.assertIs(config['automerge'], False)
        self.assertEqual(config['vulnerabilityAlerts'], {'enabled': True, 'automerge': False})
        # New rules/presets/manager overrides need an explicit policy revision;
        # otherwise they could silently undo ownership or review requirements.
        self.assertEqual(set(config), {'$schema', 'extends', 'enabledManagers',
                                       'includePaths', 'automerge', 'vulnerabilityAlerts'})


if __name__ == '__main__':
    unittest.main()
