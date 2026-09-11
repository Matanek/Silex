import hashlib,json,platform,statistics,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent
bins={name:root/('late-leaf-'+('before' if name=='before' else 'direct')) for name in ('before','after')}
def run(name):
    start=time.perf_counter_ns()
    result=subprocess.run([str(bins[name])],capture_output=True,timeout=60)
    duration=time.perf_counter_ns()-start
    if result.returncode or result.stdout!=b'894\n' or result.stderr:
        raise RuntimeError((name,result.returncode,result.stdout,result.stderr))
    return duration
for i in range(6):
    for name in (('before','after') if i%2==0 else ('after','before')): run(name)
rows=[]
for i in range(21):
    order=('before','after') if i%2==0 else ('after','before')
    row={'index':i,'first':order[0]}
    for name in order: row[name+'_ns']=run(name)
    row['after_before']=row['after_ns']/row['before_ns']; rows.append(row)
summary={}
for key in ('before_ns','after_ns','after_before'):
    values=[r[key] for r in rows]; med=statistics.median(values)
    summary[key]={'median':med,'minimum':min(values),'maximum':max(values),'mad':statistics.median(abs(x-med) for x in values),'half_shift':statistics.median(values[11:])/statistics.median(values[:10])-1}
data={'mode':'diagnostic','scope':'process wall time for 30000000 calls to a helper that becomes scalar after memory cleanup; explicit-sharing control; same compiler; no LLVM comparator or physical X64 claim','warmup_pairs':6,'pairs':21,'host':platform.platform(),'machine':platform.machine(),'cpu':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'binary_sha256':{k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in bins.items()},'source_sha256':{name:hashlib.sha256((root/filename).read_bytes()).hexdigest() for name,filename in [('before','LateLeafLoop.sx'),('after','LateLeafDirect.sx')]},'observations':rows,'summary':summary}
(root/'late-leaf-direct-timing.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps(summary,indent=2))
