from pathlib import Path
import subprocess,json,hashlib
root=Path(__file__).resolve().parent
compiler=Path('Silex/Toolchain/zig-out/bin/silex').resolve(); src=root/'StorageChecks/UnusedInitializerFailure.sx'
records=[]
for target in ('macos-arm64','macos-x64'):
 for mode in ('debug','release'):
  binary=root/('initializer-'+target+'-'+mode)
  command=[str(compiler),'compile',str(src),'--nocache','--'+mode,'--target',target,'-o',str(binary)]
  build=subprocess.run(command,text=True,capture_output=True)
  record={'target':target,'mode':mode,'command':command,'build_exit':build.returncode,'build_stderr':build.stderr}; records.append(record)
  if build.returncode: break
  run=subprocess.run([str(binary)],text=True,capture_output=True,timeout=60)
  record.update(binary_sha256=hashlib.sha256(binary.read_bytes()).hexdigest(),exit=run.returncode,stdout=run.stdout,stderr=run.stderr)
  record['passed']=run.returncode==1 and not run.stdout and not run.stderr
records_ok=len(records)==4 and all(r.get('passed') for r in records)
if records_ok:
 records_ok=len({(r['exit'],r['stderr']) for r in records})==1
(root/'storage-initializer-failures.json').write_text(json.dumps({'compiler_sha256':hashlib.sha256(compiler.read_bytes()).hexdigest(),'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest(),'records':records,'passed':records_ok},indent=2)+'\n')
for record in records: print(record['target'],record['mode'],record.get('exit'),record.get('stderr',record.get('build_stderr')))
assert records_ok
