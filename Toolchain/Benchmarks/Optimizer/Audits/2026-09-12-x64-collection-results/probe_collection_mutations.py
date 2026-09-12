from pathlib import Path
import json,subprocess,shutil
p=Path(__file__).parent;target=p/'CollectionResultsMutationSources';assert not target.exists();shutil.copytree('Sources',target)
probe=target/'X64LoadProbe.zig';probe.write_text('test { _ = @import("X64/RegisterAllocation.zig"); }\n')
cmd=json.loads((p/'collection-results-targeted-command.json').read_text());cmd=[f'-Mroot={probe}' if x.startswith('-Mroot=') else x for x in cmd]
results=[]
for name in ['stack-results','dead-siblings']:
 f=target/('X64/RegisterAllocation.zig' if name=='stack-results' else 'Arm64/RegisterAllocation.zig');original=f.read_text()
 if name=='stack-results':mutated=original.replace('.collection_load => .collection_inputs,','.collection_load => .stack_operands,',1)
 else:mutated=original.replace('!successorLive(function.instructions, collection_live.?, function.slot_count, index, slot)','false and !successorLive(function.instructions, collection_live.?, function.slot_count, index, slot)',1)
 assert mutated!=original;f.write_text(mutated)
 r=subprocess.run(cmd,capture_output=True,text=True);(p/f'collection-results-mutation-{name}.log').write_text(r.stdout+r.stderr);assert r.returncode!=0 and 'TestUnexpectedResult' in r.stderr or r.returncode!=0 and 'TestExpectedEqual' in r.stderr,(name,r.stdout,r.stderr)
 results.append({'mutation':name,'command':cmd,'exit':r.returncode});f.write_text(original)
(p/'collection-results-mutations.json').write_text(json.dumps(results,indent=2)+'\n');print(results)
