from pathlib import Path
import json, subprocess, os, hashlib

p = Path(__file__).parent
g = Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
compiler = p/'silex-after-private-class'
env = dict(os.environ, SILEX_USER_PACKAGE_ALLOWLIST='STD')
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def run(command):
    r = subprocess.run(command, cwd=g, env=env, capture_output=True, text=True)
    assert r.returncode == 0, (command, r.returncode, r.stdout, r.stderr)
    return r

results = []
for target in ('macos-arm64','macos-x64','linux-arm64','linux-x64','windows-arm64','windows-x64'):
    for mode in ('debug','release'):
        binary = p/f'private-class-fixture-{target}-{mode}'
        command = [str(compiler),'compile',str(p/'PrivateClassNative/ScalarClassLeaves.sx'),'--'+mode,'--nocache','--target',target,'-o',str(binary)]
        run(command)
        row = dict(target=target, mode=mode, command=command, sha256=sha(binary), executed=False)
        if target.startswith('macos-'):
            r = run([str(binary)])
            assert r.stdout == 'true\n'*18, (target,mode,r.stdout)
            row.update(executed=True,stdout=r.stdout,stderr=r.stderr,exit_code=r.returncode)
        results.append(row)
(p/'private-class-native-validation.json').write_text(json.dumps(results,indent=2)+'\n')
print('12 emissions and 4 native macOS runs passed',flush=True)

results = []
for before in json.loads((p/'direct-integer-binary-comparison.json').read_text()):
    command = before['command'].copy()
    command[0] = str(compiler)
    command[-1] = command[-1].replace('direct-integer-', 'private-class-')
    run(command)
    binary = Path(command[-1])
    r = run([str(binary)])
    assert r.stdout == before['stdout']
    results.append(dict(command=command,workload=before['workload'],target=before['target'],sha256=sha(binary),identical_b8d01d7=sha(binary)==before['sha256'],stdout=r.stdout))
(p/'private-class-binary-comparison.json').write_text(json.dumps(results,indent=2)+'\n')
print([(r['workload'],r['target'],r['identical_b8d01d7']) for r in results],flush=True)
