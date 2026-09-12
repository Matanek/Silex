from pathlib import Path
import subprocess,json,hashlib
p=Path(__file__).resolve().parent
root=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
compiler=root/'Silex/Toolchain/zig-out/bin/silex'
entries=[]
for width in [8,16,32,64]:
 for signed in [True,False]:
  t=('int' if signed else 'uint')+str(width);maximum=(1<<(width-int(signed)))-1;minimum=-maximum-1 if signed else 0
  cases=[('Add','a+b',maximum,1,t),('Subtract','a-b',minimum,1,t),('Multiply','a*b',maximum,2,t),('DivideZero','a/b',7,0,t),('RemainderZero','a%b',7,0,t),('Negate','-a',minimum if signed else 1,0,t)]
  cases += [('DivideMinimum','a/b',minimum,-1,t),('RemainderMinimum','a%b',minimum,-1,t)] if signed else [('ShiftLeftWidth','a<<b',1,width,'uint8'),('ShiftRightWidth','a>>b',maximum,width,'uint8')]
  for name,expr,a,b,rt in cases:
   entries.append((t+name,f'func calculate(a:{t}, b:{rt}) {t} {{ return {expr} }}\nfunc main() {{ print(true); print(calculate({a},{b})); print(false) }}\n',1))
  entries.append((t+'Success',f'func check(a:{t}, zero:{t}, one:{t}) bool {{ return a+zero==a && a-zero==a && a*one==a && a/one==a && a%one==zero && a>=zero && a>zero && zero<a && zero<=a && a!=zero && -zero==zero }}\nfunc main() {{ print(check({maximum},0,1)) }}\n',0))
rows=[]
for name,source,expected in entries:
 path=p/(name+'.sx');path.write_text(source)
 for target in ['macos-arm64','macos-x64']:
  for mode in ['debug','release']:
   exe=p/f'matrix-{name}-{target}-{mode}'
   command=[str(compiler),'compile',str(path),'--'+mode,'--nocache','--target',target,'-o',str(exe)]
   built=subprocess.run(command,capture_output=True,text=True);assert built.returncode==0,built.stderr
   run=subprocess.run([str(exe)],capture_output=True,text=True,timeout=30)
   row=dict(case=name,target=target,mode=mode,expected_exit=expected,exit=run.returncode,stdout=run.stdout,stderr=run.stderr,command=command,source_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),binary_sha256=hashlib.sha256(exe.read_bytes()).hexdigest())
   rows.append(row);(p/'integer-matrix.json').write_text(json.dumps(dict(compiler_sha256=hashlib.sha256(compiler.read_bytes()).hexdigest(),records=rows),indent=2)+'\n')
   assert (run.returncode,run.stdout,run.stderr)==(expected,'true\n',''),row
print('PASS',len(rows),'executions',flush=True)
