from pathlib import Path
import json,subprocess,os,shutil,hashlib
p=Path(__file__).parent
root=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
tool=root/'Silex/Toolchain'; compiler=tool/'zig-out/bin/silex'
fixture=p/'CollectionResultsFixture';fixture.mkdir(exist_ok=True);(fixture/'Package.json').write_text('{"sources":"."}\n');shutil.copy2(tool/'Benchmarks/Optimizer/Regressions/FloatMemoryResidence.sx',fixture/'Main.sx')
env=dict(os.environ,SILEX_USER_PACKAGE_ALLOWLIST='STD')
records=[]
for target in ['macos-arm64','macos-x64','linux-arm64','linux-x64','windows-arm64','windows-x64']:
 for mode in ['debug','release']:
  out=p/f'collection-results-{target}-{mode}'
  cmd=[str(compiler),'compile',str(fixture/'Main.sx'),f'--{mode}','--nocache','--target',target,'-o',str(out)]
  r=subprocess.run(cmd,cwd=root,env=env,capture_output=True,text=True)
  row={'command':cmd,'compile_exit':r.returncode,'compile_output':r.stdout+r.stderr};records.append(row)
  assert r.returncode==0,row
  row['sha256']=hashlib.sha256(out.read_bytes()).hexdigest()
  if target.startswith('macos'):
   r=subprocess.run([str(out)],cwd=root,capture_output=True,text=True);row.update(exit=r.returncode,stdout=r.stdout,stderr=r.stderr);assert r.returncode==0 and r.stdout=='true\n'*13,row
  (p/'collection-results-native-validation.json').write_text(json.dumps(records,indent=2)+'\n')
print('12 emissions; 4 native runs; 13 true each',flush=True)
records=[]
for row in json.loads((p/'class-leaf-binary-comparison.json').read_text()):
 cmd=row['command'].copy();cmd[-1]=cmd[-1].replace('class-leaf-','collection-results-');r=subprocess.run(cmd,cwd=root,env=env,capture_output=True,text=True);assert r.returncode==0,r.stderr
 out=Path(cmd[-1]);r=subprocess.run([str(out)],cwd=root,capture_output=True,text=True);assert r.returncode==0 and r.stdout==row['stdout'],r
 sha=hashlib.sha256(out.read_bytes()).hexdigest();records.append({'workload':row['workload'],'target':row['target'],'command':cmd,'sha256':sha,'identical_6b3f302':sha==row['sha256'],'stdout':r.stdout})
 (p/'collection-results-binary-comparison.json').write_text(json.dumps(records,indent=2)+'\n')
print([(r['workload'],r['target'],r['identical_6b3f302']) for r in records])
shutil.copy2(compiler,p/'silex-after-collection-results')
