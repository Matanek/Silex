from pathlib import Path
import json,subprocess,hashlib,os
p=Path(__file__).parent;g=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
new=p/'silex-after-private-class-target-policy'; rows=[]
def run(cmd):
 r=subprocess.run(cmd,cwd=g,env=dict(os.environ,SILEX_USER_PACKAGE_ALLOWLIST='STD'),capture_output=True,text=True);assert r.returncode==0,(cmd,r.stdout,r.stderr);return r
def sha(f):return hashlib.sha256(f.read_bytes()).hexdigest()
for target in ['macos-arm64','macos-x64','linux-arm64','linux-x64','windows-arm64','windows-x64']:
 for mode in ['debug','release']:
  f=p/f'private-class-final-fixture-{target}-{mode}';cmd=[str(new),'compile',str(p/'PrivateClassNative/ScalarClassLeaves.sx'),'--'+mode,'--nocache','--target',target,'-o',str(f)];run(cmd)
  row=dict(target=target,mode=mode,command=cmd,sha256=sha(f),executed=target.startswith('macos'))
  if row['executed']:
   r=run([str(f)]);assert r.stdout=='true\n'*18;row.update(stdout=r.stdout,stderr=r.stderr,exit_code=r.returncode)
  rows.append(row)
(p/'private-class-final-native-validation.json').write_text(json.dumps(rows,indent=2)+'\n')
rows=[]
for target in ['macos-arm64','macos-x64']:
 for workload in ['Arithmetic','Objects','Flocking']:
  old=p/f'{"private-class" if target.endswith("arm64") else "direct-integer"}-{workload.lower()}-{target}'
  for cached in [False,True,True]:
   new_file=p/f'private-class-final-{workload.lower()}-{target}';cmd=[str(new),'compile',str(p/'NativeReference'/f'{workload}.sx'),'--release','--target',target,'-o',str(new_file)]
   if not cached:cmd+=['--nocache']
   run(cmd);assert old.read_bytes()==new_file.read_bytes(),(target,workload,cached)
   rows.append(dict(target=target,workload=workload,cached=cached,command=cmd,sha256=sha(new_file),identical_to=str(old)))
(p/'private-class-final-binary-identity.json').write_text(json.dumps(rows,indent=2)+'\n')
print('12 emissions; 4 native executions; 18 cached/uncached binary identities verified',flush=True)
