from pathlib import Path
import hashlib,json,platform,statistics,subprocess,time,sys
p=Path(__file__).resolve().parent
sys.path.insert(0,'/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree/Silex/Toolchain/Benchmarks/Native')
import campaign
names=('before','after');bins={n:p/('floating-regions-'+n) for n in names}
def run(n):
 start=time.perf_counter_ns();r=subprocess.run([str(bins[n])],capture_output=True,timeout=60);elapsed=time.perf_counter_ns()-start
 assert r.returncode==0 and r.stdout==b'3000000\n35.999138\n' and not r.stderr,(n,r)
 return elapsed
for i in range(6):
 for n in names[i%2:]+names[:i%2]:run(n)
rows=[]
for i in range(21):
 order=names[i%2:]+names[:i%2];row={'index':i,'order':order,'runs':{n:run(n) for n in order}};row['ratio']=row['runs']['after']/row['runs']['before'];rows.append(row)
ratios=[r['ratio'] for r in rows];median=statistics.median(ratios);bound,confidence=campaign.one_sided_median_bound(len(ratios));ordered=sorted(ratios)
summary={'paired_median':median,'lower':ordered[len(ratios)-1-bound],'upper':ordered[bound],'confidence_ppm':confidence,'mad':statistics.median(abs(x-median) for x in ratios),'half_shift':statistics.median(ratios[11:])/statistics.median(ratios[:10])-1}
for n in names:summary[n+'_median_ms']=statistics.median(r['runs'][n] for r in rows)/1e6
result={'scope':'physical ARM64 process wall time including startup; eight floating recurrences after a real call; 3000000 iterations; no X64 claim','host':platform.platform(),'cpu':subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),'binaries':{n:hashlib.sha256(b.read_bytes()).hexdigest() for n,b in bins.items()},'source':hashlib.sha256((p/'Regions/FloatingRegions.sx').read_bytes()).hexdigest(),'warmups':6,'samples':21,'rows':rows,'summary':summary}
(p/'floating-regions-timing.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(summary,indent=2))
