from pathlib import Path
import json,sys,hashlib,zipfile
p=Path(__file__).parent;name=sys.argv[1];directory=p/f'{name}-intel';archive=p/f'{name}-intel.zip'
if not directory.exists():
 with zipfile.ZipFile(archive) as z:
  for f in z.namelist():assert not f.startswith('/') and '..' not in Path(f).parts
  z.extractall(directory)
r=json.loads((directory/'optimizer-x64/campaign.json').read_text());repo=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree/Silex/Toolchain');sys.path.insert(0,str(repo/'Benchmarks/Native'));import campaign
checks=[];summaries=[]
for w in r['workloads']:
 for configuration,e in w['executables'].items():
  rel=e['path'].split('.zig-cache/')[-1];f=directory/rel;sha=hashlib.sha256(f.read_bytes()).hexdigest();assert sha==e['sha256'],str(f);checks.append({'workload':w['id'],'configuration':configuration,'path':rel,'sha256':sha})
 w['release_vs_references']['baseline']=w['release_vs_baseline']
 failures=campaign.qualification_failures(w,'baseline');stability=[f for f in failures if 'upper bound' not in f]
 summaries.append({'workload':w['id'],'median_ms':{k:v['median_ns']/1e6 for k,v in w['configurations'].items()},'after_before':w['release_vs_baseline'],'baseline_stability_failures':stability,'gain_qualification_failures':failures,'references':w['release_vs_references'],'parity_failures':w['qualification_failures']})
result={'candidate':r['candidate_sha'],'baseline':r['baseline_sha'],'host':r['host'],'clang':r['clang'],'samples':r['samples'],'warmups':r['warmups'],'archive_sha256':hashlib.sha256(archive.read_bytes()).hexdigest(),'archive_files':len([f for f in directory.rglob('*') if f.is_file()]),'checked_executables':checks,'workloads':summaries}
(p/f'{name}-intel-summary.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'candidate':result['candidate'],'baseline':result['baseline'],'host':result['host'],'workloads':summaries},indent=2))
