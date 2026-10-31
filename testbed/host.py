#!/usr/bin/env python3
"""Repository-only reusable Rails host; stdlib controller, rootless Podman.

Five public commands. Candidate execution is always a separately admitted phase.
The subprocess boundary is injectable so controller tests never launch containers.
"""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import selectors
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import time
import uuid
import urllib.request

HERE = Path(__file__).resolve().parent
PROFILE = 'public-rails71-compatibility-v1'
IMAGE = 'f377fb86ef51f1b4b31787dc58131ad453fe306e58b36296f29e76a98487c520'
SELECTED = {
    'core.gem': '469a6966b0cfb6f5b307fca52af206d8ce32aa5bf53052fda2cf03a7bce4b942',
    'native.so': '4bee13087b17eb7aeb0e7ef606c7c0879d817e309e6acb2a09d520bd4c5f888e',
    'core.gemspec': '34949a0a21a1d1b8f84219d8bdd1b198e9eba5ffb2ced01ef70136b261351a08',
    'puma.gem': 'c8ed871dfbbe66448ea9ffd46692342d9804d4071522b52b5331b7b6e7b686fb',
    'libmariadb.so.3': 'a373e8e8216e180e5dca24a4da6dbe7db34cc520c0693fc29319a37953a58fb2',
}
MIB = 1024 * 1024
LIMITS = {'memory': 2 * 1024 * MIB, 'pids': 256, 'nano_cpus': 2_000_000_000,
          'lease': 900, 'file': 32 * MIB, 'output': 8 * MIB, 'work': 512 * MIB}
# Podman may serialize --cap-drop=ALL as its expanded default-capability set.
# Actual zero CapEff/NoNewPrivs is independently checked on every running PID.
DEFAULT_CAPABILITIES = {'CHOWN', 'DAC_OVERRIDE', 'FOWNER', 'FSETID', 'KILL', 'NET_BIND_SERVICE',
                        'SETFCAP', 'SETGID', 'SETPCAP', 'SETUID', 'SYS_CHROOT'}


class Refused(Exception):
    """A bounded, sanitized failure. Never include candidate stderr or secrets."""


def require(condition, label):
    if not condition:
        raise Refused(label)


def digest(path):
    with open(path, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def regular(path, private=False):
    path = Path(path)
    info = path.lstat()
    require(stat.S_ISREG(info.st_mode), 'Expected regular file')
    if private:
        require(stat.S_IMODE(info.st_mode) == 0o600 and info.st_uid == os.getuid(), 'Private file mode/owner')
    return info


def private_dir(path):
    info = Path(path).lstat()
    require(stat.S_ISDIR(info.st_mode) and stat.S_IMODE(info.st_mode) == 0o700
            and info.st_uid == os.getuid(), 'Private directory mode/owner')


def read_json(path):
    regular(path)
    require(Path(path).stat().st_size <= LIMITS['output'], 'JSON input too large')
    with open(path, encoding='utf-8') as stream:
        return json.load(stream)


def write_json(path, value):
    data = json.dumps(value, sort_keys=True, indent=2).encode()
    require(len(data) <= LIMITS['output'], 'JSON output too large')
    with open(path, 'xb') as stream:
        os.chmod(path, 0o600)
        stream.write(data)


def replace_json(path, value):
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex)
    write_json(temporary, value)
    os.replace(temporary, path)


def inventory(root, ephemeral=False):
    """No symlink traversal. Only disappearing ephemeral entries tolerate ENOENT."""
    rows = {}
    for base, dirs, files in os.walk(root, followlinks=False, onerror=lambda error: (_ for _ in ()).throw(error)):
        for name in dirs + files:
            path = Path(base) / name
            try:
                info = path.lstat()
                require(not stat.S_ISLNK(info.st_mode), 'Symlink in retained tree')
                if stat.S_ISREG(info.st_mode):
                    rows[str(path.relative_to(root))] = {'size': info.st_size, 'sha256': digest(path)}
                else:
                    require(stat.S_ISDIR(info.st_mode) or (ephemeral and stat.S_ISSOCK(info.st_mode)), 'Special retained file')
            except FileNotFoundError:
                if not ephemeral:
                    raise
    return rows


def disk_bytes(root):
    total = 0
    for base, _, files in os.walk(root, onerror=lambda error: (_ for _ in ()).throw(error)):
        for name in files:
            try:
                info = (Path(base) / name).lstat()
                require(not stat.S_ISLNK(info.st_mode), 'Symlink in work directory')
                total += info.st_size
            except FileNotFoundError:
                pass  # Work files may disappear while the process runs.
    return total


class Runner:
    """No shell, inherited Ruby/Bundler env, terminal, or unbounded capture."""
    def __init__(self, log_root, disk_root=None):
        self.logs = Path(log_root)
        self.disk_root = disk_root
        self.sequence = 0
        self.readonly = False

    def __call__(self, argv, seconds=30):
        self.sequence += 1
        log = self.logs / f'helper-{self.sequence:04d}-{uuid.uuid4().hex}.log'
        env = {key: os.environ[key] for key in ('PATH', 'HOME', 'XDG_RUNTIME_DIR', 'DBUS_SESSION_BUS_ADDRESS') if key in os.environ}
        # Podman's rootless client needs its local HOME/runtime directory. Neither
        # value nor directory is passed or mounted into candidate processes.
        def limits():
            resource.setrlimit(resource.RLIMIT_FSIZE, (LIMITS['file'], LIMITS['file']))
            resource.setrlimit(resource.RLIMIT_CPU, (seconds + 5, seconds + 5))
        with contextlib.ExitStack() as stack:
            stream = None if self.readonly else stack.enter_context(open(log, 'xb'))
            if stream:
                os.chmod(log, 0o600)
            process = subprocess.Popen(argv, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                       env=env, start_new_session=True, preexec_fn=limits)
            selector = stack.enter_context(selectors.DefaultSelector())
            selector.register(process.stdout, selectors.EVENT_READ)
            output = bytearray()
            deadline = time.monotonic() + seconds
            try:
                while selector.get_map():
                    require(time.monotonic() < deadline, 'Helper deadline exceeded')
                    for key, _ in selector.select(timeout=0.05):
                        chunk = os.read(key.fileobj.fileno(), 65536)
                        if not chunk:
                            selector.unregister(key.fileobj)
                            continue
                        require(len(output) + len(chunk) <= LIMITS['output'], 'Helper output limit')
                        output.extend(chunk)
                        if stream:
                            stream.write(chunk)
                            stream.flush()
                    if self.disk_root:
                        require(disk_bytes(self.disk_root) <= LIMITS['work'], 'Work disk limit')
                process.wait(timeout=max(0.01, deadline - time.monotonic()))
                require(process.returncode == 0, 'Helper failed (private log retained)')
            except BaseException:
                if process.poll() is None:
                    os.killpg(process.pid, signal.SIGTERM)
                    try:
                        process.wait(timeout=2)
                    except subprocess.TimeoutExpired:
                        os.killpg(process.pid, signal.SIGKILL)
                        process.wait()
                raise
            finally:
                process.stdout.close()
        return output.decode('utf-8')


class Host:
    def __init__(self, config_path, runner=None):
        self.config_path = Path(config_path).absolute()
        regular(self.config_path, private=True)
        private_dir(self.config_path.parent)
        self.config = read_json(self.config_path)
        self.root = Path(self.config['instance'])
        require(self.root.is_absolute() and self.root == self.root.resolve(), 'Instance path must be canonical')
        self.inputs = self.root / 'inputs'
        self.work = self.root / 'work'
        self.logs = self.root / 'logs'
        self.state_path = self.root / 'state.json'
        self.run = runner or Runner(self.logs, self.work)
        require(self.config['profile'] == PROFILE and self.config['ruby'] == '3.4.12', 'Wrong compatibility profile')
        require(self.config['image'].removeprefix('sha256:') == IMAGE, 'Wrong selected runtime image')
        require(self.config['client_version'] == '3.4.9', 'Public Connector/C version required')
        require(re.fullmatch(r'[0-9a-f-]{36}', self.config['server_uuid']), 'Expected server UUID')
        for key in ('mysql2_extension_sha256', 'client_library_sha256'):
            require(re.fullmatch(r'[0-9a-f]{64}', self.config[key]), 'Exact client identity required')
        require(self.config['puma_version'] == '8.0.2', 'Exact Puma archive profile required')
        require(re.fullmatch(r'[0-9a-f]{40}', self.config['map_candidate']['source_sha'])
                and re.fullmatch(r'[0-9a-f]{40}', self.config['map_candidate']['source_tree'])
                and re.fullmatch(r'[0-9a-f]{64}', self.config['map_candidate']['sha256']), 'Exact integration-owner Map binding required')
        require(self.config['dependency_home'] == '/dependencies', 'Exact prepared dependency mount required')
        require(type(self.config['host_port']) is int and 1024 <= self.config['host_port'] <= 65535, 'Explicit loopback port required')
        require(re.fullmatch(r'(?:[a-zA-Z0-9./_-]+@)?sha256:[0-9a-f]{64}', self.config['mysql_image']), 'Immutable MySQL image required')
        require(re.fullmatch(r'/[a-zA-Z0-9_/-]+', self.config['mysqld']), 'Absolute mysqld path required')

    def state(self):
        return read_json(self.state_path)

    def save(self, state):
        replace_json(self.state_path, state)

    def validate_inputs(self):
        private_dir(self.root)
        credential = Path(self.config['credentials'])
        regular(credential, private=True)
        private_dir(credential.parent)
        require(credential.name == 'database.json' and list(credential.parent.iterdir()) == [credential], 'Dedicated database credential directory required')
        require(not credential.is_relative_to(self.root), 'Credentials must be outside retained evidence')
        data = Path(self.config['mysql_data'])
        require(data.is_absolute() and data == data.resolve() and data.is_dir(), 'Retained MySQL data path')
        regular(data / 'auto.cnf')
        # auto.cnf is non-secret server identity, not a password/options file.
        uuid_line = f'server-uuid={self.config["server_uuid"]}'
        require(uuid_line in (data / 'auto.cnf').read_text().splitlines(), 'Retained UUID drift')
        for key in ('root', 'inputs', 'work', 'logs'):
            if key != 'root':
                private_dir(getattr(self, key))
        return credential

    def validate_dependencies(self):
        root = Path(self.config['dependency_root'])
        manifest = Path(self.config['dependency_manifest']['path'])
        regular(manifest)
        require(digest(manifest) == self.config['dependency_manifest']['sha256'], 'Dependency manifest drift')
        require(root.is_absolute() and root == root.resolve(), 'Prepared dependency directory required')
        require(inventory(root) == read_json(manifest), 'Installed dependency bytes drift')
        socat = Path(self.config['host_socat']['path'])
        regular(socat)
        require(socat.is_absolute() and socat == socat.resolve() and digest(socat) == self.config['host_socat']['sha256'], 'Host transport identity drift')

    def prepare(self):
        require(not self.root.exists(), 'Instance already exists; no reset/reinitialization')
        require(self.root.parent.exists(), 'Create private instance parent explicitly')
        os.mkdir(self.root, 0o700)
        for path in (self.inputs, self.work, self.logs, self.root / 'socket', self.root / 'mysql-tmp'):
            os.mkdir(path, 0o700)
        (self.root / 'lock').touch(mode=0o600)
        # Only canonical app/control files enter execution. No checkout mount.
        try:
            self.validate_inputs()
            self.validate_dependencies()
            for name in ('app', 'control'):
                source = HERE / name
                inventory(source)
                shutil.copytree(source, self.inputs / name)
            os.mkdir(self.inputs / 'artifacts', 0o700)
            artifacts = {}
            require(set(self.config['artifacts']) == set(SELECTED) | {'map.gem', 'Gemfile.lock'}, 'Exact artifact set required')
            for name, item in self.config['artifacts'].items():
                source = Path(item['path'])
                regular(source)
                actual = {'sha256': digest(source), 'size': source.stat().st_size}
                require(actual == {k: item[k] for k in ('sha256', 'size')}, 'Artifact identity mismatch')
                if name in SELECTED:
                    require(actual['sha256'] == SELECTED[name], 'Selected artifact mismatch')
                if name == 'map.gem':
                    require(actual['sha256'] == self.config['map_candidate']['sha256'], 'Selected Map candidate mismatch')
                shutil.copyfile(source, self.inputs / 'artifacts' / name)
                artifacts[name] = actual
            require(artifacts['native.so']['size'] == 6124976, 'Native size mismatch')
            profile = {k: self.config[k] for k in ('profile', 'ruby', 'dependency_home', 'server_uuid',
                       'mysql2_extension_sha256', 'client_library_sha256', 'client_version', 'puma_version')}
            profile['artifacts'] = artifacts
            profile['map_candidate'] = self.config['map_candidate']
            profile['dependency_manifest_sha256'] = self.config['dependency_manifest']['sha256']
            shutil.copyfile(self.config['dependency_manifest']['path'], self.inputs / 'dependencies.json')
            profile['host_socat'] = self.config['host_socat']
            write_json(self.inputs / 'profile.json', profile)
            # Key includes exact artifacts, lock, image/OS/arch and ABI assertion;
            # the observed ABI is checked inside the worker before any connect.
            cache = {'artifacts': artifacts, 'dependencies': profile['dependency_manifest_sha256'],
                     'image': IMAGE, 'os': 'linux', 'arch': 'x86_64', 'ruby_abi': '3.4.0'}
            state = {'phase': 'STOPPED', 'profile': PROFILE, 'inputs': inventory(self.inputs),
                     'cache_key': hashlib.sha256(json.dumps(cache, sort_keys=True).encode()).hexdigest(),
                     'containers': {}, 'instance_id': uuid.uuid4().hex, 'initialized': False, 'attempts': []}
            state['attempt_paths'] = {}
            self.save(state)
        except BaseException:
            # Preserve failed prepare effects; never remove/reuse partial inputs.
            write_json(self.root / 'prepare-failed.json', {'status': 'failed', 'effects_retained': True})
            raise

    def podman(self, *args, seconds=30):
        return self.run(['podman', *map(str, args)], seconds=seconds)

    def inspect(self, identifier):
        value = json.loads(self.podman('inspect', identifier))
        require(isinstance(value, list) and len(value) == 1 and isinstance(value[0], dict), 'Invalid container inspection')
        require(value[0].get('Id') == identifier, 'Container identity substituted')
        return value[0]

    def preflight(self):
        self.validate_inputs()
        self.validate_dependencies()
        state = self.state()
        require(inventory(self.inputs) == state['inputs'], 'Source/artifact/lock drift')
        require(read_json(self.inputs / 'profile.json')['dependency_manifest_sha256'] == self.config['dependency_manifest']['sha256'], 'Prepared dependency cohort changed')
        for name in ('app', 'control'):
            require(inventory(HERE / name) == inventory(self.inputs / name), 'Canonical source changed since prepare')
        require(state['phase'] == 'STOPPED' and not state['containers'], 'Stop previous compute before start')
        require(not self.compute(state), 'Unrecorded compute still exists')
        info = json.loads(self.podman('info', '--format', 'json'))
        require(info['host']['security']['rootless'] is True, 'Rootless Podman required')
        require(info['host']['cgroupVersion'] == 'v2', 'Enforced cgroup v2 required')
        state['image_ids'] = {}
        for role, image in (('app', self.config['image']), ('db', self.config['mysql_image'])):
            result = json.loads(self.podman('image', 'inspect', image))
            require(len(result) == 1 and result[0]['Os'] == 'linux' and result[0]['Architecture'] == 'amd64', 'Image platform mismatch')
            if image == self.config['image']:
                require(result[0]['Id'].removeprefix('sha256:') == IMAGE, 'Runtime image substituted')
            else:
                require(image in result[0]['RepoDigests'] or image == result[0]['Id'], 'MySQL image digest mismatch')
            state['image_ids'][role] = result[0]['Id']
        return state

    def compute(self, state):
        result = json.loads(self.podman('ps', '-a', '--no-trunc', '--filter',
                                       f'label=thistle.instance={state["instance_id"]}', '--format', 'json'))
        require(isinstance(result, list), 'Invalid compute inventory')
        for row in result:
            require(isinstance(row, dict) and re.fullmatch(r'[0-9a-f]{64}', row.get('Id', '')), 'Invalid compute identity')
        return result

    def mounts(self, role):
        if role == 'db':
            return {self.config['mysql_data']: ('/var/lib/mysql', True),
                    str(self.root / 'mysql-tmp'): ('/mysql-tmp', True),
                    str(self.inputs / 'control/db-entrypoint.sh'): ('/control/db-entrypoint.sh', False),
                    str(self.root / 'socket'): ('/socket', True)}
        return {str(self.inputs): ('/input', False), str(self.work): ('/work', True),
                self.config['dependency_root']: ('/dependencies', False),
                str(self.root / 'socket'): ('/socket', False),
                str(Path(self.config['credentials']).parent): ('/private', False)}

    def create(self, role, token):
        image = self.config['mysql_image'] if role == 'db' else self.config['image']
        args = ['create', '--pull=never', '--name', f'thistle-los139-{token}-{role}',
                '--label', f'thistle.los139={token}', '--read-only', '--network=none',
                '--label', f'thistle.instance={self.state()["instance_id"]}', '--label', f'thistle.role={role}',
                '--cap-drop=ALL', '--security-opt=no-new-privileges', '--userns=keep-id',
                '--user', f'{os.getuid()}:{os.getgid()}', '--memory', str(LIMITS['memory']),
                '--memory-swap', str(LIMITS['memory']), '--cpus=2', '--pids-limit=256',
                '--ulimit', f'fsize={LIMITS["file"]}:{LIMITS["file"]}', '--ulimit', 'cpu=600:600',
                '--timeout', str(LIMITS['lease']), '--log-driver=none', '--unsetenv-all',
                '--workdir', '/work' if role == 'app' else '/var/lib/mysql']
        for source, (target, writable) in self.mounts(role).items():
            require(',' not in source and ':' not in source, 'Unsupported mount path')
            args += ['--mount', f'type=bind,src={source},dst={target},{"rw" if writable else "ro"}']
        if role == 'app':
            command = ['/usr/bin/env', '-i', 'PATH=/usr/local/bin:/usr/bin:/bin', 'HOME=/work',
                       'TMPDIR=/work/tmp', 'RAILS_ENV=test', 'LD_LIBRARY_PATH=/input/artifacts',
                       'ruby', '/input/control/run.rb', 'host']
        else:
            command = ['/bin/sh', '/control/db-entrypoint.sh', str(os.getuid()), token,
                       self.config['mysqld'], '--no-defaults', '--datadir=/var/lib/mysql', '--tmpdir=/mysql-tmp',
                       '--socket=/socket/mysql.sock', '--pid-file=/socket/mysql.pid',
                       '--log-error=/socket/mysql.log', '--skip-networking', '--mysqlx=OFF',
                       '--skip-log-bin', '--innodb-buffer-pool-size=134217728']
        identifier = self.podman(*args, '--entrypoint', command[0], image, *command[1:]).strip()
        require(re.fullmatch(r'[0-9a-f]{64}', identifier), 'Missing created container identity')
        return identifier

    def prove(self, identifier, role, token, running):
        observed = self.inspect(identifier)
        host = observed['HostConfig']
        require(observed['Config']['Labels'].get('thistle.los139') == token, 'Container ownership mismatch')
        require(observed['Config']['Labels'].get('thistle.instance') == self.state()['instance_id'], 'Instance ownership mismatch')
        require(observed['Image'] == self.state()['image_ids'][role], 'Actual container image changed')
        require(observed['State']['Running'] is running, 'Actual compute state differs')
        require(host['ReadonlyRootfs'] is True and host['NetworkMode'] == 'none', 'Root/network isolation absent')
        require(not host.get('Privileged') and not host.get('PortBindings'), 'Privileged/published port refused')
        require(not any(observed.get('NetworkSettings', {}).get('Ports', {}).values()), 'Published image port refused')
        require(host['Memory'] == LIMITS['memory'] and host['MemorySwap'] == LIMITS['memory'], 'Memory/swap unenforced')
        require(host['PidsLimit'] == LIMITS['pids'] and host['NanoCpus'] == LIMITS['nano_cpus'], 'PID/CPU unenforced')
        dropped = {cap.removeprefix('CAP_') for cap in host['CapDrop']}
        require('no-new-privileges' in host['SecurityOpt'] and not host.get('CapAdd')
                and ('ALL' in dropped or DEFAULT_CAPABILITIES <= dropped), 'Privileges not dropped')
        actual = {m['Source']: (m['Destination'], m['RW']) for m in observed['Mounts'] if m['Type'] == 'bind'}
        require(actual == self.mounts(role), 'Bind mount topology mismatch')
        require(all(m['Type'] == 'bind' for m in observed['Mounts']), 'Unexpected image/anonymous volume')
        require(observed['Config']['User'] == f'{os.getuid()}:{os.getgid()}', 'User mismatch')
        if running:
            pid = observed['State']['Pid']
            require(type(pid) is int and pid > 0, 'Actual PID absent')
            namespaces = {name: os.readlink(f'/proc/{pid}/ns/{name}') for name in ('pid', 'net', 'mnt', 'user')}
            for name in ('pid', 'net', 'mnt', 'user'):
                require(namespaces[name] != os.readlink(f'/proc/self/ns/{name}'), 'Host namespace shared')
            status = Path(f'/proc/{pid}/status').read_text()
            require('NoNewPrivs:\t1' in status and 'CapEff:\t0000000000000000' in status, 'Actual process privileges differ')
            limits = Path(f'/proc/{pid}/limits').read_text()
            require(re.search(r'Max file size\s+33554432\s+33554432\s+bytes', limits), 'Actual file limit differs')
            require(re.search(r'Max cpu time\s+600\s+600\s+seconds', limits), 'Actual CPU limit differs')
            groups = Path(f'/proc/{pid}/cgroup').read_text().splitlines()
            require(len(groups) == 1 and groups[0].startswith('0::/'), 'Actual cgroup v2 missing')
            group = groups[0][3:]
            require('..' not in Path(group).parts, 'Invalid cgroup path')
            cgroot = Path('/sys/fs/cgroup') / group.lstrip('/')
            actual_limits = {name: (cgroot / name).read_text().strip() for name in ('memory.max', 'memory.swap.max', 'pids.max', 'cpu.max')}
            require(actual_limits['memory.max'] == str(LIMITS['memory']) and actual_limits['memory.swap.max'] == '0'
                    and actual_limits['pids.max'] == str(LIMITS['pids']), 'Actual cgroup limits differ')
            quota, period = actual_limits['cpu.max'].split()
            require(quota != 'max' and int(quota) == 2 * int(period), 'Actual cgroup CPU limit differs')
            mounts = Path(f'/proc/{pid}/mountinfo').read_text().splitlines()
            roots = [line.split() for line in mounts if line.split()[4] == '/']
            require(len(roots) == 1 and 'ro' in roots[0][5].split(','), 'Actual root mount is writable')
            return {'inspect': observed, 'namespaces': namespaces, 'pid': pid}
        return {'inspect': observed}

    def exec_ruby(self, identifier, script, *args, seconds=60):
        return self.podman('exec', identifier, '/usr/bin/env', '-i', 'PATH=/usr/local/bin:/usr/bin:/bin',
                           'HOME=/work', 'TMPDIR=/work/tmp', 'RAILS_ENV=test', 'GEM_HOME=/work/gems',
                           'LD_LIBRARY_PATH=/input/artifacts',
                           f'GEM_PATH=/work/gems:{self.config["dependency_home"]}',
                           'ruby', '/input/control/run.rb', script, *args, seconds=seconds)

    def access_command(self, state):
        # socat owns the listener/fork/pump. The tiny fixed Ruby adapter only
        # bridges stdin/stdout into this worker's loopback; no generic proxy API.
        relay = shlex.join([sys.executable, str(HERE / 'host.py'), '_relay',
                            '--relay-cid', state['containers']['app']])
        relay = relay.replace('\\', '\\\\').replace(',', '\\,').replace(':', '\\:')
        return ['/usr/bin/systemd-run', '--user', '--scope', '--quiet', '--unit', f'thistle-los139-{state["token"]}',
                '--property=MemoryMax=134217728', '--property=MemorySwapMax=0', '--property=TasksMax=32',
                '--property=CPUQuota=100%', '/usr/bin/timeout', '--kill-after=5s', str(LIMITS['lease']) + 's',
                self.config['host_socat']['path'], '-T', '15',
                f'TCP4-LISTEN:{self.config["host_port"]},bind=127.0.0.1,reuseaddr,fork,max-children=8', f'EXEC:{relay}']

    def access_identity(self, access):
        unit = access['unit']
        require(re.fullmatch(r'thistle-los139-[0-9a-f]{32}\.scope', unit), 'Access unit ownership refused')
        group = self.run(['/usr/bin/systemctl', '--user', 'show', unit, '--property=ControlGroup', '--value']).strip()
        require(group.startswith('/') and '..' not in Path(group).parts and unit in Path(group).parts, 'Access cgroup identity absent')
        root = Path('/sys/fs/cgroup') / group.lstrip('/')
        limits = {key: (root / key).read_text().strip() for key in ('memory.max', 'memory.swap.max', 'pids.max', 'cpu.max')}
        require(limits['memory.max'] == '134217728' and limits['memory.swap.max'] == '0'
                and limits['pids.max'] == '32', 'Host access resource limits absent')
        quota, period = limits['cpu.max'].split()
        require(quota != 'max' and int(quota) == int(period), 'Host access CPU unbounded')
        pids = (root / 'cgroup.procs').read_text().split()
        require(0 < len(pids) <= 32 and all(pid.isdecimal() for pid in pids), 'Host access compute absent')
        inodes = set()
        for pid in pids:
            try:
                for fd in Path(f'/proc/{pid}/fd').iterdir():
                    try:
                        target = os.readlink(fd)
                        if target.startswith('socket:['):
                            inodes.add(target[8:-1])
                    except FileNotFoundError:
                        pass
            except FileNotFoundError:
                pass
        address = f'0100007F:{self.config["host_port"]:04X}'
        listeners = [row.split() for row in Path('/proc/net/tcp').read_text().splitlines()[1:]]
        require(any(row[1] == address and row[3] == '0A' and row[9] in inodes for row in listeners), 'Host listener socket not owned by admitted scope')
        return {'unit': unit, 'cgroup': group, 'limits': limits, 'owned_listener': address}

    def host_probe(self, path='/orders/1', expected_generation=None):
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        # Probe the advertised URL as a browser would, without substituting its
        # Host header. Both Rails and Map must accept this actual loopback host.
        request = urllib.request.Request(f'http://127.0.0.1:{self.config["host_port"]}{path}')
        with opener.open(request, timeout=3) as response:
            body = response.read(1024 * 1024 + 1)
            require(response.status == 200 and len(body) <= 1024 * 1024, 'Host URL failed')
        if expected_generation:
            require(expected_generation.encode() in body, 'Host Map generation differs')
        else:
            require(json.loads(body) == {'reference': 'retained-order-1', 'quantities': [2, 3]}, 'Host controller answer differs')
        return {'status': 'passed', 'host_url': request.full_url, 'peer_boundary': 'host loopback -> stdio -> worker loopback'}

    def start_access(self, state):
        access = {'unit': f'thistle-los139-{state["token"]}.scope'}
        state['access'] = access
        self.save(state)  # Record intended resource before attempting creation.
        with open(self.logs / f'access-{state["token"]}.log', 'xb') as log:
            os.chmod(log.name, 0o600)
            process = subprocess.Popen(self.access_command(state), stdin=subprocess.DEVNULL, stdout=log, stderr=log,
                                       start_new_session=True, env={key: os.environ[key] for key in
                                           ('PATH', 'HOME', 'XDG_RUNTIME_DIR', 'DBUS_SESSION_BUS_ADDRESS') if key in os.environ})
        deadline = time.monotonic() + 5
        while True:
            require(process.poll() is None and time.monotonic() < deadline, 'Host access startup failed')
            try:
                proof = self.access_identity(access)
                probe = self.host_probe()
                break
            except (Refused, OSError):
                time.sleep(0.1)
        write_json(self.logs / f'host-endpoint-{state["token"]}.json', {'scope': proof, 'probe': probe})

    def stop_access(self, access):
        # Stop the exact unit even if startup/readiness failed. A missing or failed
        # unit inspection cannot be claimed as successful cleanup.
        unit = access['unit']
        require(re.fullmatch(r'thistle-los139-[0-9a-f]{32}\.scope', unit), 'Access unit ownership refused')
        self.run(['/usr/bin/systemctl', '--user', 'stop', unit])
        phase = self.run(['/usr/bin/systemctl', '--user', 'show', unit, '--property=ActiveState', '--value']).strip()
        require(phase in ('inactive', 'failed'), 'Host listener cleanup incomplete')
        # The exact host loopback endpoint must no longer be reachable.
        import socket
        with socket.socket() as probe:
            probe.settimeout(1)
            require(probe.connect_ex(('127.0.0.1', self.config['host_port'])) != 0, 'Host listener still reachable')

    def start(self, initialize_empty=False):
        # Every helper must succeed with valid output before any dependent create,
        # start, GO, candidate load or connection. No "exit 0 means ready" shortcut.
        state = self.preflight()
        require(not initialize_empty or not state.get('init_attempted', False), 'Initialization already attempted')
        token = uuid.uuid4().hex
        state.update(phase='STARTING', token=token, expires_at=time.time() + LIMITS['lease'])
        self.save(state)
        try:
            os.makedirs(self.work / 'tmp', mode=0o700, exist_ok=True)
            (self.work / 'sessions' / token).mkdir(mode=0o700, parents=True)
            for name in ('admission.json', 'cohort-ready.json', 'go.json', 'ready.json'):
                path = self.work / name
                if path.exists():
                    # Archive prior session receipts before removing coordination
                    # files. Data, source, gems and evidence remain untouched.
                    path.rename(self.logs / f'{token}-prior-{name}')
            for role in ('db', 'app'):
                identifier = self.create(role, token)
                state['containers'][role] = identifier
                self.save(state)
                self.prove(identifier, role, token, False)
            self.podman('start', state['containers']['app'])
            app_proof = self.prove(state['containers']['app'], 'app', token, True)
            write_json(self.work / 'admission.json', {'token': token, 'expires_at': state['expires_at'],
                       'namespaces': app_proof['namespaces']})
            deadline = time.monotonic() + 35
            while not (self.work / 'cohort-ready.json').exists():
                require(time.monotonic() < deadline, 'Installed cohort preflight deadline')
                self.prove(state['containers']['app'], 'app', token, True)
                time.sleep(0.1)
            cohort = read_json(self.work / 'cohort-ready.json')
            require(cohort['token'] == token and cohort['identity']['native']['sha256'] == SELECTED['native.so']
                    and cohort['identity']['client']['sha256'] == self.config['mysql2_extension_sha256']
                    and cohort['identity']['client_library']['sha256'] == self.config['client_library_sha256']
                    and cohort['identity']['lock']['sha256'] == read_json(self.inputs / 'profile.json')['artifacts']['Gemfile.lock']['sha256'],
                    'Installed cohort preflight identity mismatch')
            write_json(self.logs / f'{token}-cohort.json', cohort)
            # No DB start, application boot/connect or GO before actual installed
            # framework/native/client/lock preflight succeeds inside confinement.
            self.podman('start', state['containers']['db'])
            proofs = {role: self.prove(cid, role, token, True) for role, cid in state['containers'].items()}
            require(proofs['db']['namespaces']['pid'] != proofs['app']['namespaces']['pid'], 'DB/app PID namespace shared')
            write_json(self.logs / f'{token}-admission.json', proofs)
            # The DB entrypoint proves scratch writeability as its real UID
            # before exec mysqld. A failed probe exits before data reuse/init.
            probe_path = self.root / 'mysql-tmp' / f'write-probe-{token}.json'
            deadline = time.monotonic() + 5
            while not probe_path.exists():
                require(time.monotonic() < deadline, 'MySQL scratch write probe missing')
                self.prove(state['containers']['db'], 'db', token, True)
                time.sleep(0.05)
            require(read_json(probe_path) == {'uid': os.getuid(), 'path': '/mysql-tmp', 'status': 'passed'}, 'MySQL scratch identity mismatch')
            write_json(self.logs / f'{token}-mysql-scratch.json', read_json(probe_path))
            state['init_attempted'] = state.get('init_attempted', False) or initialize_empty
            self.save(state)
            write_json(self.work / 'go.json', {'token': token, 'expires_at': state['expires_at'],
                       'namespaces': proofs['app']['namespaces'], 'initialize_empty': initialize_empty})
            deadline = time.monotonic() + 40
            while not (self.work / 'ready.json').exists():
                require(time.monotonic() < deadline, 'Rails readiness deadline')
                self.prove(state['containers']['app'], 'app', token, True)
                require(disk_bytes(self.work) <= LIMITS['work'], 'Work disk limit')
                time.sleep(0.2)
            ready = read_json(self.work / 'ready.json')
            require(ready['token'] == token and ready['booted'] is True, 'Invalid ready receipt')
            # Actual endpoint must answer through real loopback TCP before RUNNING.
            probe = json.loads(self.exec_ruby(state['containers']['app'], 'probe'))
            require(probe['status'] == 'passed' and probe['peer'] == '127.0.0.1', 'Endpoint probe failed')
            write_json(self.logs / f'{token}-endpoint.json', probe)
            state.update(phase='RUNNING', initialized=True)
            self.save(state)
            self.start_access(state)
            self.spawn_guard(token)
        except BaseException:
            state['phase'] = 'FAILED'
            self.save(state)
            self.stop()
            raise

    def spawn_guard(self, token):
        # OCI's own timeout is independent of this disk/lease monitor. The guard
        # never holds the CLI lock for the whole lease; status remains read-only.
        with open(self.logs / f'guard-{uuid.uuid4().hex}.log', 'xb') as log:
            os.chmod(log.name, 0o600)
            process = subprocess.Popen([sys.executable, str(HERE / 'host.py'), '_guard', '--config', str(self.config_path), '--lease-token', token],
                             stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True,
                             env={'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
                                  **{k: os.environ[k] for k in ('HOME', 'XDG_RUNTIME_DIR') if k in os.environ}})
        deadline = time.monotonic() + 3
        marker = self.logs / f'guard-{token}.json'
        while not marker.exists():
            require(process.poll() is None and time.monotonic() < deadline, 'Lease guard unavailable')
            time.sleep(0.05)
        require(read_json(marker) == {'token': token, 'pid': process.pid}, 'Lease guard identity mismatch')

    def status(self):
        if isinstance(self.run, Runner):
            previous = self.run.readonly
            self.run.readonly = True
            try:
                return self.observe_status()
            finally:
                self.run.readonly = previous
        return self.observe_status()

    def observe_status(self):
        state = self.state()
        actual_ids = {row['Id'] for row in self.compute(state)}
        require(actual_ids == set(state['containers'].values()), 'Actual compute differs from lifecycle record')
        observations = {role: self.prove(cid, role, state['token'], True) for role, cid in state['containers'].items()}
        if observations:
            require(time.time() < state['expires_at'] and state['phase'] == 'RUNNING', 'Stale/expired compute lease')
            self.access_identity(state['access'])
        else:
            require(state['phase'] == 'STOPPED', 'Incomplete lifecycle')
        return {'phase': state['phase'], 'profile': PROFILE, 'containers': state['containers'],
                'initialized': state['initialized'], 'endpoint': f'http://127.0.0.1:{self.config["host_port"]}/orders/1' if observations else None}

    def test(self, inject_failure=False):
        state = self.state()
        self.status()
        require(state['phase'] == 'RUNNING', 'Start first')
        self.validate_inputs()
        require(inventory(self.inputs) == state['inputs'], 'Source/artifact/lock drift')
        attempt = uuid.uuid4().hex
        relative = f'sessions/{state["token"]}/attempts/{attempt}'
        directory = self.work / relative
        directory.mkdir(mode=0o700, parents=True)
        shutil.copytree(self.inputs / 'app', directory / 'app')
        write_json(directory / 'begin.json', {'attempt': attempt, 'token': state['token'], 'cache_key': state['cache_key']})
        state.setdefault('attempt_started_ns', {})[attempt] = time.time_ns()
        state['attempts'].append(attempt)
        state['attempt_paths'][attempt] = relative
        self.save(state)
        try:
            require(not inject_failure, 'Controlled failure after admission, before producer')
            app = state['containers']['app']
            self.exec_ruby(app, 'producer', f'/work/{relative}', seconds=120)
            producer = read_json(directory / 'producer.json')
            require(producer['status'] == 'passed', 'Producer result missing or failed')
            replace_json(self.work / 'sessions' / state['token'] / 'selected.json', {
                'token': state['token'], 'attempt': attempt, 'store': f'/work/{relative}/store', 'generation': producer['saved']})
            self.exec_ruby(app, 'consumer', f'/work/{relative}', seconds=120)
            consumer = read_json(directory / 'consumer.json')
            require(consumer['status'] == 'passed' and consumer['rails_free'] is True
                    and consumer['saved'] == producer['saved'] and consumer['current'] == producer['current']
                    and producer['saved'] != producer['current'], 'Consumer result incomplete')
            self.host_probe('/map/?generation=' + producer['saved'], expected_generation=producer['saved'])
            write_json(directory / 'result.json', {'status': 'passed', 'saved': producer['saved'], 'current': producer['current']})
            self.retain(attempt)
        except BaseException:
            write_json(directory / 'failure.json', {'status': 'failed', 'effects_retained': True,
                       'program': 'controller', 'step': 'test-before-producer' if inject_failure else 'installed-journey',
                       'code': 'CONTROLLED_FAILURE' if inject_failure else 'JOURNEY_FAILED'})
            self.stop()  # Retains raw failed effects before removing compute.
            raise
        return attempt

    def retain(self, attempt):
        # Retention happens before runtime cleanup. Secret directory never enters
        # this tree. Copies include raw store/native/client identities and locks.
        destination = self.root / 'retained' / attempt
        destination.parent.mkdir(mode=0o700, exist_ok=True)
        require(not destination.exists(), 'Attempt already retained')
        destination.mkdir(mode=0o700)
        relative = self.state()['attempt_paths'][attempt]
        require(re.fullmatch(r'sessions/[0-9a-f]{32}/attempts/[0-9a-f]{32}', relative), 'Retained attempt path refused')
        shutil.copytree(self.work / relative, destination / 'raw')
        (destination / 'logs').mkdir(mode=0o700)
        # Avoid quadratic copies of all historic helper logs on each reuse.
        started = self.state().get('attempt_started_ns', {}).get(attempt, 0)
        for log in self.logs.iterdir():
            regular(log)
            if log.stat().st_mtime_ns >= started:
                shutil.copyfile(log, destination / 'logs' / log.name)
        shutil.copytree(self.inputs / 'artifacts', destination / 'artifacts')
        if (self.work / 'loaded').exists():
            shutil.copytree(self.work / 'loaded', destination / 'loaded')
        write_json(destination / 'profile.json', read_json(self.inputs / 'profile.json'))
        shutil.copyfile(self.inputs / 'dependencies.json', destination / 'dependencies.json')
        expected = inventory(destination)
        write_json(destination / 'INDEX.json', expected)
        # INDEX excludes only itself; independently re-enumerate and compare.
        actual = inventory(destination)
        actual.pop('INDEX.json')
        require(expected == actual, 'Retention readback mismatch')

    def verify_retained(self, attempt):
        destination = self.root / 'retained' / attempt
        expected = read_json(destination / 'INDEX.json')
        actual = inventory(destination)
        actual.pop('INDEX.json')
        require(expected == actual, 'Incomplete/corrupt retained evidence')

    def stop(self):
        state = self.state()
        failures = []
        if state.get('access'):
            try:
                self.stop_access(state['access'])
                state.pop('access')
                self.save(state)
            except Exception:
                failures.append('host-access-cleanup')
        try:
            # Discover create effects even if its helper failed, timed out or
            # returned malformed/missing output. Only exact instance/token-owned
            # resources may be stopped; no name/flag-only cleanup claims.
            for row in self.compute(state):
                observed = self.inspect(row['Id'])
                labels = observed['Config']['Labels']
                require(labels.get('thistle.los139') == state.get('token'), 'Unexpected lease owns compute')
                role = labels.get('thistle.role')
                require(role in ('app', 'db'), 'Unknown owned compute role')
                require(state['containers'].get(role, row['Id']) == row['Id'], 'Duplicate role compute')
                state['containers'][role] = row['Id']
            self.save(state)
        except Exception:
            failures.append('compute-inventory')
        # Failed attempts must be retained too. A retention failure cannot prevent
        # best-effort compute stop, and cannot result in success.
        for attempt in state['attempts']:
            try:
                if not (self.root / 'retained' / attempt).exists():
                    self.retain(attempt)
                self.verify_retained(attempt)
            except Exception:
                failures.append('retention')
        remaining = dict(state['containers'])
        for role in ('app', 'db'):
            if role not in remaining:
                continue
            identifier = remaining[role]
            try:
                actual = self.inspect(identifier)
                require(actual['Config']['Labels'].get('thistle.los139') == state['token'], 'Cleanup ownership mismatch')
                if actual['State']['Running']:
                    self.podman('stop', '--time=5', identifier)
                self.prove(identifier, role, state['token'], False)
                self.podman('rm', identifier)
                # exists has documented 0=present,1=absent. Use ps by exact ID so
                # helper errors still fail rather than masquerading as absence.
                result = json.loads(self.podman('ps', '-a', '--no-trunc', '--filter', f'id={identifier}', '--format', 'json'))
                require(result == [], 'Compute cleanup incomplete')
                del remaining[role]
            except Exception:
                failures.append(f'cleanup-{role}')
        try:
            require(not self.compute(state), 'Owned compute remains after cleanup')
        except Exception:
            failures.append('compute-absence')
        state.update(containers=remaining, phase='FAILED' if failures else 'STOPPED')
        self.save(state)
        write_json(self.logs / f'stop-{uuid.uuid4().hex}.json', {'status': 'failed' if failures else 'passed',
                   'remaining_compute': remaining, 'failures': failures, 'data_accounts_credentials_kept': True})
        require(not failures, 'Stop incomplete; inspect private evidence; state retained')

    def guard(self, token):
        write_json(self.logs / f'guard-{token}.json', {'token': token, 'pid': os.getpid()})
        try:
            while True:
                state = self.state()
                if state['phase'] != 'RUNNING' or state['token'] != token:
                    return
                if time.time() >= state['expires_at']:
                    break
                require(disk_bytes(self.work) <= LIMITS['work'], 'Work disk limit')
                time.sleep(1)
        finally:
            with self.lock():
                if self.state()['containers'] and self.state()['token'] == token:
                    self.stop()

    @contextlib.contextmanager
    def lock(self, readonly=False):
        with open(self.root / 'lock', 'rb') as lock:
            fcntl.flock(lock, fcntl.LOCK_SH if readonly else fcntl.LOCK_EX)
            yield


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['prepare', 'start', 'status', 'test', 'stop', '_guard', '_relay'])
    parser.add_argument('--config', help='0600 private local configuration')
    parser.add_argument('--initialize-empty', action='store_true', help='Explicit first-use app schema initialization at start')
    parser.add_argument('--inject-failure', action='store_true', help='Controlled test failure; verify retained evidence and stopped compute')
    parser.add_argument('--lease-token', help=argparse.SUPPRESS)
    parser.add_argument('--relay-cid', help=argparse.SUPPRESS)
    args = parser.parse_args()
    os.umask(0o077)
    try:
        if args.command == '_relay':
            require(args.relay_cid is not None and re.fullmatch(r'[0-9a-f]{64}', args.relay_cid), 'Relay container identity refused')
            # stdio is the only transport. No inherited Ruby/Bundler/proxy env or
            # arbitrary target/port/program can enter the worker.
            subprocess.run(['podman', 'exec', '--interactive', args.relay_cid, '/usr/bin/env', '-i',
                            'PATH=/usr/local/bin:/usr/bin:/bin', 'ruby', '/input/control/relay.rb'],
                           stdin=sys.stdin.buffer, stdout=sys.stdout.buffer, stderr=subprocess.DEVNULL,
                           env={k: os.environ[k] for k in ('PATH', 'HOME', 'XDG_RUNTIME_DIR') if k in os.environ},
                           check=True, timeout=20)
            return 0
        require(args.config is not None, 'Private configuration required')
        host = Host(args.config)
        if args.command == 'prepare':
            host.prepare()
        elif args.command == '_guard':
            require(args.lease_token is not None, 'Guard requires an exact lease')
            host.guard(args.lease_token)
        else:
            with host.lock(readonly=args.command == 'status'):
                if args.command == 'start':
                    host.start(args.initialize_empty)
                elif args.command == 'test':
                    host.test(args.inject_failure)
                else:
                    result = getattr(host, args.command)()
                    if result is not None:
                        print(json.dumps(result, sort_keys=True))
        return 0
    except Exception as error:
        # No exception text, config values or candidate logs enter stdout/stderr.
        frame = error.__traceback__
        line = None
        while frame:
            if Path(frame.tb_frame.f_code.co_filename).resolve() == Path(__file__).resolve():
                line = frame.tb_lineno
            frame = frame.tb_next
        print(json.dumps({'program': 'controller', 'step': args.command,
                          'code': f'CONTROLLER_L{line}' if line else 'CONTROLLER_UNEXPECTED',
                          'class': type(error).__name__ if type(error) in (Refused, OSError, ValueError, KeyError, TypeError) else 'UnexpectedError',
                          'effects_retained': True}), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
