import hashlib,json,platform,statistics,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent
names=('before','forwarding','after')
bins={name:root/('view-loop-'+name) for name in names}
def run(name):
 start=time.perf_counter_ns()
 result=subprocess.run([str(bins[name])],capture_output=True,timeout=60)
 duration=time.perf_counter_ns()-start
 if result.returncode or result.stdout!=b'266\n' or result.stderr: raise RuntimeError((name,result.returncode,result.stdout,result.stderr))
 return duration
for i in range(6):
 for name in names[i%3:]+names[:i%3]: run(name)
rows=[]
for i in range(21):
 order=names[i%3:]+names[:i%3]
 row={'index':i,'order':order}
 for name in order: row[name+'_ns']=run(name)
 row['after_before']=row['after_ns']/row['before_ns']
 row['after_forwarding']=row['after_ns']/row['forwarding_ns']
 rows.append(row)
summary={}
for key in ('before_ns','forwarding_ns','after_ns','after_before','after_forwarding'):
 values=[r[key] for r in rows]; med=statistics.median(values)
 summary[key]={'median':med,'minimum':min(values),'maximum':max(values),'mad':statistics.median(abs(x-med) for x in values),'half_shift':statistics.median(values[11:])/statistics.median(values[:10])-1}
data={'mode':'diagnostic','scope':'process wall time including startup; fixed 250000-iteration view reduction; no LLVM comparator or physical X64 claim','warmup_rotations':6,'rotations':21,'host':platform.platform(),'machine':platform.machine(),'cpu':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'binary_sha256':{k:hashlib.sha256(p.read_bytes()).hexdigest() for k,p in bins.items()},'binary_bytes':{k:p.stat().st_size for k,p in bins.items()},'source_sha256':hashlib.sha256((root/'KnownViewLoop.sx').read_bytes()).hexdigest(),'observations':rows,'summary':summary}
(root/'storage-timing.json').write_text(json.dumps(data,indent=2)+'\n')
print(json.dumps(summary,indent=2))
