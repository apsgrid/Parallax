from pathlib import Path
import hashlib,json
base=Path(r"E:\Projects\Parallax\Unpacked")
mem=bytearray((base/"runtime_ram.bin").read_bytes())
# Overlay relocation: 171A-D719 -> 3FFF-FFFE.
for a in range(0xD719,0x1719,-1):
    mem[a+0x28E5]=mem[a]
source=0x4200
dest=0x0800
stats={"input_bytes":0,"output_bytes":0,"runs":0,"triples":0,"spaces":0,"zeros":0,"literals":0}
def rb():
    global source
    if source==0xFFFF: raise StopIteration
    b=mem[source]; source=(source+1)&0xFFFF; stats["input_bytes"]+=1; return b
def wb(v,n=1):
    global dest
    for _ in range(n):
        mem[dest]=v; dest=(dest+1)&0xFFFF; stats["output_bytes"]+=1
try:
    while True:
        b=rb()
        if b==0xDE:
            n=rb(); v=rb(); stats["runs"]+=1; wb(v,n)
        elif b==0x9B:
            v=rb(); stats["triples"]+=1; wb(v,3)
        elif b==0xD9:
            n=rb(); stats["spaces"]+=1; wb(0x20,n)
        elif b==0xB6:
            n=rb(); stats["zeros"]+=1; wb(0x00,n)
        else:
            stats["literals"]+=1; wb(b)
except StopIteration:
    pass
lo=0x0800
hi=(dest-1)&0xFFFF
(base/"overlay_game_ram.bin").write_bytes(mem)
(base/"overlay_game_image.bin").write_bytes(mem[lo:hi+1])
report={"relocated_input_start":0x4200,"relocated_input_end":0xFFFE,"output_start":lo,"output_end":hi,"entry":0xCA98,"stats":stats,"sha256":hashlib.sha256(mem[lo:hi+1]).hexdigest()}
(base/"overlay_game_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report,indent=2))
