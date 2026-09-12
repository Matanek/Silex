from pathlib import Path
import json,sys,hashlib,shutil
root=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
sys.path.insert(0,str(root/'Silex/Toolchain/Benchmarks/Native'))
import campaign
p=Path(__file__).parent
directory=p/'private-length-native-arm64';directory.mkdir(exist_ok=True)
for mode in ['debug','clang','clang-o3-slot8']:
    shutil.copy2(p/'cfg-native-arm64'/f'objects-{mode}',directory/f'objects-{mode}')
shutil.copy2(p/'private-length-objects-macos-arm64',directory/'objects-release')
result=campaign.measure_workload(directory,21,6,'objects',p/'cfg-native-arm64')
report={'candidate_compiler_sha256':hashlib.sha256((root/'Silex/Toolchain/zig-out/bin/silex').read_bytes()).hexdigest(),'baseline_sha':'886cc17e59203c7c6b42190ddfe28239a0ece81d','baseline_note':'Objects ARM64 binary identical between 225ba12 and 886cc17; retained frozen executable. Debug is the unchanged original reference.','host':campaign.host_profile(),'samples':21,'warmups':6,'workloads':[result]}
(p/'private-length-objects-timing.json').write_text(json.dumps(report,indent=2)+'\n')
result['release_vs_references']['baseline']=result['release_vs_baseline']
print(json.dumps({'median_ms':{n:v['median_ns']/1e6 for n,v in result['configurations'].items()},'after_before':result['release_vs_baseline'],'gain_failures':campaign.qualification_failures(result,'baseline'),'parity_failures':result['qualification_failures']},indent=2))
