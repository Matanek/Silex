from pathlib import Path
import subprocess,re,json,shutil,sys
p=Path(__file__).parent
result={}
for kind,prefix in [('before','class-leaf'),('after','collection-results')]:
 r=subprocess.run(['/opt/homebrew/opt/llvm/bin/llvm-objdump','-d',str(p/f'{prefix}-flocking-macos-x64')],capture_output=True,text=True);assert r.returncode==0;(p/f'collection-results-flocking-{kind}.asm').write_text(r.stdout)
 funcs=[];lines=[]
 for line in r.stdout.splitlines():
  if not re.match(r'^[0-9a-f]+:',line):continue
  lines.append(line)
  if '\tretq' in line:
   funcs.append({'index':len(funcs),'start':lines[0].split(':')[0],'instructions':len(lines),'stack_accesses':sum('(%rbp)' in l for l in lines)});lines=[]
   if len(funcs)==6:break
 result[kind]=funcs
(p/'collection-results-structural.json').write_text(json.dumps({'scope':'Whole function static counts, including cold exits; not loop timing proof. Function index 2 is Flocking.steer.','functions':result},indent=2)+'\n');print(result)
