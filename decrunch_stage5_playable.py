from pathlib import Path
import hashlib,json
base=Path(r"E:\Projects\Parallax\Unpacked")
mem=bytearray((base/"final_game_ram.bin").read_bytes())

# Stage 5 relocation: each page copy happens after pre-decrementing the high bytes.
# Source bases D98D..078D -> destination bases FEFF..2CFF (constant delta 0x2572).
for a in range(0x078D,0xDA8D):
    mem[a+0x2572]=mem[a]

source=0x2E0F
dest=0x0800
stats={"input_bytes":0,"output_bytes":0,"generic_runs":0,"triples":0,"zero_runs":0,"zero_pairs":0,"star_runs":0,"star_pairs":0,"space_runs":0,"literals":0}

def rb():
    global source
    b=mem[source]
    source=(source+1)&0xFFFF
    stats["input_bytes"]+=1
    if source==0x0000:
        raise StopIteration
    return b

def wb(v,n=1):
    global dest
    for _ in range(n):
        mem[dest]=v&255
        dest=(dest+1)&0xFFFF
        stats["output_bytes"]+=1

try:
    while True:
        b=rb()
        if b==0xD1:
            n=rb(); v=rb(); stats["generic_runs"]+=1; wb(v,n)
        elif b==0xD7:
            v=rb(); stats["triples"]+=1; wb(v,3)
        elif b==0xCB:
            n=rb(); stats["zero_runs"]+=1; wb(0,n)
        elif b==0x75:
            stats["zero_pairs"]+=1; wb(0,2)
        elif b==0xD3:
            n=rb(); stats["star_runs"]+=1; wb(0x2A,n)
        elif b==0xA1:
            stats["star_pairs"]+=1; wb(0x2A,2)
        elif b==0xAF:
            n=rb(); stats["space_runs"]+=1; wb(0x20,n)
        else:
            stats["literals"]+=1; wb(b)
except StopIteration:
    pass

lo=0x0800; hi=(dest-1)&0xFFFF
(base/"playable_ram.bin").write_bytes(mem)
(base/"playable_image.bin").write_bytes(mem[lo:hi+1])
report={"relocation_delta":0x2572,"compressed_start":0x2E0F,"compressed_end":0xFFFF,"output_start":lo,"output_end":hi,"entry":0x7C00,"stats":stats,"sha256":hashlib.sha256(mem[lo:hi+1]).hexdigest()}
(base/"playable_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report,indent=2))
