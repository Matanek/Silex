from pathlib import Path
import sys,subprocess,json,hashlib
root=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
sys.path.insert(0,str(root/'Packages/GFX.Physics/Benchmarks/Oracle2D'));import RunStageKernels as stages
sys.path.insert(0,str(root/'Silex/Toolchain/Benchmarks/Native'));import campaign
p=Path(__file__).parent;old=json.loads((p/'snapshot-physics-correctness.json').read_text());new=json.loads((p/'cfg-residence-physics-correctness.json').read_text());results=[]
for stage in ['preparation','integration']:
 names=['baseline','release','clang'];bins={'baseline':p/f'{stage}-snapshot-after','release':p/f'{stage}-cfg-residence','clang':p/('preparation-full-clang' if stage=='preparation' else 'integration-snapshot-clang')}
 signatures={'baseline':old[stage]['records']['after']['signature_interval'],'release':new[stage]['signature_interval'],'clang':old[stage]['records']['clang']['signature_interval']}
 def run(name):
  r=subprocess.run([str(bins[name])],capture_output=True,text=True,timeout=60)
  if r.returncode or r.stderr:raise RuntimeError((name,r.returncode,r.stderr))
  value=stages.timing(r.stdout,stage,'clang-slots' if name=='clang' else 'silex',signatures[name]);value['stdout']=r.stdout;return value
 for i in range(6):
  for name in names[i%3:]+names[:i%3]:run(name)
 observations=[]
 for i in range(21):
  order=names[i%3:]+names[:i%3];runs={n:run(n) for n in order};observations.append({'index':i,'order':order,'runs':runs,'timings_ns':{n:round(r['elapsed_ms']*1e6) for n,r in runs.items()}})
 row={'id':stage,'observations':observations,'configurations':{n:campaign.summarize([r['timings_ns'][n] for r in observations]) for n in names},'release_vs_clang':campaign.analyze_release_vs_clang(observations),'release_vs_references':{'baseline':campaign.analyze_release_vs_clang(observations,'baseline')},'binaries':{n:{'path':str(b),'sha256':hashlib.sha256(b.read_bytes()).hexdigest()} for n,b in bins.items()}}
 row['parity_failures']=campaign.qualification_failures(row);row['gain_failures']=campaign.qualification_failures(row,'baseline');results.append(row)
 print(json.dumps({'stage':stage,'median_ms':{n:row['configurations'][n]['median_ns']/1e6 for n in names},'after_before':row['release_vs_references']['baseline'],'after_clang':row['release_vs_clang']['median_ppm'],'gain_failures':row['gain_failures'],'parity_failures':row['parity_failures']},indent=2),flush=True)
 report={'scope':'Physical ARM64 complete canonical Physics stages, same slots8 layout','candidate_sha':'225ba12f8d8b4f2e434c0ae18bd0b6269c909373','baseline_sha':'5ff94ab7471b4d2c2b1d3c7cbdb03b6572bbceae','host':campaign.host_profile(),'warmups':6,'samples':21,'workloads':results};(p/'cfg-physics-timing.json').write_text(json.dumps(report,indent=2)+'\n')
