"""Harmless controller tests: actual Host/Runner logic, a fake Podman boundary.

No Rails, native load, gem install, database, container, or server is executed.
"""
import contextlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

SOURCE = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('reusable_host', SOURCE / 'host.py')
host = importlib.util.module_from_spec(spec)
spec.loader.exec_module(host)


class Podman:
    def __init__(self, config):
        self.config = config
        self.calls = []
        self.containers = {}
        self.fail = None
        self.inspect_change = lambda value: value
        self.results = True
        self.incomplete_cleanup = False

    def __call__(self, argv, seconds=30):
        self.calls.append(argv)
        args = argv[1:]
        if self.fail and self.fail(args):
            raise host.Refused('mocked helper failed')
        command = args[0]
        if command == 'info':
            return json.dumps({'host': {'security': {'rootless': True}, 'cgroupVersion': 'v2'}})
        if command == 'image':
            image = args[-1]
            return json.dumps([{'Id': image, 'Os': 'linux', 'Architecture': 'amd64', 'RepoDigests': [image]}])
        if command == 'create':
            identifier = f'{len(self.containers) + 1:064x}'
            labels = {}
            for i, arg in enumerate(args):
                if arg == '--label':
                    key, value = args[i + 1].split('=', 1)
                    labels[key] = value
            mounts = []
            for i, arg in enumerate(args):
                if arg == '--mount':
                    options = args[i + 1].split(',')
                    mounts.append({'Source': options[1][4:], 'Destination': options[2][4:], 'RW': options[3] == 'rw', 'Type': 'bind'})
            self.containers[identifier] = {
                'Id': identifier, 'Image': args[args.index('--entrypoint') + 2],
                'Config': {'Labels': labels, 'User': f'{os.getuid()}:{os.getgid()}'},
                'HostConfig': {'ReadonlyRootfs': True, 'NetworkMode': 'none', 'Memory': host.LIMITS['memory'],
                    'MemorySwap': host.LIMITS['memory'], 'PidsLimit': 256, 'NanoCpus': 2_000_000_000,
                    'SecurityOpt': ['no-new-privileges'], 'CapDrop': ['ALL'], 'PortBindings': {}},
                'Mounts': mounts, 'State': {'Running': False, 'Pid': len(self.containers) + 700}}
            return identifier
        if command == 'inspect':
            return json.dumps([self.inspect_change(self.containers[args[1]])])
        if command in ('start', 'stop'):
            self.containers[args[-1]]['State']['Running'] = command == 'start'
            return args[-1]
        if command == 'rm':
            if not self.incomplete_cleanup:
                self.containers.pop(args[-1])
            return args[-1]
        if command == 'ps':
            if args[args.index('--filter') + 1].startswith('label='):
                return json.dumps([{'Id': key} for key in self.containers])
            identifier = args[args.index('--filter') + 1].split('=')[1]
            return json.dumps([{'Id': identifier}] if identifier in self.containers else [])
        if command == 'exec':
            if 'probe' in args:
                return json.dumps({'status': 'passed', 'peer': '127.0.0.1'})
            output = Path(self.config['instance']) / 'work' / args[-1].removeprefix('/work/')
            if self.results and 'producer' in args:
                host.write_json(output / 'producer.json', {'status': 'passed', 'saved': 'a' * 64, 'current': 'b' * 64})
            if self.results and 'consumer' in args:
                host.write_json(output / 'consumer.json', {'status': 'passed', 'saved': 'a' * 64, 'current': 'b' * 64, 'rails_free': True})
            return ''
        raise AssertionError(f'Unexpected mocked operation {command}')


class LifecycleTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        base = Path(self.temp.name)
        base.chmod(0o700)
        private = base / 'private'
        private.mkdir(mode=0o700)
        credential = private / 'database.json'
        credential.write_text('private-placeholder-not-used')
        credential.chmod(0o600)
        data = base / 'data'
        data.mkdir(mode=0o700)
        (data / 'auto.cnf').write_text('[auto]\nserver-uuid=0fe59249-d501-11f1-964a-c4f5809f9f3d\n')
        self.config = {'instance': str(base / 'instance'), 'profile': host.PROFILE, 'ruby': '3.4.12',
            'image': host.IMAGE, 'server_uuid': '0fe59249-d501-11f1-964a-c4f5809f9f3d', 'mysql_data': str(data),
            'credentials': str(credential), 'dependency_home': '/dependencies', 'client_version': '3.4.9', 'host_port': 19292,
            'mysql2_extension_sha256': 'a' * 64, 'client_library_sha256': 'b' * 64, 'puma_version': '8.0.2',
            'mysql_image': 'sha256:' + 'c' * 64, 'mysqld': '/usr/sbin/mysqld', 'artifacts': {}}
        dependencies = base / 'dependencies'
        dependencies.mkdir(mode=0o700)
        manifest = base / 'dependencies.json'
        host.write_json(manifest, {})
        transport = base / 'socat'
        transport.write_text('mocked transport; never executed')
        self.config.update(dependency_root=str(dependencies), dependency_manifest={'path': str(manifest), 'sha256': host.digest(manifest)},
                           host_socat={'path': str(transport), 'sha256': host.digest(transport)})
        self.config_path = base / 'config.json'
        host.write_json(self.config_path, self.config)
        self.fake = Podman(self.config)
        self.controller = host.Host(self.config_path, runner=self.fake)
        self.root = self.controller.root
        self.root.mkdir(mode=0o700)
        for name in ('inputs', 'work', 'logs', 'socket', 'mysql-tmp'):
            (self.root / name).mkdir(mode=0o700)
        (self.root / 'lock').touch(mode=0o600)
        for name in ('app', 'control'):
            shutil.copytree(SOURCE / name, self.root / 'inputs' / name)
        (self.root / 'inputs/artifacts').mkdir(mode=0o700)
        (self.root / 'inputs/artifacts/Gemfile.lock').write_text('mocked resolution')
        host.write_json(self.root / 'inputs/profile.json', {'dependency_manifest_sha256': host.digest(manifest)})
        self.controller.save({'phase': 'STOPPED', 'containers': {}, 'initialized': False, 'attempts': [],
                              'instance_id': 'mock-instance', 'attempt_paths': {}, 'cache_key': 'unit-test-only', 'inputs': host.inventory(self.root / 'inputs')})

    @contextlib.contextmanager
    def admitted(self):
        original_write = host.write_json
        original_read = Path.read_text

        def write(path, value):
            original_write(path, value)
            if Path(path).name == 'go.json':
                original_write(self.root / 'work/ready.json', {'token': value['token'], 'booted': True})
            if Path(path).name.endswith('-admission.json'):
                token = Path(path).name.removesuffix('-admission.json')
                original_write(self.root / 'mysql-tmp' / f'write-probe-{token}.json',
                               {'uid': os.getuid(), 'path': '/mysql-tmp', 'status': 'passed'})

        def read(path, *args, **kwargs):
            if str(path).startswith('/proc/') and path.name == 'status':
                return 'NoNewPrivs:\t1\nCapEff:\t0000000000000000\n'
            if str(path).startswith('/proc/') and path.name == 'limits':
                return 'Max file size  33554432  33554432  bytes\nMax cpu time  600  600  seconds\n'
            if str(path).startswith('/proc/') and path.name == 'cgroup':
                return '0::/mock\n'
            if str(path).startswith('/proc/') and path.name == 'mountinfo':
                return '1 0 1:1 / / ro - overlay overlay ro\n'
            if str(path).startswith('/sys/fs/cgroup/mock/'):
                return {'memory.max': str(host.LIMITS['memory']), 'memory.swap.max': '0',
                        'pids.max': '256', 'cpu.max': '200000 100000'}[path.name]
            return original_read(path, *args, **kwargs)

        def readlink(path):
            parts = str(path).split('/')
            return f'{parts[-1]}:[{parts[2]}]'

        def start_access(state):
            state['access'] = {'unit': f'thistle-los139-{state["token"]}.scope'}
            self.controller.save(state)

        with patch.object(host, 'write_json', side_effect=write), patch.object(Path, 'read_text', read), \
                patch.object(host.os, 'readlink', side_effect=readlink), patch.object(self.controller, 'spawn_guard'), \
                patch.object(self.controller, 'start_access', side_effect=start_access), patch.object(self.controller, 'access_identity'), \
                patch.object(self.controller, 'host_probe'), patch.object(self.controller, 'stop_access'):
            yield

    def test_failed_preflight_helper_never_creates_starts_or_releases_go(self):
        for predicate in (lambda args: args[0] == 'info', lambda args: args[0] == 'image'):
            with self.subTest(predicate=predicate):
                self.fake.calls.clear()
                self.fake.fail = predicate
                with self.assertRaises(host.Refused):
                    self.controller.start()
                self.assertFalse(any(call[1] in ('create', 'start', 'exec') for call in self.fake.calls))
                self.assertFalse((self.root / 'work/go.json').exists())

    def test_missing_invalid_or_exceptional_preflight_cannot_start(self):
        for response in ('', '{}', 'null', '[]', 'false'):
            with self.subTest(response=response):
                with patch.object(self.controller, 'podman', return_value=response) as run:
                    with self.assertRaises((ValueError, TypeError, KeyError, host.Refused)):
                        self.controller.start()
                    self.assertTrue(all(call.args[0] in ('ps', 'info') for call in run.call_args_list))
                self.assertFalse((self.root / 'work/go.json').exists())
        with patch.object(self.controller, 'preflight', side_effect=RuntimeError('stubbed helper exception')):
            with self.assertRaises(RuntimeError):
                self.controller.start()
        self.assertEqual([], self.fake.calls)

    def test_uuid_source_and_credential_drift_refuse_before_helpers(self):
        modifications = [self.root / 'inputs/app/config/routes.rb', Path(self.config['mysql_data']) / 'auto.cnf']
        for path in modifications:
            old = path.read_bytes()
            path.write_text('drift')
            with self.assertRaises(host.Refused):
                self.controller.start()
            self.assertEqual([], self.fake.calls)
            path.write_bytes(old)
        Path(self.config['credentials']).chmod(0o644)
        with self.assertRaises(host.Refused):
            self.controller.start()
        self.assertTrue(all(call[1] == 'ps' for call in self.fake.calls))

    def test_admission_mismatch_stops_created_compute_without_go(self):
        def change(value):
            value['HostConfig']['NetworkMode'] = 'host'
            return value
        self.fake.inspect_change = change
        with self.assertRaises(host.Refused):
            self.controller.start()
        self.assertFalse((self.root / 'work/go.json').exists())
        self.assertFalse(any(call[1] in ('start', 'exec') for call in self.fake.calls))
        # Cleanup mismatch is a truthful failure, never an invented STOPPED.
        self.assertEqual('FAILED', self.controller.state()['phase'])

    def test_stopped_start_test_stop_start_preserves_source_data_and_credentials(self):
        before_data = host.inventory(Path(self.config['mysql_data']))
        before_credentials = Path(self.config['credentials']).read_bytes()
        before_source = host.inventory(self.root / 'inputs')
        with self.admitted():
            self.controller.start(initialize_empty=True)
            attempt = self.controller.test()
            self.controller.verify_retained(attempt)
            self.controller.stop()
            self.assertEqual('STOPPED', self.controller.status()['phase'])
            self.assertEqual({}, self.fake.containers)
            with self.assertRaises(host.Refused):
                self.controller.start(initialize_empty=True)
            self.controller.start()
            self.controller.stop()
        self.assertEqual(before_data, host.inventory(Path(self.config['mysql_data'])))
        self.assertEqual(before_credentials, Path(self.config['credentials']).read_bytes())
        self.assertEqual(0o600, Path(self.config['credentials']).stat().st_mode & 0o777)
        self.assertEqual(before_source, host.inventory(self.root / 'inputs'))

    def test_missing_producer_result_stops_consumer_and_retains_failure(self):
        self.fake.results = False
        with self.admitted():
            self.controller.start()
            with self.assertRaises(FileNotFoundError):
                self.controller.test()
        self.assertFalse(any('consumer' in call for call in self.fake.calls))
        self.assertEqual({}, self.fake.containers)
        attempt = self.controller.state()['attempts'][0]
        self.controller.verify_retained(attempt)
        self.assertTrue((self.root / 'retained' / attempt / 'raw/failure.json').exists())

    def test_controlled_failure_and_incomplete_cleanup_remain_nonzero(self):
        with self.admitted():
            self.controller.start()
            self.fake.incomplete_cleanup = True
            with self.assertRaises(host.Refused):
                self.controller.test(inject_failure=True)
        self.assertEqual('FAILED', self.controller.state()['phase'])
        self.assertTrue(self.controller.state()['containers'])
        self.assertFalse(any('producer' in call for call in self.fake.calls))

    def test_retained_index_excludes_self_and_corruption_blocks_success(self):
        with self.admitted():
            self.controller.start()
            attempt = self.controller.test()
            index = self.root / 'retained' / attempt / 'INDEX.json'
            self.assertNotIn('INDEX.json', host.read_json(index))
            (index.parent / 'raw/result.json').write_text('altered')
            with self.assertRaises(host.Refused):
                self.controller.stop()
        self.assertEqual({}, self.fake.containers)  # failure still stops compute
        self.assertEqual('FAILED', self.controller.state()['phase'])

    def test_status_stopped_performs_no_writes_or_mutations(self):
        before = host.inventory(self.root)
        self.assertEqual('STOPPED', self.controller.status()['phase'])
        self.assertEqual(before, host.inventory(self.root))
        self.assertTrue(all(call[1] == 'ps' for call in self.fake.calls))

    def test_commands_are_env_i_and_constrained_without_checkout_or_secret_values(self):
        with self.admitted():
            self.controller.start()
            self.controller.stop()
        creates = [call for call in self.fake.calls if call[1] == 'create']
        self.assertEqual(2, len(creates))
        for call in creates:
            for flag in ('--pull=never', '--read-only', '--network=none', '--cap-drop=ALL', '--unsetenv-all', '--timeout'):
                self.assertIn(flag, call)
            self.assertNotIn(str(SOURCE.parent), ' '.join(call))
            self.assertNotIn('private-placeholder-not-used', ' '.join(call))
        execute = next(call for call in self.fake.calls if call[1] == 'exec')
        self.assertEqual(['/usr/bin/env', '-i'], execute[3:5])
        self.assertNotIn('RUBYOPT', ' '.join(execute))
        self.assertNotIn('-I', execute)
        db = next(call for call in creates if '--tmpdir=/mysql-tmp' in call)
        self.assertIn(f'type=bind,src={self.root / "mysql-tmp"},dst=/mysql-tmp,rw', db)
        self.assertIn('/control/db-entrypoint.sh', db)
        self.assertNotIn('--tmpdir=/var/lib/mysql', db)

    def test_each_attempt_selects_its_own_store_and_preserves_older_selection(self):
        with self.admitted():
            self.controller.start()
            first = self.controller.test()
            first_path = self.controller.state()['attempt_paths'][first]
            first_raw = host.inventory(self.root / 'retained' / first)
            second = self.controller.test()
            state = self.controller.state()
            second_path = state['attempt_paths'][second]
            selected = host.read_json(self.root / 'work/sessions' / state['token'] / 'selected.json')
            self.assertNotEqual(first_path, second_path)
            self.assertEqual('/work/' + second_path + '/store', selected['store'])
            self.assertEqual(state['token'], selected['token'])
            self.assertEqual(first_raw, host.inventory(self.root / 'retained' / first))
            self.controller.stop()

    def test_host_access_is_loopback_bounded_and_has_no_db_forward(self):
        state = {'token': 'a' * 32, 'containers': {'app': 'b' * 64}}
        command = self.controller.access_command(state)
        self.assertIn('TCP4-LISTEN:19292,bind=127.0.0.1,reuseaddr,fork,max-children=8', command)
        self.assertIn('--property=MemoryMax=134217728', command)
        self.assertIn('--property=TasksMax=32', command)
        self.assertIn('--kill-after=5s', command)
        self.assertNotIn('3306', ' '.join(command))
        self.assertNotIn('0.0.0.0', ' '.join(command))

    def test_controlled_failure_has_distinct_safe_code_and_releases_compute(self):
        with self.admitted():
            self.controller.start()
            with self.assertRaises(host.Refused):
                self.controller.test(inject_failure=True)
            attempt = self.controller.state()['attempts'][0]
            report = host.read_json(self.root / 'retained' / attempt / 'raw/failure.json')
            self.assertEqual('CONTROLLED_FAILURE', report['code'])
            self.assertEqual('test-before-producer', report['step'])
            self.assertNotIn('private-placeholder-not-used', json.dumps(report))
            self.assertEqual({}, self.fake.containers)
            self.assertEqual('STOPPED', self.controller.state()['phase'])


class FilesystemAndRunnerTest(unittest.TestCase):
    def test_disk_monitor_tolerates_only_missing_ephemeral_entries(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / 'file').write_text('hello')
            original = Path.lstat
            def missing(path):
                if path.name == 'file':
                    raise FileNotFoundError()
                return original(path)
            with patch.object(Path, 'lstat', missing):
                self.assertEqual(0, host.disk_bytes(root))
            with patch.object(Path, 'lstat', side_effect=PermissionError()):
                with self.assertRaises(PermissionError):
                    host.disk_bytes(root)

    def test_runner_propagates_nonzero_and_caps_output_without_secret_env(self):
        with tempfile.TemporaryDirectory() as directory:
            runner = host.Runner(directory)
            # Harmless stdlib subprocesses only; no candidate code/dependencies.
            with self.assertRaises(host.Refused):
                runner([host.sys.executable, '-c', 'raise SystemExit(7)'], seconds=2)
            with patch.dict(os.environ, {'RUBYOPT': 'secret-canary', 'BUNDLE_GEMFILE': 'secret-canary'}):
                output = runner([host.sys.executable, '-c', 'import os; print(os.environ.get("RUBYOPT")); print(os.environ.get("BUNDLE_GEMFILE"))'], seconds=2)
                self.assertEqual('None\nNone\n', output)
            with patch.dict(host.LIMITS, output=128):
                with self.assertRaises(host.Refused):
                    runner([host.sys.executable, '-c', 'print("x" * 1024)'], seconds=2)
            before = list(Path(directory).iterdir())
            runner.readonly = True
            self.assertEqual('ok\n', runner([host.sys.executable, '-c', 'print("ok")'], seconds=2))
            self.assertEqual(before, list(Path(directory).iterdir()))


if __name__ == '__main__':
    unittest.main()
