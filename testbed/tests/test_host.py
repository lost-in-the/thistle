"""Harmless controller tests: actual Host/Runner logic, a fake Podman boundary.

No Rails, native load, gem install, database, container, or server is executed.
"""
import contextlib
import importlib.util
import io
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
        self.units = {}
        self.source_commit, self.source_tree = '1' * 40, '2' * 40
        self.tracked = ['testbed/host.py'] + [f'testbed/{name}/{path}' for name in ('app', 'control') for path in host.inventory(SOURCE / name)]

    def __call__(self, argv, seconds=30):
        if argv[0] == 'git':
            if 'rev-parse' in argv:
                return self.source_tree if argv[-1] == 'HEAD^{tree}' else self.source_commit
            if 'ls-files' in argv:
                return '\0'.join(self.tracked) + '\0'
            if 'diff' in argv:
                return ''
            raise AssertionError('Unexpected read-only git helper')
        self.calls.append(argv)
        if argv[0].endswith('systemctl'):
            unit = next(value for value in argv if value.endswith('.scope'))
            if 'stop' in argv:
                self.units[unit] = 'inactive'
                return ''
            phase = self.units.get(unit, 'not-found')
            if phase == 'not-found':
                raise host.HelperFailed(5, 'LoadState=not-found\nActiveState=inactive\n')
            return 'LoadState=loaded\nActiveState=' + phase + '\n'
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
        if command in ('start', 'stop', 'kill'):
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
                return json.dumps({'status': 'passed', 'peer': '127.0.0.1', 'transport': 'private-unix'})
            output = Path(self.config['instance']) / 'work' / args[-1].removeprefix('/work/')
            if self.results and 'producer' in args:
                host.write_json(output / 'producer.json', {'status': 'passed', 'saved': 'a' * 64, 'current': 'b' * 64})
            if self.results and 'consumer' in args:
                host.write_json(output / 'consumer.json', {'status': 'passed', 'saved': 'a' * 64, 'current': 'b' * 64, 'rails_free': True})
            if self.results and 'consumer' in args:
                host.write_json(output / 'oracle.json', {'saved': 'a' * 64, 'origin_id': 'c' * 64, 'order_id': 'd' * 64,
                    'source_sha256': host.digest(Path(self.config['instance']) / 'inputs/app/app/services/inspection.rb'),
                    'site_lines': [7, 8], 'site_count': 2})
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
        with host.private_open(credential) as stream:
            stream.write(b'private-placeholder-not-used')
        data = base / 'data'
        data.mkdir(mode=0o700)
        with host.private_open(data / 'auto.cnf') as stream:
            stream.write(b'[auto]\nserver-uuid=0fe59249-d501-11f1-964a-c4f5809f9f3d\n')
        self.config = {'instance': str(base / 'instance'), 'profile': host.PROFILE, 'ruby': '3.4.12',
            'image': host.IMAGE, 'server_uuid': '0fe59249-d501-11f1-964a-c4f5809f9f3d', 'mysql_data': str(data),
            'credentials': str(credential), 'dependency_home': '/dependencies', 'client_version': '3.4.9', 'host_port': 19292,
            'mysql2_extension_sha256': 'a' * 64, 'client_library_sha256': 'b' * 64, 'puma_version': '8.0.2',
            'mysql_image': 'sha256:' + 'c' * 64, 'mysqld': '/usr/sbin/mysqld', 'artifacts': {}, 'host_source': {'commit': '1' * 40, 'tree': '2' * 40}}
        self.config['map_candidate'] = {'source_sha': 'd' * 40, 'source_tree': 'd' * 40, 'sha256': 'e' * 64}
        dependencies = base / 'dependencies'
        dependencies.mkdir(mode=0o700)
        manifest = base / 'dependencies.json'
        host.write_json(manifest, {})
        transport = base / 'socat'
        with host.private_open(transport) as stream:
            stream.write(b'mocked transport; never executed')
        self.config.update(dependency_root=str(dependencies), dependency_manifest={'path': str(manifest), 'sha256': host.digest(manifest)},
                           host_socat={'path': str(transport), 'sha256': host.digest(transport)})
        defaults = base / 'defaults.json'
        host.write_json(defaults, {'specs': {}, 'files': {}})
        self.config['default_providers'] = {'path': str(defaults), 'sha256': host.digest(defaults)}
        self.config_path = base / 'config.json'
        host.write_json(self.config_path, self.config)
        self.fake = Podman(self.config)
        self.controller = host.Host(self.config_path, runner=self.fake)
        port = patch.object(self.controller, 'port_absent', return_value=True)
        port.start()
        self.addCleanup(port.stop)
        self.root = self.controller.root
        self.root.mkdir(mode=0o700)
        for name in ('inputs', 'work', 'logs', 'socket', 'mysql-tmp'):
            (self.root / name).mkdir(mode=0o700)
        (self.root / 'lock').touch(mode=0o600)
        for name in ('app', 'control'):
            host.private_tree(SOURCE / name, self.root / 'inputs' / name)
        (self.root / 'inputs/artifacts').mkdir(mode=0o700)
        with host.private_open(self.root / 'inputs/artifacts/Gemfile.lock') as stream:
            stream.write(b'mocked resolution')
        host.write_json(self.root / 'inputs/profile.json', {'dependency_manifest_sha256': host.digest(manifest),
                        'default_providers_sha256': self.config['default_providers']['sha256'],
                        'map_candidate': self.config['map_candidate'], 'host_socat': self.config['host_socat'],
                        'artifacts': {'Gemfile.lock': {'sha256': 'f' * 64}}})
        host.private_copy(manifest, self.root / 'inputs/dependencies.json')
        host.private_copy(defaults, self.root / 'inputs/default-providers.json')
        self.controller.save({'phase': 'STOPPED', 'containers': {}, 'initialized': False, 'attempts': [],
                              'instance_id': 'mock-instance', 'attempt_paths': {}, 'sessions': {}, 'source': self.controller.source_identity(), 'cache_key': 'unit-test-only', 'inputs': host.inventory(self.root / 'inputs')})

    @contextlib.contextmanager
    def admitted(self):
        original_write = host.write_json
        original_read = Path.read_text

        def write(path, value):
            original_write(path, value)
            if Path(path).name == 'admission.json' and 'token' in value:
                original_write(Path(path).parent / 'cohort-ready.json', {'token': value['token'], 'identity': {
                    'native': {'sha256': host.SELECTED['native.so']}, 'client': {'sha256': self.config['mysql2_extension_sha256']},
                    'client_library': {'sha256': self.config['client_library_sha256']}, 'lock': {'sha256': 'f' * 64}}})
            if Path(path).name == 'go.json':
                original_write(Path(path).parent / 'ready.json', {'token': value['token'], 'booted': True})
            if Path(path).name == 'admission.json' and Path(path).parent.parent == self.root / 'logs':
                token = Path(path).parent.name
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
            self.fake.units[state['access']['unit']] = 'active'
            host.write_json(self.controller.session_logs(state['token']) / 'host-endpoint.json', {'mocked_process_boundary': True})
            self.controller.save(state)

        with patch.object(host, 'write_json', side_effect=write), patch.object(Path, 'read_text', read), \
                patch.object(host.os, 'readlink', side_effect=readlink), patch.object(self.controller, 'spawn_guard'), \
                patch.object(self.controller, 'start_access', side_effect=start_access), patch.object(self.controller, 'access_identity'), \
                patch.object(self.controller, 'socket_identity', return_value={'mode': '0600'}), \
                patch.object(self.controller, 'port_absent', return_value=True), patch.object(self.controller, 'host_map_probe', return_value={'mocked': True}):
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
        self.assertEqual('STOPPED', self.controller.state()['phase'])
        self.assertEqual({}, self.fake.containers)

    def test_real_podman_expanded_cap_drop_serialization_is_accepted(self):
        expanded = ['CAP_CHOWN', 'CAP_DAC_OVERRIDE', 'CAP_FOWNER', 'CAP_FSETID', 'CAP_KILL',
                    'CAP_NET_BIND_SERVICE', 'CAP_SETFCAP', 'CAP_SETGID', 'CAP_SETPCAP', 'CAP_SETUID', 'CAP_SYS_CHROOT']
        def change(value):
            value['HostConfig']['CapDrop'] = expanded
            return value
        self.fake.inspect_change = change
        with self.admitted():
            self.controller.start()
            self.controller.stop()
        self.assertEqual('STOPPED', self.controller.state()['phase'])

    def test_explicit_cap_add_is_refused_even_with_drop_all(self):
        def change(value):
            value['HostConfig']['CapAdd'] = ['CAP_CHOWN']
            return value
        self.fake.inspect_change = change
        with self.assertRaises(host.Refused):
            self.controller.start()
        self.assertFalse((self.root / 'work/go.json').exists())
        self.assertFalse(any(call[1] in ('start', 'exec') for call in self.fake.calls))

    def test_incomplete_expanded_cap_drop_is_refused(self):
        def change(value):
            value['HostConfig']['CapDrop'] = ['CAP_' + name for name in host.DEFAULT_CAPABILITIES - {'SETUID'}]
            return value
        self.fake.inspect_change = change
        with self.assertRaises(host.Refused):
            self.controller.start()
        self.assertFalse((self.root / 'work/go.json').exists())
        self.assertFalse(any(call[1] in ('start', 'exec') for call in self.fake.calls))

    def test_failed_installed_cohort_preflight_never_starts_db_or_releases_go(self):
        original = host.read_json
        def read(path):
            value = original(path)
            if Path(path).name == 'cohort-ready.json':
                value['identity']['client_library']['sha256'] = '0' * 64
            return value
        with self.admitted(), patch.object(host, 'read_json', side_effect=read):
            with self.assertRaises(host.Refused):
                self.controller.start()
        self.assertEqual(1, len([call for call in self.fake.calls if call[1] == 'start']))  # confined preflight worker only
        self.assertFalse((self.root / 'work/go.json').exists())
        self.assertFalse(any(call[1] == 'exec' for call in self.fake.calls))
        self.assertEqual({}, self.fake.containers)

    def test_nonzero_effective_capability_is_refused_before_go(self):
        with self.admitted():
            original_read = Path.read_text
            def read(path, *args, **kwargs):
                if str(path).startswith('/proc/') and path.name == 'status':
                    return 'NoNewPrivs:\t1\nCapEff:\t0000000000000001\n'
                return original_read(path, *args, **kwargs)
            with patch.object(Path, 'read_text', read):
                with self.assertRaises(host.Refused):
                    self.controller.start()
        self.assertFalse((self.root / 'work/go.json').exists())
        self.assertFalse(any(call[1] == 'exec' for call in self.fake.calls))
        self.assertEqual({}, self.fake.containers)

    def test_stopped_start_test_stop_start_preserves_source_data_and_credentials(self):
        before_data = host.inventory(Path(self.config['mysql_data']))
        before_credentials = Path(self.config['credentials']).read_bytes()
        before_source = host.inventory(self.root / 'inputs')
        with self.admitted():
            self.controller.start(initialize_empty=True)
            attempt = self.controller.test()
            self.controller.stop()
            self.controller.verify_retained(self.controller.state()['token'])
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
        token = self.controller.state()['token']
        self.controller.verify_retained(token)
        bundle = self.root / self.controller.state()['sessions'][token]['sealed']['path']
        self.assertTrue((bundle / 'session/attempts' / attempt / 'failure.json').exists())

    def test_controlled_failure_and_incomplete_cleanup_remain_nonzero(self):
        with self.admitted():
            self.controller.start()
            self.fake.incomplete_cleanup = True
            with self.assertRaises(host.Refused):
                self.controller.test(inject_failure=True)
        self.assertEqual('FAILED', self.controller.state()['phase'])
        self.assertTrue(self.controller.state()['containers'])
        self.assertFalse(any('producer' in call for call in self.fake.calls))

    def test_old_corruption_remains_failed_without_poisoning_new_session(self):
        with self.admitted():
            self.controller.start()
            attempt = self.controller.test()
            old = self.controller.state()['token']
            self.controller.stop()
            index = self.root / self.controller.state()['sessions'][old]['sealed']['path'] / 'INDEX.json'
            self.assertNotIn('INDEX.json', host.read_json(index))
            (index.parent / 'session/attempts' / attempt / 'result.json').write_text('altered')
            with self.assertRaises(host.Refused):
                self.controller.verify_retained(old)
            self.controller.start()
            current = self.controller.state()['token']
            self.controller.test()
            self.controller.stop()
            self.controller.verify_retained(current)
            with self.assertRaises(host.Refused):
                self.controller.verify_retained(old)
        self.assertEqual('STOPPED', self.controller.state()['phase'])

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
            first_raw = host.inventory(self.root / 'work' / first_path)
            second = self.controller.test()
            state = self.controller.state()
            second_path = state['attempt_paths'][second]
            selected = host.read_json(self.root / 'work/sessions' / state['token'] / 'selected.json')
            self.assertNotEqual(first_path, second_path)
            self.assertEqual('/work/' + second_path + '/store', selected['store'])
            self.assertEqual(state['token'], selected['token'])
            self.assertEqual(first_raw, host.inventory(self.root / 'work' / first_path))
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

    def test_host_listener_must_be_in_the_admitted_scope(self):
        unit = 'thistle-los139-' + 'a' * 32 + '.scope'
        group = '/user.slice/' + unit
        files = {'memory.max': '134217728', 'memory.swap.max': '0', 'pids.max': '32',
                 'cpu.max': '100000 100000', 'cgroup.procs': '111', 'memory.peak': '1048576', 'pids.peak': '4'}
        def read(path, *args, **kwargs):
            if path.name in files:
                return files[path.name]
            if str(path) == '/proc/net/tcp':
                return 'header\n0: 0100007F:4B5C 00000000:0000 0A 0 0 0 0 0 77\n'
            raise AssertionError('Unexpected control-file read')
        with patch.object(self.controller, 'run', return_value=group), patch.object(Path, 'read_text', read), \
                patch.object(Path, 'iterdir', return_value=iter([Path('/proc/111/fd/3')])), \
                patch.object(host.os, 'readlink', return_value='socket:[77]'):
            self.assertEqual('0100007F:4B5C', self.controller.access_identity({'unit': unit})['owned_listener'])
        with patch.object(self.controller, 'run', return_value=group), patch.object(Path, 'read_text', read), \
                patch.object(Path, 'iterdir', return_value=iter([Path('/proc/111/fd/3')])), \
                patch.object(host.os, 'readlink', return_value='socket:[88]'):
            with self.assertRaises(host.Refused):
                self.controller.access_identity({'unit': unit})

    def test_host_side_probe_checks_exact_answer_and_generation(self):
        response = io.BytesIO(b'{"reference":"retained-order-1","quantities":[2,3]}')
        response.status = 200
        with patch.object(host.urllib.request, 'build_opener') as opener:
            opener.return_value.open.return_value = response
            result = self.controller.host_probe()
            request = opener.return_value.open.call_args.args[0]
            self.assertEqual('http://127.0.0.1:19292/orders/1', request.full_url)
            self.assertEqual('127.0.0.1:19292', request.host)
            self.assertNotIn('Host', request.headers)
            self.assertEqual('passed', result['status'])
        response = io.BytesIO(b'wrong generation')
        response.status = 200
        with patch.object(host.urllib.request, 'build_opener') as opener:
            opener.return_value.open.return_value = response
            with self.assertRaises(host.Refused):
                self.controller.host_probe('/map/', kind='find', oracle={'saved': 'a' * 64, 'origin_id': 'b' * 64})

    def test_controlled_failure_has_distinct_safe_code_and_releases_compute(self):
        with self.admitted():
            self.controller.start()
            with self.assertRaises(host.Refused):
                self.controller.test(inject_failure=True)
            attempt = self.controller.state()['attempts'][0]
            token = self.controller.state()['token']
            bundle = self.root / self.controller.state()['sessions'][token]['sealed']['path']
            report = host.read_json(bundle / 'session/attempts' / attempt / 'failure.json')
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
