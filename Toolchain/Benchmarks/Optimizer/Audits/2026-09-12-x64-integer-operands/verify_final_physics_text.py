from pathlib import Path
import subprocess,json,hashlib,struct
p=Path(__file__).parent;g=Path('/Users/nekmata/Projects/SilexProject/.specs/Silex-Optimization-Parity-Completion/Worktree')
def machine_text(path):
 b=path.read_bytes();assert struct.unpack_from('<I',b)[0]==0xfeedfacf
 offset=32
 for _ in range(struct.unpack_from('<I',b,16)[0]):
  cmd,size=struct.unpack_from('<II',b,offset)
  if cmd==0x19:
   for i in range(struct.unpack_from('<I',b,offset+64)[0]):
    section=offset+72+i*80
    if b[section:section+16].rstrip(b'\0')==b'__text':
     length=struct.unpack_from('<Q',b,section+40)[0];start=struct.unpack_from('<I',b,section+48)[0];return b[start:start+length]
  offset+=size
 raise AssertionError('text missing')
rows=[]
for before in json.loads((p/'gpr-exhaustive-physics-code-comparison.json').read_text()):
 cmd=before['command'].copy();cmd[0]=str(p/'silex-after-direct-integer');old=Path(cmd[-1]);cmd[-1]=cmd[-1].replace('gpr-exhaustive','direct-integer');r=subprocess.run(cmd,cwd=g,capture_output=True,text=True);assert r.returncode==0,(cmd,r.stdout,r.stderr);new=Path(cmd[-1]);a=machine_text(old);b=machine_text(new);assert a==b,before['stage'];rows.append(dict(stage=before['stage'],command=cmd,baseline_file=str(old),binary_sha256=hashlib.sha256(new.read_bytes()).hexdigest(),text_sha256=hashlib.sha256(b).hexdigest(),same_text_as_40dc120=True,text_bytes=len(b)))
(p/'direct-integer-physics-code-comparison.json').write_text(json.dumps(rows,indent=2)+'\n');print([(x['stage'],x['same_text_as_40dc120']) for x in rows])
