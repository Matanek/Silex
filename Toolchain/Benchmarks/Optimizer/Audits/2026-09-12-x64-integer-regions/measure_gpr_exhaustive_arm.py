from pathlib import Path
import hashlib, json, shutil, subprocess, sys

p = Path(__file__).parent
group = Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
sys.path.insert(0,str(group/'Silex/Toolchain/Benchmarks/Native'))
import campaign
directory = p/'gpr-exhaustive-native-arm64'
directory.mkdir(exist_ok=True)
for mode in ['clang','clang-o3-slot8']:
    shutil.copy2(p/'class-leaf-native-arm64'/f'objects-{mode}',directory/f'objects-{mode}')
shutil.copy2(p/'gpr-exhaustive-objects-macos-arm64',directory/'objects-release')
cmd=[str(p/'silex-after-gpr-exhaustive'),'compile',str(p/'NativeReference/Objects.sx'),'--debug','--nocache','-o',str(directory/'objects-debug')]
subprocess.run(cmd,cwd=group,check=True,capture_output=True)
result=campaign.measure_workload(directory,21,6,'objects',p/'class-leaf-native-arm64')
report={'candidate_compiler_sha256':hashlib.sha256((p/'silex-after-gpr-exhaustive').read_bytes()).hexdigest(),'baseline_sha':'3e584015c9dc3a1cbfa687c7e36ba6bf75eab28d','baseline_note':'Objects ARM64 identical in 6b3f302 and 3e58401; frozen class-leaf executable.','host':campaign.host_profile(),'samples':21,'warmups':6,'workloads':[result]}
(p/'gpr-exhaustive-arm-timing.json').write_text(json.dumps(report,indent=2)+'\n')
result['release_vs_references']['baseline']=result['release_vs_baseline']
print(json.dumps({'median_ms':{k:v['median_ns']/1e6 for k,v in result['configurations'].items()},'after_before':result['release_vs_baseline'],'gain_failures':campaign.qualification_failures(result,'baseline'),'parity_failures':result['qualification_failures']},indent=2))
