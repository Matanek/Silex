from pathlib import Path
import subprocess,json,hashlib
p=Path(__file__).resolve().parent
cache=Path('.zig-cache/optimizer-oracle');rows=[]
for name,count in [('AggregatePreparation',159),('Main',8),('LateScalarClosure',1)]:
 for mode in ['raw','silex']:
  source=cache/f'{name}-{mode}.ll'
  for level in ['O0','O3']:
   binary=p/f'late-final-llvm-{name}-{mode}-{level}'
   cmd=['clang','-'+level,'-target','arm64-apple-darwin25.6.0','-mcpu=apple-m1','-ffp-contract=on',str(source),'-o',str(binary)]
   build=subprocess.run(cmd,capture_output=True,text=True)
   assert build.returncode==0,build.stderr
   result=subprocess.run([str(binary)],capture_output=True,text=True,timeout=60)
   row={'case':name,'mode':mode,'level':level,'command':cmd,'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'binary_sha256':hashlib.sha256(binary.read_bytes()).hexdigest(),'build_exit':build.returncode,'build_stderr':build.stderr,'exit':result.returncode,'stdout':result.stdout,'stderr':result.stderr};rows.append(row)
   (p/'late-final-llvm-executions.json').write_text(json.dumps(rows,indent=2)+'\n')
   assert result.returncode==0 and result.stdout=='true\n'*count and not result.stderr,row
print('12 LLVM raw/Release O0/O3 executions agree')
