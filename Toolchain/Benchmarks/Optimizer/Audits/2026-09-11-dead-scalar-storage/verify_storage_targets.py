import hashlib,json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
previous=json.loads((root/'targets.json').read_text())
records=[]
for item in previous['records']:
 command=item['command'].copy(); command[-1]=str(root/('storage-'+Path(command[-1]).name))
 build=subprocess.run(command,text=True,capture_output=True)
 record={'target':item['target'],'mode':item['mode'],'command':command,'build_exit':build.returncode,'build_stdout':build.stdout,'build_stderr':build.stderr}
 records.append(record)
 if build.returncode: break
 binary=Path(command[-1]); record['sha256']=hashlib.sha256(binary.read_bytes()).hexdigest()
 record['format']=subprocess.check_output(['file',str(binary)],text=True).strip()
 if item['target'].startswith('macos'):
  run=subprocess.run([str(binary)],text=True,capture_output=True,timeout=60)
  record.update(run_exit=run.returncode,stdout=run.stdout,stderr=run.stderr,execution=item['execution'])
  record['passed']=run.returncode==0 and run.stdout=='true\n'*7 and not run.stderr
 else: record['execution']='emission-only'; record['passed']=True
 if not record['passed']: break
compiler=Path(previous['records'][0]['command'][0])
source=Path(previous['records'][0]['command'][2])
data={'compiler_sha256':hashlib.sha256(compiler.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'records':records}
(root/'storage-targets.json').write_text(json.dumps(data,indent=2)+'\n')
assert len(records)==12 and all(r.get('passed') for r in records)
print('12 target emissions and 4 native executions passed')
