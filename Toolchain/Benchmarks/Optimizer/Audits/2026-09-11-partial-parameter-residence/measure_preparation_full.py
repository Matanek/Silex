from pathlib import Path
import subprocess,sys,json,hashlib,statistics,platform
root=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree');sys.path.insert(0,str(root/'Packages/GFX.Physics/Benchmarks/Oracle2D'));import RunStageKernels as stages
sys.path.insert(0,str(root/'Silex/Toolchain/Benchmarks/Native'));import campaign
p=Path(__file__).resolve().parent;names=('before','after','clang');binaries={n:p/('preparation-full-'+n) for n in names};signature=json.loads((p/'preparation-full-correctness.json').read_text())['signature_interval']
def run(name):
 r=subprocess.run([str(binaries[name])],capture_output=True,text=True,timeout=120)
 if r.returncode or r.stderr:raise RuntimeError((name,r.returncode,r.stderr))
 result=stages.timing(r.stdout,'preparation','clang-slots' if name=='clang' else 'silex',signature);result['stdout']=r.stdout;return result
for i in range(6):
 for n in names[i%3:]+names[:i%3]:run(n)
rows=[]
for i in range(21):
 order=names[i%3:]+names[:i%3];row={'index':i,'order':order,'runs':{n:run(n) for n in order}}
 for left,right in [('after','before'),('after','clang'),('before','clang')]:row[left+'_'+right]=row['runs'][left]['elapsed_ms']/row['runs'][right]['elapsed_ms']
 rows.append(row);(p/'preparation-full-timing-partial.json').write_text(json.dumps(rows,indent=2)+'\n')
summary={}
for key in ['after_before','after_clang','before_clang']:
 values=[r[key] for r in rows];med=statistics.median(values);bound,confidence=campaign.one_sided_median_bound(len(values));ordered=sorted(values)
 summary[key]=dict(median=med,mad=statistics.median(abs(v-med) for v in values),lower_bound=ordered[len(values)-1-bound],upper_bound=ordered[bound],confidence_ppm=confidence,half_shift=statistics.median(values[11:])/statistics.median(values[:10])-1)
for n in names:
 values=[r['runs'][n]['elapsed_ms'] for r in rows];med=statistics.median(values);summary[n]=dict(median_ms=med,mad_ms=statistics.median(abs(v-med) for v in values))
result=dict(scope='physical ARM64 complete preparation; 8192 elements, 2048 passes, all 26 output fields in signature; same slot8 layout; no X64 claim',host=platform.platform(),machine=platform.machine(),cpu=subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),compiler_sha256=hashlib.sha256((root/'Silex/Toolchain/zig-out/bin/silex').read_bytes()).hexdigest(),binaries={n:hashlib.sha256(path.read_bytes()).hexdigest() for n,path in binaries.items()},warmups=6,samples=21,observations=rows,summary=summary)
(p/'preparation-full-timing.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(summary,indent=2))
