#!/usr/bin/env python3
"""Orchestrate the frozen evaluator; this candidate-owned runner is not protected CI."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import io


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def run(command, **kwargs):
    return subprocess.run([str(x) for x in command], check=True, **kwargs)


def run_logged(command, stdout_path, stderr_path, **kwargs):
    # Write directly to retained files, including on failure or timeout.
    with stdout_path.open('w') as stdout, stderr_path.open('w') as stderr:
        run(command, stdout=stdout, stderr=stderr, timeout=60, **kwargs)


def package_files(package):
    with tarfile.open(package) as outer:
        payload = outer.extractfile('data.tar.gz').read()
    with tarfile.open(fileobj=io.BytesIO(payload), mode='r:gz') as data:
        return {m.name.removeprefix('./'): hashlib.sha256(data.extractfile(m).read()).hexdigest()
                for m in data.getmembers() if m.isfile()}


def prepare_output(out):
    # Callers may pre-create this directory for logs, but an executed attempt's
    # receipts must not be overwritten by a retry. Use a new output per attempt.
    out.mkdir(parents=True, exist_ok=True)
    if (out / 'build-identity.json').exists() or (out / 'installed-baseline').exists():
        raise FileExistsError('Qualification attempt already exists; choose a fresh output directory')


def installed_smoke(src, out, ruby, consumer, env, core_files):
    # Each arm uses its selected source's smoke. The historical package has no
    # model observer; never impose a later feature journey on that frozen arm.
    # Select from the actual package, not fixture availability: a model-enabled
    # candidate with missing fixture inputs must fail rather than skip coverage.
    smoke = out / 'installed_smoke.rb'
    shutil.copyfile(src / 'map/test/installed_smoke.rb', smoke)
    command = [ruby, smoke]
    model_inputs, model_receipt = {}, None
    if 'lib/thistle/model_observer.rb' in core_files:
        fixture = out / 'model-fixture'
        fixture.mkdir()
        for name in ('booted_app.rb', 'records.rb'):
            shutil.copyfile(src / 'test/fixtures/models' / name, fixture / name)
        model_producer = out / 'installed_model_producer.rb'
        shutil.copyfile(src / 'map/test/installed_model_producer.rb', model_producer)
        model_receipt = out / 'model-producer.json'
        model_store = out / 'model-store'
        run_logged([ruby, model_producer, fixture, out / 'model-source', model_store],
                   model_receipt, out / 'model-producer.stderr', cwd=consumer, env=env)
        model_inputs = {path.relative_to(out).as_posix(): sha(path)
                        for path in [model_producer, *sorted(fixture.glob('*.rb'))]}
        command += [model_store, model_receipt]
    run_logged(command, out / 'map-installed-smoke.json', out / 'map-installed-smoke.stderr',
               cwd=consumer, env=env)
    return smoke, model_inputs, model_receipt


def main():
    parser = argparse.ArgumentParser()
    for name in ('source', 'evaluator', 'output', 'ruby', 'toolchain', 'dependencies', 'libclang'):
        parser.add_argument('--' + name, required=True, type=Path)
    args = parser.parse_args()
    src, evaluator, out = args.source.resolve(), args.evaluator.resolve(), args.output.resolve()
    prepare_output(out)
    baseline = src / 'pkg/hardened-baseline/thistle.gem'
    map_gem = src / 'pkg/hardened-baseline/thistle-map.gem'
    core_files, map_files = package_files(baseline), package_files(map_gem)
    assert not any(p.startswith('docs/handoff/') for p in core_files), 'handoff leaked into gem'
    vendored = {p.relative_to(src).as_posix(): sha(p) for p in (src / 'engine/vendor').rglob('*') if p.is_file()}
    assert vendored == {p: h for p, h in core_files.items() if p.startswith('engine/vendor/')}, 'vendor byte set differs'
    policy = evaluator / 'policies/experiment-001.json'
    assert sha(policy) == '14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe'
    revision = subprocess.check_output(['git', '-C', str(evaluator), 'rev-parse', 'HEAD'], text=True).strip()
    assert revision == 'b81f5adc2c647083b6ce8688234012c6d2da0ee4'
    run(['git', '-C', evaluator, 'diff', '--exit-code', 'HEAD', '--'])
    evaluator_paths = subprocess.check_output(['git', '-C', str(evaluator), 'ls-files', '-z']).decode().split('\0')
    evaluator_files = {path: sha(evaluator / path) for path in evaluator_paths if path}
    record = {
        'candidate_commit': subprocess.check_output(['git', '-C', str(src), 'rev-parse', 'HEAD'], text=True).strip(),
        'restored_source_commit': '23ca426d8b2cc1da052492115748b60641ee4241',
        'evaluator_commit': revision, 'policy_sha256': sha(policy),
        'evaluator_files': evaluator_files,
        'core_gem_sha256': sha(baseline), 'map_gem_sha256': sha(map_gem),
        'cargo_lock_sha256': sha(src / 'engine/Cargo.lock'),
        'vendor_files': len(vendored), 'packaged_files': core_files,
        'authority': 'frozen separately versioned evaluator on candidate-owned hosted orchestration; not a protected external check',
    }
    for name, command in [('ruby', [args.ruby, '--version']), ('rustc', [args.toolchain / 'rustc', '-vV']),
                          ('cargo', [args.toolchain / 'cargo', '--version']), ('cc', ['cc', '--version'])]:
        record[name] = subprocess.check_output([str(x) for x in command], text=True)
    record['toolchain_binaries'] = {str(p.resolve()): sha(p.resolve()) for p in
                                    [args.ruby, args.toolchain / 'rustc', args.toolchain / 'cargo', Path(shutil.which('cc'))]}
    record['cargo_manifest'] = (src / 'engine/Cargo.toml').read_text()
    record['native_build_command'] = 'cargo build --release --locked --offline; C bridge built by Ruby mkmf'
    (out / 'build-identity.json').write_text(json.dumps(record, indent=2) + '\n')
    work = out / 'installed-baseline'
    command = ['python3', evaluator / 'evaluate.py', '--ruby', args.ruby,
               '--toolchain-bin', args.toolchain, '--libclang-path', args.libclang,
               '--rails', '--gem', baseline, '--forbid-source-root', src, '--timeout', '300',
               '--work-dir', work, '--report', out / 'baseline-report.json']
    for dep in sorted(args.dependencies.glob('*.gem')):
        command += ['--dependency', dep.resolve()]
    run(command, cwd=out)
    report = json.loads((out / 'baseline-report.json').read_text())
    assert report['verdict'] == 'pass', report
    assert report['artifacts'][-1]['sha256'] == record['core_gem_sha256']
    env = {'PATH': str(args.ruby.parent) + ':/usr/bin:/bin', 'LANG': 'C.UTF-8',
           'GEM_HOME': str(work / 'gems'), 'GEM_PATH': str(work / 'gems')}

    def verify_core():
        for entry in report['runtime_files']:
            assert sha(work / 'gems' / entry['path']) == entry['sha256'], entry

    verify_core()
    run([args.ruby, '-S', 'gem', 'install', '--norc', '--local', '--no-document', map_gem], env=env, cwd=work / 'consumer')
    smoke, model_inputs, model_receipt = installed_smoke(
        src, out, args.ruby, work / 'consumer', env, core_files)
    smoke_report = json.loads((out / 'map-installed-smoke.json').read_text())
    assert smoke_report['native_sha256'] in [item['sha256'] for item in report['loaded_native']]
    verify_core()
    installed = {}
    for name, files in [('thistle', core_files), ('thistle-map', map_files)]:
        root = Path(smoke_report['core_gem' if name == 'thistle' else 'map_gem'])
        for path, expected in files.items():
            assert sha(root / path) == expected, (name, path)
        installed[name] = {'path': str(root), 'files': files}
    (out / 'installed-file-identities.json').write_text(json.dumps(installed, indent=2) + '\n')
    inspect_code = '''require 'json'; require 'digest'; require 'thistle'
root = Gem.loaded_specs.fetch('thistle').full_gem_path
manifest = Thistle.capture(root: root, output: ARGV.fetch(0))
reader = Thistle::Reader.new(ARGV.fetch(0), generation: manifest.fetch('generation'))
begin
  fact = reader.find('engine/src/store.rs', limit: 500).find { |f| f['kind'] == 'file' && f['path'] == 'engine/src/store.rs' }
  raise 'packaged store.rs file fact absent' unless fact
  source = reader.source(fact.fetch('id'))
  expected = File.binread(File.join(root, 'engine/src/store.rs'))
  raise 'captured bytes differ from packaged source' unless source.fetch('content').b == expected
  raise 'source digest mismatch' unless source.fetch('sha256') == Digest::SHA256.hexdigest(expected)
  puts JSON.pretty_generate(source.merge('check' => reader.check, 'build_identity' => JSON.parse(File.read(ARGV.fetch(1)))))
ensure
  reader.close
end
'''
    run_logged([args.ruby, '-e', inspect_code, out / 'self-inspection-store', out / 'build-identity.json'],
               out / 'baseline-self-inspection.json', out / 'baseline-self-inspection.stderr',
               cwd=work / 'consumer', env=env)
    verify_core()
    assert sha(baseline) == record['core_gem_sha256'], 'core package changed after qualification'
    assert sha(map_gem) == record['map_gem_sha256'], 'Map package changed during smoke/self-inspection'
    run(['git', '-C', evaluator, 'diff', '--exit-code', 'HEAD', '--'])
    assert evaluator_files == {path: sha(evaluator / path) for path in evaluator_files}, 'evaluator bytes changed'
    (out / 'tuple-verification.json').write_text(json.dumps({
        'status': 'pass', 'core_gem_sha256': sha(baseline), 'map_gem_sha256': sha(map_gem),
        'native': report['loaded_native'], 'runtime_files': report['runtime_files'],
        'core_files_verified': len(core_files), 'map_files_verified': len(map_files),
        'smoke_sha256': sha(smoke), 'baseline_report_sha256': sha(out / 'baseline-report.json'),
        'model_journey': 'pass' if model_receipt else 'not_applicable_to_selected_package',
        'model_fixture_inputs': model_inputs,
        'model_producer_receipt_sha256': sha(model_receipt) if model_receipt else None,
        'self_inspection_sha256': sha(out / 'baseline-self-inspection.json'),
    }, indent=2) + '\n')


if __name__ == '__main__':
    main()
