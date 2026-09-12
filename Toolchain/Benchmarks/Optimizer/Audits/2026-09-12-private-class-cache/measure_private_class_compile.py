from pathlib import Path
import subprocess, os, time, json, statistics
p=Path(__file__).parent
g=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
rows=[]
for target in ['macos-arm64','macos-x64']:
 for i in range(13):
  for label in (['before','after'] if i%2==0 else ['after','before']):
   binary=p/('silex-after-direct-integer' if label=='before' else 'silex-after-private-class')
   output=p/f'private-class-compile-budget-{target}-{label}'
   cmd=[str(binary),'compile',str(p/'NativeReference/Objects.sx'),'--release','--nocache','--target',target,'-o',str(output)]
   start=time.perf_counter_ns()
   with open(p/'private-class-compile-budget-last.log','w') as log:
    child=subprocess.Popen(cmd,cwd=g,stdout=log,stderr=log,env=dict(os.environ,SILEX_USER_PACKAGE_ALLOWLIST='STD'))
    _,status,usage=os.wait4(child.pid,0);child.returncode=os.waitstatus_to_exitcode(status)
   elapsed=time.perf_counter_ns()-start;assert child.returncode==0
   rows.append(dict(target=target,index=i,warmup=i<2,configuration=label,elapsed_ns=elapsed,cpu_seconds=usage.ru_utime+usage.ru_stime,max_rss_bytes=usage.ru_maxrss,binary_bytes=output.stat().st_size,command=cmd))
summary=[]
for target in ['macos-arm64','macos-x64']:
 d={}
 for label in ['before','after']:
  r=[x for x in rows if x['target']==target and x['configuration']==label and not x['warmup']]
  d[label]={k:statistics.median(x[k] for x in r) for k in ['elapsed_ns','cpu_seconds','max_rss_bytes','binary_bytes']}
 summary.append(dict(target=target,measurements=d))
(p/'private-class-compile-budget.json').write_text(json.dumps(dict(diagnostic_only=True,samples=11,warmups=2,summary=summary,observations=rows),indent=2)+'\n')
print(json.dumps(summary,indent=2))
