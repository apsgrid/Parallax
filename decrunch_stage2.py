from pathlib import Path
import hashlib,json
base=Path(r"E:\Projects\Parallax\Unpacked")
mem=bytearray((base/"ram_after_decrunch.bin").read_bytes())
for a in range(0xD6BF,0x07BF,-1):
    mem[a+0x293F]=mem[a]
source=0x31AC
dest=0x0800
stats={"input_bytes":0,"output_bytes":0,"runs":0,"run_bytes":0,"triples":0,"triple_bytes":0,"literals":0}
def rb():
    global source
    if source==0xFFFF: raise StopIteration
    b=mem[source]; source=(source+1)&0xFFFF; stats["input_bytes"]+=1; return b
def wb(v):
    global dest
    mem[dest]=v; dest=(dest+1)&0xFFFF; stats["output_bytes"]+=1
try:
    while True:
        b=rb()
        if b==0xBB:
            count=rb(); val=rb(); stats["runs"]+=1; stats["run_bytes"]+=count
            for _ in range(count): wb(val)
        elif b==0xED:
            val=rb(); stats["triples"]+=1; stats["triple_bytes"]+=3
            for _ in range(3): wb(val)
        else:
            stats["literals"]+=1; wb(b)
except StopIteration:
    pass
runtime_lo=0x0800
runtime_hi=(dest-1)&0xFFFF
(base/"runtime_ram.bin").write_bytes(mem)
(base/"runtime_image.bin").write_bytes(mem[runtime_lo:runtime_hi+1])
report={"relocated_input_start":0x31AC,"relocated_input_end":0xFFFE,"runtime_output_start":runtime_lo,"runtime_output_end":runtime_hi,"runtime_entry":0x0B40,"stats":stats,"runtime_image_sha256":hashlib.sha256(mem[runtime_lo:runtime_hi+1]).hexdigest()}
(base/"runtime_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report,indent=2))
