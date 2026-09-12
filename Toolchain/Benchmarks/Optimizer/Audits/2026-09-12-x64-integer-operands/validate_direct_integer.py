from pathlib import Path
import hashlib, json, os, shutil, subprocess

p = Path(__file__).parent
group = Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
tool = group / 'Silex/Toolchain'
compiler = tool / 'zig-out/bin/silex'
env = dict(os.environ, SILEX_USER_PACKAGE_ALLOWLIST='STD')
def run(cmd):
    result = subprocess.run(cmd, cwd=group, env=env, capture_output=True, text=True)
    assert result.returncode == 0, (cmd, result.returncode, result.stdout, result.stderr)
    return result
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

records = []
for before in json.loads((p / 'mixed-regions-binary-comparison.json').read_text()):
    cmd = before['command'].copy()
    cmd[0] = str(compiler)
    cmd[-1] = cmd[-1].replace('mixed-regions-', 'direct-integer-')
    run(cmd)
    binary = Path(cmd[-1])
    result = run([str(binary)])
    assert result.stdout == before['stdout']
    records.append(dict(command=cmd, workload=before['workload'], target=before['target'], sha256=sha(binary), identical_901c6f5=sha(binary)==before['sha256'], stdout=result.stdout))
(p/'direct-integer-binary-comparison.json').write_text(json.dumps(records, indent=2)+'\n')
print([(r['workload'], r['target'], r['identical_901c6f5']) for r in records], flush=True)

fixtures = [('float', tool/'Benchmarks/Optimizer/Regressions/FloatMemoryResidence.sx', 'true\n'*22), ('integer', tool/'Benchmarks/Optimizer/Regressions/IntegerMemoryRegions.sx', 'true\n'*18), ('protocol', group/'Silex/Tests/Native/NativePortability.sx', None)]
records = []
for name, source, expected in fixtures:
    directory = p / ('DirectInteger-'+name)
    directory.mkdir(exist_ok=True)
    (directory/'Package.json').write_text('{"sources":"."}\n')
    fixture = directory/source.name
    shutil.copy2(source, fixture)
    assert sha(source) == sha(fixture)
    targets = ['macos-arm64','macos-x64','linux-arm64','linux-x64','windows-arm64','windows-x64'] if name!='protocol' else ['macos-arm64','macos-x64']
    for target in targets:
        for mode in ['debug','release']:
            binary = p/f'direct-integer-{name}-{target}-{mode}'
            cmd = [str(compiler),'compile',str(fixture),f'--{mode}','--nocache','--target',target,'-o',str(binary)]
            run(cmd)
            row = dict(command=cmd, fixture_sha256=sha(fixture), target=target, mode=mode, sha256=sha(binary), executed=False)
            if target.startswith('macos-'):
                result = run([str(binary)])
                if expected is None: expected = result.stdout
                assert result.stdout == expected
                row.update(executed=True, stdout=result.stdout, stderr=result.stderr, exit=result.returncode)
            records.append(row)
(p/'direct-integer-native-validation.json').write_text(json.dumps(records, indent=2)+'\n')
shutil.copy2(compiler, p/'silex-after-direct-integer')
(p/'direct-integer-compiler.json').write_text(json.dumps({'sha256':sha(compiler)},indent=2)+'\n')
print('28 emissions, 12 native Debug/Release runs passed',flush=True)
