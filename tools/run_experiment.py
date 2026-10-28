#!/usr/bin/env python3
"""Run the unchanged development policy once, after both exact artifacts qualify."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def run(command, log):
    with log.open('w') as stream:
        subprocess.run([str(x) for x in command], stdout=stream, stderr=subprocess.STDOUT, check=True)


def main():
    p = argparse.ArgumentParser()
    for name in ['baseline_source', 'candidate_source', 'accepted', 'evaluator', 'output', 'ruby', 'toolchain', 'libclang', 'dependencies']:
        p.add_argument('--' + name.replace('_', '-'), type=Path, required=True)
    a = p.parse_args()
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    for arm in ['baseline', 'candidate']:
        (out / arm).mkdir()
    expected = {'thistle.gem': 'fc9fb44db77817dcb65dd9d4d23e601e0661b8116ebd4071c1c94b2d747d527e',
                'thistle-map.gem': 'c19c41173588ea6929a675539cf549e429950442fe36382d49c1fa6edc472bf7'}
    for name, digest in expected.items():
        assert sha(a.accepted / 'packages' / name) == digest, 'accepted package identity mismatch'
    for arm, src in [('baseline', a.baseline_source), ('candidate', a.candidate_source)]:
        packages = src / 'pkg/hardened-baseline'
        packages.mkdir(parents=True, exist_ok=True)
        for name in expected:
            if arm == 'baseline' or name == 'thistle-map.gem':
                shutil.copyfile(a.accepted / 'packages' / name, packages / name)
        args = ['python3', a.candidate_source / 'tools/qualify_baseline.py', '--source', src,
                '--evaluator', a.evaluator, '--output', out / arm, '--ruby', a.ruby,
                '--toolchain', a.toolchain, '--libclang', a.libclang, '--dependencies', a.dependencies]
        run(args, out / (arm + '-quality.log'))
        for package in packages.glob('*.gem'):
            (out / arm / 'packages').mkdir(exist_ok=True)
            shutil.copyfile(package, out / arm / 'packages' / package.name)
    assert sha(a.baseline_source / 'pkg/hardened-baseline/thistle.gem') == expected['thistle.gem']
    # Only search preparation/reuse and its tests differ in the native/Ruby core.
    for name in ['lib', 'ext', 'engine/src', '.cargo']:
        for original in (a.baseline_source / name).rglob('*'):
            if not original.is_file():
                continue
            relative = original.relative_to(a.baseline_source)
            if relative.as_posix() == 'engine/src/store.rs':
                continue
            assert sha(original) == sha(a.candidate_source / relative), str(relative)
    policy = a.evaluator / 'policies/experiment-001.json'
    assert sha(policy) == '14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe'
    command = ['python3', a.evaluator / 'compare.py', '--ruby', a.ruby,
               '--baseline-home', out / 'baseline/installed-baseline/gems',
               '--candidate-home', out / 'candidate/installed-baseline/gems', '--policy', policy,
               '--baseline-quality-report', out / 'baseline/baseline-report.json',
               '--candidate-quality-report', out / 'candidate/baseline-report.json',
               '--pairs', '20', '--calibration-pairs', '4', '--classes', '400', '--queries', '100',
               '--seed', '20261028', '--report', out / 'experiment-001.json']
    run(command, out / 'comparison.log')
    assert sha(policy) == '14f69505966970cf639fe6b462269f3ba301cf1cc95533b5c81aa544a3dd6dfe'
    print(json.dumps(json.loads((out / 'experiment-001.json').read_text())['decision'], indent=2))


if __name__ == '__main__':
    main()
