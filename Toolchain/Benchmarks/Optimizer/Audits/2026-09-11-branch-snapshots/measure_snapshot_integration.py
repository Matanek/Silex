from pathlib import Path
import sys,subprocess,json,hashlib,platform
root=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree');sys.path.insert(0,str(root/'Packages/GFX.Physics/Benchmarks/Oracle2D'));import RunStageKernels as stages
sys.path.insert(0,str(root/'Silex/Toolchain/Benchmarks/Native'));import campaign
p=Path(__file__).parent;correct=json.loads((p/'snapshot-physics-correctness.json').read_text());results=json.loads((p/'snapshot-physics-timing.json').read_text())['workloads']
for stage in ['integration']:
 names=['baseline','release','clang'];bins={name:p/('preparation-full-clang' if stage=='preparation' and name=='clang' else f'{stage}-snapshot-'+{'baseline':'before','release':'after','clang':'clang'}[name]) for name in names}
 def run(name):
  r=subprocess.run([str(bins[name])],capture_output=True,text=True,timeout=60)
  if r.returncode or r.stderr:raise RuntimeError((name,r.returncode,r.stderr))
  value=stages.timing(r.stdout,stage,'clang-slots' if name=='clang' else 'silex',correct[stage]['records'][{'baseline':'before','release':'after','clang':'clang'}[name]]['signature_interval']);value['stdout']=r.stdout;return value
 for i in range(6):
  for name in names[i%3:]+names[:i%3]:run(name)
 observations=[]
 for i in range(21):
  order=names[i%3:]+names[:i%3];runs={n:run(n) for n in order};observations.append({'index':i,'order':order,'runs':runs,'timings_ns':{n:round(r['elapsed_ms']*1e6) for n,r in runs.items()}})
  (p/f'snapshot-{stage}-timing-partial.json').write_text(json.dumps(observations,indent=2)+'\n')
 row={'id':stage,'observations':observations,'configurations':{n:campaign.summarize([r['timings_ns'][n] for r in observations]) for n in names},'release_vs_clang':campaign.analyze_release_vs_clang(observations),'release_vs_references':{'baseline':campaign.analyze_release_vs_clang(observations,'baseline')},'binaries':{n:{'path':str(b),'sha256':hashlib.sha256(b.read_bytes()).hexdigest()} for n,b in bins.items()}}
 row['parity_failures']=campaign.qualification_failures(row);row['gain_failures']=campaign.qualification_failures(row,'baseline');results.append(row)
 print(json.dumps({'stage':stage,'median_ms':{n:row['configurations'][n]['median_ns']/1e6 for n in names},'after_before':row['release_vs_references']['baseline']['median_ppm'],'after_clang':row['release_vs_clang']['median_ppm'],'gain_failures':row['gain_failures'],'parity_failures':row['parity_failures']},indent=2),flush=True)
 report={'scope':'Physical ARM64 complete canonical Physics stages, same slots8 layout; no X64 performance claim','host':campaign.host_profile(),'os':platform.platform(),'warmups':6,'samples':21,'compiler_sha256':hashlib.sha256((root/'Silex/Toolchain/zig-out/bin/silex').read_bytes()).hexdigest(),'workloads':results};(p/'snapshot-physics-timing.json').write_text(json.dumps(report,indent=2)+'\n')
