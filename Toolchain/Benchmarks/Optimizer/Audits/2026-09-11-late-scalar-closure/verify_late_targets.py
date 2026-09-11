from pathlib import Path
import json,subprocess,hashlib
p=Path(__file__).resolve().parent; baseline=json.loads((p/'targets.json').read_text());rows=[]
for source,tag,expected in [('Silex/Toolchain/Benchmarks/Optimizer/Regressions/AggregatePreparation.sx','preparation',159),('Silex/Toolchain/Benchmarks/Optimizer/Regressions/ValueModules/Main.sx','modules',8),('Silex/Toolchain/Benchmarks/Optimizer/Regressions/LateScalarClosure.sx','late',1)]:
 for item in baseline['records']:
  cmd=item['command'].copy();cmd[2]=source;cmd[-1]=str(p/(tag+'-late-final-'+item['target']+'-'+item['mode'].lower()));b=subprocess.run(cmd,capture_output=True,text=True);row=dict(case=tag,target=item['target'],mode=item['mode'],command=cmd,build_exit=b.returncode,build_stdout=b.stdout,build_stderr=b.stderr,execution='emission-only');rows.append(row)
  if b.returncode==0:
   exe=Path(cmd[-1]);row['binary_sha256']=hashlib.sha256(exe.read_bytes()).hexdigest();row['format']=subprocess.check_output(['file',str(exe)],text=True).strip()
   if item['target'].startswith('macos'):
    r=subprocess.run([str(exe)],capture_output=True,text=True,timeout=30);row.update(execution=item['execution'],exit=r.returncode,stdout=r.stdout,stderr=r.stderr);row['passed']=r.returncode==0 and r.stdout=='true\n'*expected and not r.stderr
   else:row['passed']=True
  (p/'late-final-targets.json').write_text(json.dumps(dict(compiler_sha256=hashlib.sha256(Path(cmd[0]).read_bytes()).hexdigest(),records=rows),indent=2)+'\n')
  assert row.get('passed'),row
print('36 emissions, 12 macOS executions agree')
