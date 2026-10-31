#!/usr/bin/env python3
"""Repository-only reusable Rails host; stdlib controller, rootless Podman.

Five public commands. Candidate execution is always a separately admitted phase.
The subprocess boundary is injectable so controller tests never launch containers.
"""
import argparse
import contextlib
from concurrent.futures import ThreadPoolExecutor
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import resource
import selectors
import shutil
import signal
import stat
import socket
import subprocess
import sys
import time
import uuid
import urllib.request
from urllib.parse import urlencode, urlsplit, parse_qs
from html.parser import HTMLParser
import html

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


class HelperFailed(Refused):
    def __init__(self, returncode, output):
        super().__init__('Helper failed; private output retained')
        self.returncode, self.output = returncode, output


def private_open(path):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW | os.O_CLOEXEC, 0o600)
    try:
        info = os.fstat(descriptor)
        require(stat.S_ISREG(info.st_mode) and stat.S_IMODE(info.st_mode) == 0o600
                and info.st_uid == os.getuid() and info.st_nlink == 1, 'Private output allocation refused')
        return os.fdopen(descriptor, 'wb')
    except BaseException:
        os.close(descriptor)
        raise


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
    path = Path(path)
    data = json.dumps(value, sort_keys=True, indent=2).encode()
    require(len(data) <= LIMITS['output'], 'JSON output too large')
    temporary = path.with_name('.' + path.name + '.' + uuid.uuid4().hex + '.tmp')
    with private_open(temporary) as stream:
        stream.write(data)
        stream.flush()
        os.fsync(stream.fileno())
    os.link(temporary, path)  # atomic exclusive publication; existing evidence is immutable
    temporary.unlink()


def replace_json(path, value):
    temporary = path.with_name(path.name + '.' + uuid.uuid4().hex)
    write_json(temporary, value)
    os.replace(temporary, path)


def private_copy(source, destination):
    regular(source)
    with open(source, 'rb') as incoming, private_open(destination) as outgoing:
        shutil.copyfileobj(incoming, outgoing)


def private_tree(source, destination, skip_socket=None):
    """Copy frozen owned regular files with private modes from creation."""
    destination = Path(destination)
    destination.mkdir(mode=0o700)
    for item in Path(source).iterdir():
        info = item.lstat()
        if stat.S_ISDIR(info.st_mode):
            private_tree(item, destination / item.name, skip_socket=skip_socket)
        elif stat.S_ISREG(info.st_mode):
            private_copy(item, destination / item.name)
        else:
            # Only the exact session HTTP socket may remain after Puma stops.
            require(item == skip_socket and stat.S_ISSOCK(info.st_mode)
                    and info.st_uid == os.getuid() and stat.S_IMODE(info.st_mode) == 0o600,
                    'Unexpected special source file')


class MapPage(HTMLParser):
    def __init__(self, body):
        super().__init__(convert_charrefs=True)
        self.results, self.ids, self.site_count, self.checks, self.links = [], set(), 0, [], []
        self.in_check, self.check_text = False, ''
        self.feed(body)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        if tag == 'a' and 'data-result-link' in attrs:
            self.results.append(parse_qs(urlsplit(attrs.get('href', '')).query))
        if tag == 'a' and 'href' in attrs:
            self.links.append(urlsplit(attrs['href']))
        if 'constant-site' in attrs.get('class', '').split():
            self.site_count += 1
        if tag == 'pre' and 'check-data' in attrs.get('class', '').split():
            self.in_check, self.check_text = True, ''

    def handle_data(self, data):
        if self.in_check:
            self.check_text += data

    def handle_endtag(self, tag):
        if tag == 'pre' and self.in_check:
            self.checks.append(json.loads(self.check_text))
            self.in_check = False


def check_map_page(kind, body, oracle):
    page = MapPage(body)
    saved, origin = oracle['saved'], oracle['origin_id']
    require(saved in body, 'Map generation absent')
    if kind == 'find':
        require(any(row.get('id') == [origin] and row.get('generation') == [saved] for row in page.results), 'Known Find result absent')
    elif kind == 'check':
        require(any(row.get('integrity') == 'verified' and row.get('generation') == saved for row in page.checks), 'Map integrity not verified')
    elif kind == 'source':
        require(origin in html.unescape(body) and 'Inspection#sites' in body and oracle['source_sha256'] in body
                and all(f'L{line}' in page.ids for line in oracle['site_lines']), 'Pinned Source identity/hash/lines absent')
    elif kind in ('links', 'incoming'):
        require(page.site_count == oracle['site_count'] and all(any(link.fragment == f'L{line}'
                and parse_qs(link.query).get('id') == [origin] and parse_qs(link.query).get('generation') == [saved]
                for link in page.links) for line in oracle['site_lines']), 'HTTP site identities/count differ')
        require(origin in html.unescape(body), 'Site origin identity absent')
    return page


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
        self.next_disk_sample = 0.0

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
            stream = None if self.readonly else stack.enter_context(private_open(log))
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
                    if self.disk_root and time.monotonic() >= self.next_disk_sample:
                        roots = self.disk_root if isinstance(self.disk_root, list) else [self.disk_root]
                        require(sum(disk_bytes(root) for root in roots) <= LIMITS['work'], 'Work disk limit')
                        self.next_disk_sample = time.monotonic() + 2
                process.wait(timeout=max(0.01, deadline - time.monotonic()))
                if process.returncode != 0:
                    raise HelperFailed(process.returncode, output.decode('utf-8', errors='replace'))
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
        self.run = runner or Runner(self.logs)
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
        require(len(os.fsencode(self.work / 'sessions' / ('0' * 32) / 'http.sock')) < 108, 'Choose a shorter private instance path for UNIX socket')
        require(re.fullmatch(r'(?:[a-zA-Z0-9./_-]+@)?sha256:[0-9a-f]{64}', self.config['mysql_image']), 'Immutable MySQL image required')
        require(re.fullmatch(r'/[a-zA-Z0-9_/-]+', self.config['mysqld']), 'Absolute mysqld path required')

    def state(self):
        return read_json(self.state_path)

    def save(self, state):
        replace_json(self.state_path, state)

    def source_identity(self):
        paths = ['testbed/host.py', 'testbed/app', 'testbed/control']
        def git(*args):
            return self.run(['git', '-C', str(HERE.parent), *args])
        commit, tree = git('rev-parse', 'HEAD').strip(), git('rev-parse', 'HEAD^{tree}').strip()
        require({'commit': commit, 'tree': tree} == self.config['host_source'], 'Declared controller source commit/tree drift')
        tracked = set(git('ls-files', '-z', '--', *paths).rstrip('\0').split('\0'))
        files = {'testbed/host.py': {'size': (HERE / 'host.py').stat().st_size, 'sha256': digest(HERE / 'host.py')}}
        for name in ('app', 'control'):
            files.update({f'testbed/{name}/{path}': identity for path, identity in inventory(HERE / name).items()})
        require(set(files) == tracked, 'Untracked or ignored canonical source additions')
        git('diff', '--exit-code', 'HEAD', '--', *paths)
        return {'commit': commit, 'tree': tree, 'files': files,
                'inventory_sha256': hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()}

    def session_logs(self, token):
        require(re.fullmatch(r'[0-9a-f]{32}', token), 'Log session refused')
        return self.logs / token

    def select_logs(self, token):
        directory = self.session_logs(token)
        directory.mkdir(mode=0o700, exist_ok=True)
        private_dir(directory)
        if isinstance(self.run, Runner):
            self.run.logs = directory
            self.run.disk_root = self.active_disk_roots(token)

    def active_disk_roots(self, token):
        return [self.work / 'sessions' / token, self.work / 'gems', self.work / 'loaded']

    def wait_receipt(self, path, seconds, identifier=None):
        deadline, next_inspection = time.monotonic() + seconds, 0.0
        while not path.exists():
            now = time.monotonic()
            require(now < deadline, 'Receipt readiness deadline')
            if identifier and now >= next_inspection:
                require(self.inspect(identifier)['State']['Running'] is True, 'Preflight worker exited')
                next_inspection = now + 2
            time.sleep(0.2)
        return read_json(path)

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
            source_identity = self.source_identity()
            for name in ('app', 'control'):
                source = HERE / name
                inventory(source)
                private_tree(source, self.inputs / name)
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
                private_copy(source, self.inputs / 'artifacts' / name)
                artifacts[name] = actual
            require(artifacts['native.so']['size'] == 6124976, 'Native size mismatch')
            profile = {k: self.config[k] for k in ('profile', 'ruby', 'dependency_home', 'server_uuid',
                       'mysql2_extension_sha256', 'client_library_sha256', 'client_version', 'puma_version')}
            profile['artifacts'] = artifacts
            profile['map_candidate'] = self.config['map_candidate']
            profile['dependency_manifest_sha256'] = self.config['dependency_manifest']['sha256']
            private_copy(self.config['dependency_manifest']['path'], self.inputs / 'dependencies.json')
            defaults = self.config['default_providers']
            regular(defaults['path'])
            require(digest(defaults['path']) == defaults['sha256'], 'Immutable default provider manifest drift')
            private_copy(defaults['path'], self.inputs / 'default-providers.json')
            profile['default_providers_sha256'] = defaults['sha256']
            profile['source'] = source_identity
            profile['host_socat'] = self.config['host_socat']
            write_json(self.inputs / 'profile.json', profile)
            # Key includes exact artifacts, lock, image/OS/arch and ABI assertion;
            # the observed ABI is checked inside the worker before any connect.
            cache = {'artifacts': artifacts, 'dependencies': profile['dependency_manifest_sha256'],
                     'default_providers': profile['default_providers_sha256'],
                     'image': IMAGE, 'os': 'linux', 'arch': 'x86_64', 'ruby_abi': '3.4.0'}
            state = {'phase': 'STOPPED', 'profile': PROFILE, 'inputs': inventory(self.inputs),
                     'cache_key': hashlib.sha256(json.dumps(cache, sort_keys=True).encode()).hexdigest(),
                     'containers': {}, 'instance_id': uuid.uuid4().hex, 'initialized': False, 'attempts': [],
                     'sessions': {}, 'source': source_identity}
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
        require(self.source_identity() == state['source'], 'Canonical controller source changed since prepare')
        require(inventory(self.inputs) == state['inputs'], 'Source/artifact/lock drift')
        require(read_json(self.inputs / 'profile.json')['dependency_manifest_sha256'] == self.config['dependency_manifest']['sha256'], 'Prepared dependency cohort changed')
        profile = read_json(self.inputs / 'profile.json')
        require(profile['default_providers_sha256'] == self.config['default_providers']['sha256'], 'Prepared default provider binding changed')
        require(profile['map_candidate'] == self.config['map_candidate'] and profile['host_socat'] == self.config['host_socat'], 'Prepared artifact/transport binding changed')
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
                require(image in result[0]['RepoDigests'] or image.removeprefix('sha256:') == result[0]['Id'].removeprefix('sha256:'), 'MySQL image digest mismatch')
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
                       f'TMPDIR=/work/sessions/{token}/tmp', 'RAILS_ENV=test', 'LD_LIBRARY_PATH=/input/artifacts',
                       'ruby', '/input/control/run.rb', 'host', token]
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
                           'HOME=/work', f'TMPDIR=/work/sessions/{self.state()["token"]}/tmp', 'RAILS_ENV=test', 'GEM_HOME=/work/gems',
                           'LD_LIBRARY_PATH=/input/artifacts',
                           f'GEM_PATH=/work/gems:{self.config["dependency_home"]}',
                           'ruby', '/input/control/run.rb', script, *args, seconds=seconds)

    def access_command(self, state):
        path = self.http_socket(state['token'])
        require(not any(char in str(path) for char in ',:\\'), 'Unsupported UNIX socket path')
        return ['/usr/bin/systemd-run', '--user', '--scope', '--quiet', '--unit', f'thistle-los139-{state["token"]}',
                '--property=MemoryMax=134217728', '--property=MemorySwapMax=0', '--property=TasksMax=32',
                '--property=CPUQuota=100%', '/usr/bin/timeout', '--kill-after=5s', str(LIMITS['lease']) + 's',
                self.config['host_socat']['path'], '-T', '15',
                f'TCP4-LISTEN:{self.config["host_port"]},bind=127.0.0.1,reuseaddr,fork,max-children=8',
                f'UNIX-CONNECT:{path}']

    def http_socket(self, token):
        require(re.fullmatch(r'[0-9a-f]{32}', token), 'Session token refused')
        return self.work / 'sessions' / token / 'http.sock'

    def socket_identity(self, token):
        path = self.http_socket(token)
        private_dir(path.parent)
        info = path.lstat()
        require(stat.S_ISSOCK(info.st_mode) and info.st_uid == os.getuid()
                and info.st_gid == os.getgid() and stat.S_IMODE(info.st_mode) == 0o600, 'Private Puma socket identity refused')
        return {'path': str(path), 'uid': info.st_uid, 'gid': info.st_gid, 'mode': '0600', 'inode': info.st_ino}

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
        peaks = {name: (root / name).read_text().strip() for name in ('memory.peak', 'pids.peak')}
        return {'unit': unit, 'cgroup': group, 'limits': limits, 'peaks': peaks, 'owned_listener': address}

    def host_probe(self, path='/orders/1', kind=None, oracle=None, asset_type=None):
        opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
        # Use the actual advertised URL; never replace Host or forwarded headers.
        request = urllib.request.Request(f'http://127.0.0.1:{self.config["host_port"]}{path}')
        with opener.open(request, timeout=5) as response:
            raw = response.read(1024 * 1024 + 1)
            require(response.status == 200 and len(raw) <= 1024 * 1024, 'Host URL failed')
            if asset_type:
                require(response.headers.get_content_type() == asset_type and raw, 'Host asset unavailable')
        body = raw.decode('utf-8')
        if kind:
            check_map_page(kind, body, oracle)
        elif not asset_type:
            require(json.loads(body) == {'reference': 'retained-order-1', 'quantities': [2, 3]}, 'Host controller answer differs')
        return {'status': 'passed', 'host_url': request.full_url, 'body': body,
                'topology': 'host loopback -> socat -> private Puma UNIX socket'}

    def host_map_probe(self, oracle):
        generation, origin = oracle['saved'], oracle['origin_id']
        routes = [('find', '/', {'q': 'Inspection#sites'}), ('source', '/source', {'id': origin}),
                  ('links', '/links', {'id': origin}), ('incoming', '/links', {'id': oracle['order_id'], 'direction': 'incoming'}),
                  ('check', '/check', {})]
        work = [(kind, '/map' + path + '?' + urlencode(dict(params, generation=generation)), None)
                for kind, path, params in routes]
        work += [(None, '/map/assets/' + name, content_type) for name, content_type in
                 [('map.css', 'text/css'), ('woods-map-tokens.css', 'text/css'), ('map.js', 'text/javascript')]]
        def fetch(item):
            kind, path, asset_type = item
            return self.host_probe(path, kind=kind, oracle=oracle, asset_type=asset_type)
        # Four simultaneous workers cover the HTML/asset connection pattern. Actual
        # task/RSS peaks remain a required runtime observation, never a mock claim.
        before = self.access_identity(self.state()['access'])
        with ThreadPoolExecutor(max_workers=4) as pool:
            results = list(pool.map(fetch, work))
        after = self.access_identity(self.state()['access'])
        return {'parallel_workers': 4, 'requests': results, 'resource_before': before, 'resource_after': after}

    def start_access(self, state):
        socket_proof = self.socket_identity(state['token'])
        access = {'unit': f'thistle-los139-{state["token"]}.scope'}
        state['access'] = access
        self.save(state)  # Record intended resource before attempting creation.
        with private_open(self.session_logs(state['token']) / 'access.log') as log:
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
                time.sleep(0.5)
        write_json(self.session_logs(state['token']) / 'host-endpoint.json', {'scope': proof, 'probe': probe, 'socket': socket_proof})

    def stop_access(self, access):
        unit = access['unit']
        require(re.fullmatch(r'thistle-los139-[0-9a-f]{32}\.scope', unit), 'Access unit ownership refused')
        before = self.unit_state(unit)
        if before['LoadState'] != 'not-found' and before['ActiveState'] not in ('inactive', 'failed'):
            try:
                self.run(['/usr/bin/systemctl', '--user', 'stop', unit])
            except HelperFailed as error:
                # A GC race is acceptable only with structured not-loaded state;
                # all other failed helper effects remain failures.
                require(error.returncode == 5 and self.unit_state(unit)['LoadState'] == 'not-found', 'Host access stop failed')
        after = self.unit_state(unit)
        require(after['LoadState'] == 'not-found' or after['ActiveState'] in ('inactive', 'failed'), 'Host listener cleanup incomplete')
        require(self.port_absent(), 'Host listener still reachable')
        return {'before': before, 'after': after, 'port_unreachable': True}

    def unit_state(self, unit):
        failed = False
        try:
            output = self.run(['/usr/bin/systemctl', '--user', 'show', unit, '--property=LoadState', '--property=ActiveState'])
        except HelperFailed as error:
            require(error.returncode == 5, 'Unexpected unit inspection failure')
            output = error.output
            failed = True
        fields = dict(line.split('=', 1) for line in output.splitlines() if line.startswith(('LoadState=', 'ActiveState=')))
        require(set(fields) == {'LoadState', 'ActiveState'}, 'Missing structured unit state')
        require(fields['LoadState'] in ('loaded', 'not-found') and
                fields['ActiveState'] in ('active', 'activating', 'deactivating', 'inactive', 'failed'), 'Unexpected unit state')
        require(not failed or fields == {'LoadState': 'not-found', 'ActiveState': 'inactive'}, 'Exit 5 without actual unit absence')
        return fields

    def port_absent(self):
        with socket.socket() as probe:
            probe.settimeout(1)
            return probe.connect_ex(('127.0.0.1', self.config['host_port'])) != 0

    def start(self, initialize_empty=False):
        state = self.preflight()
        require(not initialize_empty or not state.get('init_attempted', False), 'Initialization already attempted')
        token = uuid.uuid4().hex
        state.update(phase='STARTING', token=token, expires_at=time.time() + LIMITS['lease'])
        state.setdefault('sessions', {})[token] = {'attempts': [], 'custody_history': [], 'source': state['source']}
        self.save(state)
        self.select_logs(token)
        session = self.work / 'sessions' / token
        session.mkdir(mode=0o700, parents=True)
        try:
            (session / 'tmp').mkdir(mode=0o700)
            for name in ('gems', 'loaded'):
                (self.work / name).mkdir(mode=0o700, exist_ok=True)
            require(not self.http_socket(token).exists(), 'Existing session socket refused')
            write_json(session / 'source.json', state['source'])
            write_json(self.session_logs(token) / 'controller.json', {'source': state['source'], 'cache_key': state['cache_key'],
                       'image_ids': state['image_ids'], 'map_candidate': self.config['map_candidate']})
            for role in ('db', 'app'):
                identifier = self.create(role, token)
                state['containers'][role] = identifier
                self.save(state)
                self.prove(identifier, role, token, False)
            app = state['containers']['app']
            self.podman('start', app)
            app_proof = self.prove(app, 'app', token, True)
            write_json(session / 'admission.json', {'token': token, 'expires_at': state['expires_at'], 'namespaces': app_proof['namespaces']})
            cohort = self.wait_receipt(session / 'cohort-ready.json', 35, app)
            require(cohort['token'] == token and cohort['identity']['native']['sha256'] == SELECTED['native.so']
                    and cohort['identity']['client']['sha256'] == self.config['mysql2_extension_sha256']
                    and cohort['identity']['client_library']['sha256'] == self.config['client_library_sha256']
                    and cohort['identity']['lock']['sha256'] == read_json(self.inputs / 'profile.json')['artifacts']['Gemfile.lock']['sha256'],
                    'Installed cohort preflight identity mismatch')
            write_json(self.session_logs(token) / 'cohort.json', cohort)
            # No DB start or GO follows a missing/invalid actual installed preflight.
            self.podman('start', state['containers']['db'])
            proofs = {role: self.prove(cid, role, token, True) for role, cid in state['containers'].items()}
            require(proofs['db']['namespaces']['pid'] != proofs['app']['namespaces']['pid'], 'DB/app PID namespace shared')
            write_json(self.session_logs(token) / 'admission.json', proofs)
            scratch = self.wait_receipt(self.root / 'mysql-tmp' / f'write-probe-{token}.json', 5, state['containers']['db'])
            require(scratch == {'uid': os.getuid(), 'path': '/mysql-tmp', 'status': 'passed'}, 'MySQL scratch identity mismatch')
            write_json(self.session_logs(token) / 'mysql-scratch.json', scratch)
            state['init_attempted'] = state.get('init_attempted', False) or initialize_empty
            self.save(state)
            write_json(session / 'go.json', {'token': token, 'expires_at': state['expires_at'],
                       'namespaces': proofs['app']['namespaces'], 'initialize_empty': initialize_empty})
            ready = self.wait_receipt(session / 'ready.json', 40, app)
            require(ready['token'] == token and ready['booted'] is True, 'Invalid ready receipt')
            write_json(self.session_logs(token) / 'puma-socket.json', self.socket_identity(token))
            probe = json.loads(self.exec_ruby(app, 'probe', f'/work/sessions/{token}/http.sock'))
            require(probe['status'] == 'passed' and probe['peer'] == '127.0.0.1'
                    and probe['transport'] == 'private-unix', 'Internal UNIX endpoint probe failed')
            write_json(self.session_logs(token) / 'internal-endpoint.json', probe)
            state.update(phase='RUNNING', initialized=True)
            self.save(state)
            self.start_access(state)
            self.spawn_guard(token)
        except BaseException:
            # Preserve source failure separately; successful cleanup never promotes it.
            write_json(session / 'start-failure.json', {'status': 'failed', 'code': 'START_FAILED', 'token': token})
            state['phase'] = 'FAILED'
            self.save(state)
            self.stop()
            raise

    def spawn_guard(self, token):
        # OCI's own timeout is independent of this disk/lease monitor. The guard
        # never holds the CLI lock for the whole lease; status remains read-only.
        with private_open(self.session_logs(token) / 'guard.log') as log:
            process = subprocess.Popen([sys.executable, str(HERE / 'host.py'), '_guard', '--config', str(self.config_path), '--lease-token', token],
                             stdin=subprocess.DEVNULL, stdout=log, stderr=log, start_new_session=True,
                             env={'PATH': os.environ.get('PATH', '/usr/bin:/bin'),
                                  **{k: os.environ[k] for k in ('HOME', 'XDG_RUNTIME_DIR') if k in os.environ}})
        deadline = time.monotonic() + 3
        marker = self.session_logs(token) / 'guard.json'
        while not marker.exists():
            require(process.poll() is None and time.monotonic() < deadline, 'Lease guard unavailable')
            time.sleep(0.2)
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
                'initialized': state['initialized'], 'last_stop': state.get('last_stop'),
                'endpoint': f'http://127.0.0.1:{self.config["host_port"]}/orders/1' if observations else None}

    def test(self, inject_failure=False):
        state = self.state()
        self.status()
        require(state['phase'] == 'RUNNING', 'Start first')
        self.select_logs(state['token'])
        self.validate_inputs()
        require(inventory(self.inputs) == state['inputs'], 'Source/artifact/lock drift')
        require(self.source_identity() == state['source'], 'Canonical controller source drift')
        attempt = uuid.uuid4().hex
        relative = f'sessions/{state["token"]}/attempts/{attempt}'
        directory = self.work / relative
        directory.mkdir(mode=0o700, parents=True)
        private_tree(self.inputs / 'app', directory / 'app')
        write_json(directory / 'begin.json', {'attempt': attempt, 'token': state['token'],
                   'cache_key': state['cache_key'], 'source': state['source']})
        state['attempts'].append(attempt)
        state['attempt_paths'][attempt] = relative
        state['sessions'][state['token']]['attempts'].append(attempt)
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
            oracle = read_json(directory / 'oracle.json')
            fixture = read_json(self.inputs / 'app/expected.json')
            require(oracle['saved'] == producer['saved'] and oracle['site_count'] == 2
                    and oracle['site_lines'] == fixture['site_lines']
                    and oracle['source_sha256'] == digest(self.inputs / 'app/app/services/inspection.rb'), 'Fixture HTTP oracle drift')
            write_json(directory / 'host-http.json', self.host_map_probe(oracle))
            write_json(directory / 'result.json', {'status': 'passed', 'saved': producer['saved'],
                       'current': producer['current'], 'custody': 'pending_stop'})
            # Custody waits until stop confirms all writer compute stopped.
        except BaseException:
            write_json(directory / 'failure.json', {'status': 'failed', 'effects_retained': True,
                       'program': 'controller', 'step': 'test-before-producer' if inject_failure else 'installed-journey',
                       'code': 'CONTROLLED_FAILURE' if inject_failure else 'JOURNEY_FAILED'})
            self.stop()
            raise
        return attempt

    def retain_blob(self, source):
        identity = {'sha256': digest(source), 'size': Path(source).stat().st_size}
        root = self.root / 'retained' / 'blobs'
        root.mkdir(mode=0o700, parents=True, exist_ok=True)
        target = root / identity['sha256']
        if not target.exists():
            temporary = root / (identity['sha256'] + '-' + uuid.uuid4().hex + '.partial')
            private_copy(source, temporary)
            require(digest(temporary) == identity['sha256'], 'Shared blob readback mismatch')
            os.link(temporary, target)
            temporary.unlink()
        regular(target, private=True)
        require(target.stat().st_size == identity['size'] and digest(target) == identity['sha256'], 'Shared blob bytes drift')
        return dict(identity, path=str(target.relative_to(self.root)))

    def shared_evidence(self, state):
        if state.get('shared_evidence'):
            # Verify only the selected current tuple, never all historic sessions.
            reference = state['shared_evidence']
            directory = self.root / reference['path']
            require(digest(directory / 'INDEX.json') == reference['index_sha256'], 'Shared index identity drift')
            self.verify_bundle(directory)
            for blob in read_json(directory / 'artifacts.json').values():
                path = self.root / blob['path']
                require(path.stat().st_size == blob['size'] and digest(path) == blob['sha256'], 'Current shared artifact drift')
            return reference
        directory = self.root / 'retained' / 'shared' / (state['cache_key'] + '-' + uuid.uuid4().hex)
        directory.mkdir(mode=0o700, parents=True)
        for name in ('app', 'control'):
            private_tree(self.inputs / name, directory / name)
        for name in ('profile.json', 'dependencies.json', 'default-providers.json'):
            private_copy(self.inputs / name, directory / name)
        write_json(directory / 'artifacts.json', {p.name: self.retain_blob(p) for p in (self.inputs / 'artifacts').iterdir()})
        self.seal(directory)
        reference = {'path': str(directory.relative_to(self.root)), 'index_sha256': digest(directory / 'INDEX.json')}
        state['shared_evidence'] = reference
        self.save(state)
        return reference

    def seal(self, directory):
        expected = inventory(directory)
        write_json(directory / 'INDEX.json', expected)
        self.verify_bundle(directory)

    def verify_bundle(self, directory):
        expected = read_json(directory / 'INDEX.json')
        actual = inventory(directory)
        actual.pop('INDEX.json')
        require(actual == expected, 'Retention readback mismatch')

    def retain(self, token):
        # Called only after every owned writer is independently proven stopped.
        state = self.state()
        shared = self.shared_evidence(state)
        record = state['sessions'][token]
        directory = self.root / 'retained' / 'sessions' / token / uuid.uuid4().hex
        directory.mkdir(mode=0o700, parents=True)
        record['custody_history'].append({'path': str(directory.relative_to(self.root)), 'status': 'partial'})
        self.save(state)
        private_tree(self.work / 'sessions' / token, directory / 'session', skip_socket=self.http_socket(token))
        private_tree(self.session_logs(token), directory / 'logs')
        write_json(directory / 'shared.json', shared)
        loaded = self.work / 'loaded'
        write_json(directory / 'loaded.json', {p.name: self.retain_blob(p) for p in loaded.iterdir()} if loaded.exists() else {})
        required = ('source.json', 'admission.json', 'cohort-ready.json', 'go.json', 'ready.json')
        write_json(directory / 'raw-gaps.json', {'missing_session_receipts': [name for name in required
                   if not (directory / 'session' / name).exists()], 'source': state['source']})
        frozen = inventory(directory)
        write_json(directory / 'SNAPSHOT.json', frozen)
        # Verify the frozen bytes before dependent container removal. INDEX is final
        # only after the later actual cleanup/absence receipt has been added.
        actual = inventory(directory)
        actual.pop('SNAPSHOT.json')
        require(actual == frozen, 'Frozen snapshot readback mismatch')
        return directory

    def finish_retention(self, directory, receipt):
        # Append closed cleanup-helper logs; never rewrite the frozen prefix.
        for path in self.session_logs(receipt['token']).iterdir():
            target = directory / 'logs' / path.name
            if not target.exists():
                private_copy(path, target)
        write_json(directory / 'STOP.json', receipt)
        self.seal(directory)
        return {'path': str(directory.relative_to(self.root)), 'index_sha256': digest(directory / 'INDEX.json')}

    def verify_retained(self, token):
        record = self.state()['sessions'][token]
        require(record.get('sealed'), 'Session custody incomplete')
        directory = self.root / record['sealed']['path']
        require(digest(directory / 'INDEX.json') == record['sealed']['index_sha256'], 'Published session index identity changed')
        self.verify_bundle(directory)

    def stop(self):
        state = self.state()
        token = state.get('token')
        failures, stopped, absent = [], {}, []
        if token:
            self.select_logs(token)
        state['phase'] = 'STOPPING'
        self.save(state)
        access_receipt = None
        if state.get('access'):
            try:
                access_receipt = self.stop_access(state['access'])
                state.pop('access')
            except Exception:
                failures.append('host-access-cleanup')
        try:
            for row in self.compute(state):
                observed = self.inspect(row['Id'])
                self.cleanup_owner(observed, state)
                role = observed['Config']['Labels']['thistle.role']
                require(state['containers'].get(role, row['Id']) == row['Id'], 'Duplicate role compute')
                state['containers'][role] = row['Id']
        except Exception:
            failures.append('compute-inventory')
        self.save(state)
        remaining = dict(state['containers'])
        # Stop *all* actual writer compute before copying any capture/store/log tree.
        for role, identifier in list(remaining.items()):
            try:
                observed = self.owned_container(identifier, state)
                if observed is None:
                    absent.append(identifier)
                    del remaining[role]
                    continue
                if observed['State']['Running']:
                    try:
                        self.podman('stop', '--time=5', identifier)
                    except Exception:
                        failures.append('stop-helper-' + role)
                        observed = self.owned_container(identifier, state)
                        if observed is not None and observed['State']['Running']:
                            self.podman('kill', identifier)
                observed = self.owned_container(identifier, state)
                if observed is None:
                    absent.append(identifier)
                    del remaining[role]
                else:
                    require(observed['State']['Running'] is False, 'Writer still running')
                    stopped[role] = identifier
            except Exception:
                failures.append('stop-' + role)
        state['containers'] = remaining
        self.save(state)
        quiesced = not state.get('access') and set(stopped.values()) == set(remaining.values()) and not any(
            failure.startswith(('compute-', 'stop-')) for failure in failures)
        directory = None
        record = state.get('sessions', {}).get(token, {})
        if quiesced and token and not record.get('sealed'):
            try:
                directory = self.retain(token)
            except Exception:
                failures.append('retention')
        # A failed snapshot leaves stopped resources and raw bind-mounted effects;
        # the next stop takes a new custody attempt, never reuses a partial bundle.
        if quiesced and (directory is not None or record.get('sealed') or not token):
            for role, identifier in list(remaining.items()):
                try:
                    observed = self.owned_container(identifier, state)
                    if observed is not None:
                        require(observed['State']['Running'] is False, 'Writer restarted during cleanup')
                        self.podman('rm', identifier)
                    require(self.exact_absent(identifier), 'Compute cleanup incomplete')
                    del remaining[role]
                    absent.append(identifier)
                except Exception:
                    failures.append('remove-' + role)
        try:
            empty = self.compute(state) == []
            require(empty, 'Owned compute remains')
        except Exception:
            empty = False
            failures.append('compute-absence')
        receipt = {'token': token, 'status': 'failed' if failures else 'passed', 'failures': failures,
                   'stopped_before_snapshot': stopped, 'absent_ids': absent, 'remaining_compute': remaining,
                   'instance_absent': empty, 'host_access': access_receipt, 'source': state.get('source'),
                   'data_accounts_credentials_kept': True}
        receipt['scope'] = 'compute_cleanup_and_custody_only'
        if token:
            session = self.work / 'sessions' / token
            receipt['start_status'] = 'failed' if (session / 'start-failure.json').exists() else 'ready' if (session / 'ready.json').exists() else 'unobserved'
            receipt['attempt_outcomes'] = {}
            for attempt in record.get('attempts', []):
                path = session / 'attempts' / attempt
                receipt['attempt_outcomes'][attempt] = 'failed' if (path / 'failure.json').exists() else 'passed' if (path / 'result.json').exists() else 'incomplete'
        if directory is not None:
            try:
                reference = self.finish_retention(directory, receipt)
                state = self.state()  # retain may have added shared/custody metadata
                state['sessions'][token]['custody_history'][-1]['status'] = receipt['status']
                if not failures:
                    state['sessions'][token]['sealed'] = reference
            except Exception:
                failures.append('final-index')
        else:
            state = self.state()
        # STOPPED describes actual compute absence, never retroactive journey success.
        state.update(containers=remaining, phase='STOPPED' if empty and not state.get('access') else 'FAILED')
        receipt.update(status='failed' if failures else 'passed', failures=failures)
        state['last_stop'] = receipt
        self.save(state)
        if token:
            write_json(self.session_logs(token) / ('stop-' + uuid.uuid4().hex + '.json'), receipt)
        require(not failures, 'Stop incomplete; private effects retained')

    def cleanup_owner(self, observed, state):
        labels = observed['Config']['Labels']
        require(labels.get('thistle.instance') == state['instance_id'] and labels.get('thistle.los139') == state.get('token')
                and labels.get('thistle.role') in ('app', 'db'), 'Cleanup ownership mismatch')

    def exact_absent(self, identifier):
        rows = json.loads(self.podman('ps', '-a', '--no-trunc', '--filter', f'id={identifier}', '--format', 'json'))
        require(isinstance(rows, list) and all(isinstance(row, dict) and row.get('Id') == identifier for row in rows), 'Invalid exact-ID inventory')
        return rows == []

    def owned_container(self, identifier, state):
        require(re.fullmatch(r'[0-9a-f]{64}', identifier), 'Cleanup exact ID refused')
        if self.exact_absent(identifier):
            return None
        try:
            observed = self.inspect(identifier)
        except Exception:
            if self.exact_absent(identifier):
                return None
            raise
        self.cleanup_owner(observed, state)
        require(type(observed['State']['Running']) is bool, 'Cleanup actual state missing')
        return observed

    def guard(self, token):
        self.select_logs(token)
        write_json(self.session_logs(token) / 'guard.json', {'token': token, 'pid': os.getpid()})
        try:
            while True:
                state = self.state()
                if state['phase'] != 'RUNNING' or state['token'] != token:
                    return
                if time.time() >= state['expires_at']:
                    break
                require(sum(disk_bytes(root) for root in self.active_disk_roots(token)) <= LIMITS['work'], 'Work disk limit')
                time.sleep(2)
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
    parser.add_argument('command', choices=['prepare', 'start', 'status', 'test', 'stop', '_guard'])
    parser.add_argument('--config', help='0600 private local configuration')
    parser.add_argument('--initialize-empty', action='store_true', help='Explicit first-use app schema initialization at start')
    parser.add_argument('--inject-failure', action='store_true', help='Controlled test failure; verify retained evidence and stopped compute')
    parser.add_argument('--lease-token', help=argparse.SUPPRESS)
    args = parser.parse_args()
    os.umask(0o077)
    try:
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
