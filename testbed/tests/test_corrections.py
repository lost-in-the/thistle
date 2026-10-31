"""R1 correction controls: actual controller, stubbed external process/FS reads."""
import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import threading
import unittest
from unittest.mock import patch

import test_host as support
host = support.host


class Corrections(unittest.TestCase):
    def setUp(self):
        self.fixture = support.LifecycleTest('runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.c = self.fixture.controller
        self.fake = self.fixture.fake
        self.root = self.fixture.root

    def test_not_loaded_exit5_and_inactive_access_cleanup_are_idempotent(self):
        unit = 'thistle-los139-' + 'a' * 32 + '.scope'
        with patch.object(self.c, 'port_absent', return_value=True):
            report = self.c.stop_access({'unit': unit})
            self.assertEqual('not-found', report['after']['LoadState'])
            self.fake.units[unit] = 'inactive'
            self.c.stop_access({'unit': unit})
        self.assertFalse(any('stop' in call for call in self.fake.calls))

    def test_unexpected_unit_error_and_reachable_port_refuse_cleanup(self):
        unit = 'thistle-los139-' + 'a' * 32 + '.scope'
        with patch.object(self.c, 'run', side_effect=host.HelperFailed(1, 'private error canary')):
            with self.assertRaises(host.Refused):
                self.c.stop_access({'unit': unit})
        with patch.object(self.c, 'port_absent', return_value=False):
            with self.assertRaises(host.Refused):
                self.c.stop_access({'unit': unit})
        with patch.object(self.c, 'run', side_effect=host.HelperFailed(5, 'LoadState=loaded\nActiveState=active\n')):
            with self.assertRaises(host.Refused):
                self.c.stop_access({'unit': unit})

    def test_scope_gc_during_stop_requires_structured_absence(self):
        unit = 'thistle-los139-' + 'a' * 32 + '.scope'
        self.fake.units[unit] = 'active'
        def run(argv, seconds=30):
            if 'stop' in argv:
                self.fake.units.pop(unit)
                raise host.HelperFailed(5, 'scope GC')
            return self.fake(argv, seconds)
        with patch.object(self.c, 'run', side_effect=run), patch.object(self.c, 'port_absent', return_value=True):
            self.assertEqual('not-found', self.c.stop_access({'unit': unit})['after']['LoadState'])

    def test_exact_external_removal_is_successful_absence(self):
        with self.fixture.admitted():
            self.c.start()
            app = self.c.state()['containers']['app']
            self.fake.containers.pop(app)
            self.c.stop()
        self.assertEqual('STOPPED', self.c.state()['phase'])
        self.assertEqual({}, self.fake.containers)

    def test_ownership_mismatch_never_stops_or_removes_other_resource(self):
        with self.fixture.admitted():
            self.c.start()
            app = self.c.state()['containers']['app']
            self.fake.containers[app]['Config']['Labels']['thistle.instance'] = 'another-instance'
            self.fake.calls.clear()
            with self.assertRaises(host.Refused):
                self.c.stop()
            mutations = [call for call in self.fake.calls if call[1] in ('stop', 'kill', 'rm') and call[-1] == app]
            self.assertEqual([], mutations)
            self.assertTrue(self.fake.containers[app]['State']['Running'])

    def test_failed_create_effect_is_discovered_without_start_or_go(self):
        def run(argv, seconds=30):
            result = self.fake(argv, seconds)
            if len(argv) > 1 and argv[1] == 'create' and 'thistle.role=app' in argv:
                raise host.HelperFailed(7, 'failed after create effect')
            return result
        with self.fixture.admitted(), patch.object(self.c, 'run', side_effect=run):
            with self.assertRaises(host.HelperFailed):
                self.c.start()
        self.assertEqual({}, self.fake.containers)
        self.assertFalse(any(call[1] in ('start', 'exec') for call in self.fake.calls))
        self.assertEqual('failed', self.c.state()['last_stop']['start_status'])

    def test_inspect_failure_preserves_failure_and_stop_can_recover(self):
        with self.fixture.admitted():
            self.c.start()
            app = self.c.state()['containers']['app']
            self.fake.fail = lambda args: args[0] == 'inspect' and args[1] == app
            with self.assertRaises(host.Refused):
                self.c.stop()
            self.assertIn(app, self.fake.containers)
            self.fake.fail = None
            self.c.stop()
        self.assertEqual('STOPPED', self.c.state()['phase'])

    def test_stop_writers_then_snapshot_then_remove_with_complete_custody(self):
        events = []
        original_run, original_retain = self.c.run, self.c.retain
        def run(argv, seconds=30):
            if len(argv) > 1 and argv[1] in ('stop', 'kill', 'rm'):
                events.append(argv[1])
            return original_run(argv, seconds)
        def retain(token):
            self.assertFalse(any(value['State']['Running'] for value in self.fake.containers.values()))
            events.append('snapshot')
            return original_retain(token)
        with self.fixture.admitted(), patch.object(self.c, 'run', side_effect=run), patch.object(self.c, 'retain', side_effect=retain):
            self.c.start()
            attempt = self.c.test()
            self.assertNotIn('snapshot', events)
            self.c.stop()
        self.assertLess(max(i for i, name in enumerate(events) if name == 'stop'), events.index('snapshot'))
        self.assertLess(events.index('snapshot'), events.index('rm'))
        state = self.c.state()
        bundle = self.root / state['sessions'][state['token']]['sealed']['path']
        self.c.verify_retained(state['token'])
        index = host.read_json(bundle / 'INDEX.json')
        self.assertNotIn('INDEX.json', index)
        for name in ('session/admission.json', 'session/cohort-ready.json', 'session/go.json', 'session/ready.json',
                     'session/source.json', 'logs/admission.json', 'logs/mysql-scratch.json', 'logs/internal-endpoint.json',
                     'logs/host-endpoint.json', 'logs/controller.json', 'STOP.json', 'SNAPSHOT.json'):
            self.assertIn(name, index)
        stop = host.read_json(bundle / 'STOP.json')
        self.assertTrue(stop['instance_absent'])
        self.assertEqual({attempt: 'passed'}, stop['attempt_outcomes'])
        self.assertIn('commit', stop['source'])
        self.assertIn('testbed/host.py', stop['source']['files'])

    def test_partial_retention_does_not_remove_compute_or_poison_retry(self):
        original = host.private_copy
        failed = False
        def copy(source, destination):
            nonlocal failed
            if not failed and '/retained/sessions/' in str(destination) and Path(source).name == 'source.json':
                failed = True
                raise OSError('stubbed one-shot copy failure')
            return original(source, destination)
        with self.fixture.admitted():
            self.c.start()
            self.c.test()
            self.fake.calls.clear()
            with patch.object(host, 'private_copy', side_effect=copy):
                with self.assertRaises(host.Refused):
                    self.c.stop()
            self.assertFalse(any(call[1] == 'rm' for call in self.fake.calls))
            self.assertTrue(self.fake.containers)
            self.assertFalse(any(value['State']['Running'] for value in self.fake.containers.values()))
            token = self.c.state()['token']
            partial = self.c.state()['sessions'][token]['custody_history'][0]['path']
            self.assertFalse((self.root / partial / 'INDEX.json').exists())
            self.c.stop()
            self.assertEqual('partial', self.c.state()['sessions'][token]['custody_history'][0]['status'])
            self.assertTrue((self.root / partial).exists())
            self.c.verify_retained(token)
        self.assertEqual({}, self.fake.containers)

    def test_shared_artifact_reference_not_one_copy_per_attempt_or_history_rehash(self):
        with self.fixture.admitted():
            self.c.start()
            self.c.test()
            self.c.test()
            first = self.c.state()['token']
            self.c.stop()
            reference = self.c.state()['shared_evidence']
            before = host.inventory(self.root / 'retained/blobs')
            with patch.object(self.c, 'verify_retained', side_effect=AssertionError('history scan')):
                self.c.start()
                self.c.test()
                self.c.stop()
            self.assertEqual(reference, self.c.state()['shared_evidence'])
            self.assertEqual(before, host.inventory(self.root / 'retained/blobs'))
            self.assertIn(first, self.c.state()['sessions'])

    def test_published_index_identity_is_checked_even_when_rows_still_match(self):
        with self.fixture.admitted():
            self.c.start()
            token = self.c.state()['token']
            self.c.test()
            self.c.stop()
        reference = self.c.state()['sessions'][token]['sealed']
        index = self.root / reference['path'] / 'INDEX.json'
        rows = host.read_json(index)
        index.write_text(json.dumps(rows, sort_keys=True, separators=(',', ':')))
        with self.assertRaises(host.Refused):
            self.c.verify_retained(token)

    def test_untracked_or_ignored_canonical_addition_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as name:
            source = Path(name) / 'canonical'
            source.mkdir(mode=0o700)
            for directory in ('app', 'control'):
                host.private_tree(support.SOURCE / directory, source / directory)
            host.private_copy(support.SOURCE / 'host.py', source / 'host.py')
            with patch.object(host, 'HERE', source):
                self.c.source_identity()
                (source / 'app/ignored-extra.rb').write_text('not declared canonical')
                with self.assertRaises(host.Refused):
                    self.c.source_identity()

    def test_atomic_publication_hides_partial_json_and_sets_private_modes(self):
        target = self.root / 'polled.json'
        started, finish = threading.Event(), threading.Event()
        original_open = host.private_open
        errors = []
        class Slow:
            def __init__(self, path): self.stream = original_open(path)
            def __enter__(self): return self
            def __exit__(self, *args): self.stream.close()
            def fileno(self): return self.stream.fileno()
            def flush(self): self.stream.flush()
            def write(self, data):
                self.stream.write(data[:1]); self.stream.flush(); started.set()
                self.assertion = finish.wait(2)
                self.stream.write(data[1:])
        def writer():
            try:
                with patch.object(host, 'private_open', side_effect=Slow):
                    host.write_json(target, {'complete': True})
            except Exception as error:
                errors.append(error)
        thread = threading.Thread(target=writer)
        thread.start()
        self.assertTrue(started.wait(2))
        try:
            self.assertFalse(target.exists())
            temporary = next(self.root.glob('.polled.json.*.tmp'))
            self.assertEqual(0o600, temporary.stat().st_mode & 0o777)
        finally:
            finish.set(); thread.join(2)
        self.assertEqual([], errors)
        self.assertEqual({'complete': True}, host.read_json(target))
        with self.assertRaises(FileExistsError):
            host.write_json(target, {'complete': False})
        self.assertEqual({'complete': True}, host.read_json(target))

    def test_bad_find_check_source_and_site_pages_do_not_pass_generation_only(self):
        oracle = {'saved': 'a' * 64, 'origin_id': 'b' * 64, 'source_sha256': 'c' * 64,
                  'site_count': 2, 'site_lines': [7, 8]}
        hidden = '<input value="' + oracle['saved'] + '">'
        for kind in ('find', 'source', 'links', 'incoming', 'check'):
            with self.subTest(kind=kind), self.assertRaises(host.Refused):
                host.check_map_page(kind, hidden + 'No matches', oracle)
        failed = hidden + '<pre class="check-data">' + json.dumps({'generation': oracle['saved'], 'integrity': 'failed'}) + '</pre>'
        with self.assertRaises(host.Refused):
            host.check_map_page('check', failed, oracle)
        good = failed.replace('"failed"', '"verified"')
        host.check_map_page('check', good, oracle)
        find = hidden + '<a data-result-link href="/source?id=' + oracle['origin_id'] + '&amp;generation=' + oracle['saved'] + '">Inspection#sites</a>'
        host.check_map_page('find', find, oracle)
        wrong_sites = hidden + oracle['origin_id'] + '<span class="constant-site"></span>' * 2
        wrong_sites += ''.join('<a href="/source?id=' + 'd' * 64 + '&amp;generation=' + oracle['saved'] + '#L' + str(line) + '">site</a>' for line in (7, 8))
        with self.assertRaises(host.Refused):
            host.check_map_page('links', wrong_sites, oracle)

    def test_real_constant_syntax_pre_is_not_check_json_on_links_or_incoming(self):
        oracle = {'saved': 'a' * 64, 'origin_id': 'b' * 64, 'source_sha256': 'c' * 64,
                  'site_count': 2, 'site_lines': [7, 8]}
        body = '<input value="' + oracle['saved'] + '">'
        # ConstantOccurrence#render's actual F05 shape, including its shared
        # check-data class. Literal syntax is not a serialized integrity result.
        for line, role in [(7, 'argument'), (8, 'value')]:
            body += '<div class="constant-site"><p class="ui">Recorded constant site · Line ' + str(line)
            body += ' · Role: ' + role + ' · Binding unknown.</p>'
            body += '<pre class="check-data" aria-label="Recorded constant syntax"><code>Order</code></pre>'
            body += '<p><a href="/source?id=' + oracle['origin_id'] + '&amp;generation=' + oracle['saved']
            body += '#L' + str(line) + '">Captured Source line ' + str(line) + '</a></p></div>'
        for kind in ('links', 'incoming'):
            with self.subTest(kind=kind):
                page = host.check_map_page(kind, body, oracle)
                self.assertEqual(2, page.site_count)
                self.assertEqual([], page.checks)
        labelled_json = '<pre class="check-data" aria-label="Recorded constant syntax">'
        labelled_json += json.dumps({'generation': oracle['saved'], 'integrity': 'verified'}) + '</pre>'
        with self.assertRaises(host.Refused):
            host.check_map_page('check', labelled_json, oracle)

    def test_final_index_failure_preserves_partial_custody_and_shared_identity(self):
        with self.fixture.admitted():
            self.c.start()
            self.c.test()
            token = self.c.state()['token']
            with patch.object(self.c, 'finish_retention', side_effect=OSError('stubbed final index failure')):
                with self.assertRaises(host.Refused):
                    self.c.stop()
            state = self.c.state()
            self.assertIn('shared_evidence', state)
            self.assertEqual('partial', state['sessions'][token]['custody_history'][0]['status'])
            self.assertNotIn('sealed', state['sessions'][token])
            self.assertIn('final-index', state['last_stop']['failures'])
            self.c.stop()
            self.assertEqual(2, len(self.c.state()['sessions'][token]['custody_history']))
            self.c.verify_retained(token)

    def test_failed_or_stopping_status_reports_stopped_resources_without_mutation(self):
        with self.fixture.admitted():
            self.c.start()
            self.fake.incomplete_cleanup = True
            with self.assertRaises(host.Refused):
                self.c.stop()
            for phase in ('FAILED', 'STOPPING'):
                state = self.c.state()
                state['phase'] = phase
                self.c.save(state)
                before = self.c.state_path.read_bytes()
                self.fake.calls.clear()
                report = self.c.status()
                self.assertEqual(phase, report['phase'])
                self.assertEqual(state['last_stop'], report['last_stop'])
                self.assertTrue(all(not entry['running'] for entry in report['observations'].values()))
                self.assertEqual(before, self.c.state_path.read_bytes())
                self.assertFalse(any(call[1] in ('start', 'stop', 'kill', 'rm') for call in self.fake.calls))

    def test_noop_stop_preserves_the_completed_stop_and_attempt_receipt(self):
        with self.fixture.admitted():
            self.c.start()
            attempt = self.c.test()
            self.c.stop()
            before = self.c.state_path.read_bytes()
            self.c.stop()
            self.assertEqual(before, self.c.state_path.read_bytes())
            self.assertEqual({attempt: 'passed'}, self.c.state()['last_stop']['attempt_outcomes'])

    def test_occupied_host_port_refuses_before_any_create_or_start_effect(self):
        with self.fixture.admitted(), patch.object(self.c, 'port_absent', return_value=False):
            with self.assertRaises(host.Refused):
                self.c.start()
        self.assertFalse(any(call[1] in ('create', 'start', 'exec') for call in self.fake.calls))
        self.assertEqual('STOPPED', self.c.state()['phase'])

    def test_auth_provider_has_a_private_directory_and_exact_staged_identity(self):
        name = 'caching_sha2_password.so'
        source = self.c.inputs / 'artifacts' / name
        with host.private_open(source) as stream:
            stream.write(b'metadata fixture; not a native binary')
        expected = {'sha256': host.digest(source), 'size': source.stat().st_size}
        with self.assertRaises(host.Refused):
            self.c.prepare_client_auth({name: dict(expected, sha256='0' * 64)})
        self.assertFalse((self.c.inputs / 'client-auth').exists())
        result = self.c.prepare_client_auth({name: expected})
        self.assertEqual(dict(expected, path='/input/client-auth/' + name), result)
        directory = self.c.inputs / 'client-auth'
        self.assertEqual(0o700, directory.stat().st_mode & 0o777)
        self.assertEqual([name], [path.name for path in directory.iterdir()])
        self.assertEqual(0o600, (directory / name).stat().st_mode & 0o777)
        self.assertEqual(expected['sha256'], host.digest(directory / name))

    def test_app_and_exec_both_use_the_declared_auth_provider_directory(self):
        state = self.c.state()
        state['token'] = 'a' * 32
        self.c.save(state)
        identifier = self.c.create('app', state['token'])
        created = self.fake.calls[-1]
        self.assertIn('MARIADB_PLUGIN_DIR=/input/client-auth', created)
        self.c.exec_ruby(identifier, 'probe', '/work/sessions/' + state['token'] + '/http.sock')
        executed = self.fake.calls[-1]
        self.assertIn('MARIADB_PLUGIN_DIR=/input/client-auth', executed)
        self.assertIn('LD_LIBRARY_PATH=/input/artifacts', created)
        self.assertIn('LD_LIBRARY_PATH=/input/artifacts', executed)

    def test_prefixed_immutable_image_id_matches_actual_bare_inspection(self):
        original = self.c.run
        def run(argv, seconds=30):
            if argv[1:3] == ['image', 'inspect'] and argv[-1] == self.fixture.config['mysql_image']:
                return json.dumps([{'Id': 'c' * 64, 'RepoDigests': [], 'Os': 'linux', 'Architecture': 'amd64'}])
            return original(argv, seconds)
        with patch.object(self.c, 'run', side_effect=run):
            state = self.c.preflight()
        self.assertEqual('c' * 64, state['image_ids']['db'])
        self.assertFalse(any(call[1] == 'create' for call in self.fake.calls))

    def test_stale_declared_source_identity_stops_before_any_compute_helper(self):
        self.c.config['host_source']['commit'] = 'f' * 40
        with self.assertRaises(host.Refused):
            self.c.start()
        self.assertEqual([], self.fake.calls)

    def test_active_disk_monitor_roots_exclude_historic_sessions(self):
        roots = self.c.active_disk_roots('a' * 32)
        self.assertEqual(self.root / 'work/sessions' / ('a' * 32), roots[0])
        self.assertEqual([self.root / 'work/gems', self.root / 'work/loaded'], roots[1:])
        self.assertNotIn(self.root / 'work', roots)

    def test_four_parallel_host_requests_include_semantic_pages_and_assets(self):
        barrier = threading.Barrier(4)
        calls, lock = [], threading.Lock()
        oracle = {'saved': 'a' * 64, 'origin_id': 'b' * 64, 'order_id': 'c' * 64}
        state = self.c.state()
        state['access'] = {'unit': 'thistle-los139-' + 'a' * 32 + '.scope'}
        self.c.save(state)
        def fetch(path, **kwargs):
            with lock: calls.append((path, kwargs))
            barrier.wait(timeout=2)
            return {'mocked_readonly_HTTP': path}
        with patch.object(self.c, 'host_probe', side_effect=fetch), patch.object(self.c, 'access_identity', return_value={'mocked_peaks': True}):
            report = self.c.host_map_probe(oracle)
        self.assertEqual(4, report['parallel_workers'])
        self.assertEqual(8, len(calls))
        self.assertEqual({'find', 'source', 'links', 'incoming', 'check'}, {kw['kind'] for _, kw in calls if kw['kind']})
        self.assertEqual(3, sum(kw['asset_type'] is not None for _, kw in calls))
        self.assertTrue(all(path.startswith('/map/') for path, _ in calls))

    def test_no_per_connection_exec_and_socket_mode_identity_is_required(self):
        command = self.c.access_command({'token': 'a' * 32})
        self.assertIn('UNIX-CONNECT:' + str(self.c.http_socket('a' * 32)), command)
        self.assertNotIn('EXEC:', ' '.join(command))
        self.assertNotIn('podman', ' '.join(command))
        self.assertNotIn('_relay', ' '.join(command))
        directory = self.c.http_socket('a' * 32).parent
        directory.mkdir(mode=0o700, parents=True)
        regular = self.c.http_socket('a' * 32)
        regular.write_text('wrong object')
        with self.assertRaises(host.Refused):
            self.c.socket_identity('a' * 32)
