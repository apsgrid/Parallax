from pathlib import Path
import json,collections

m=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()

# The corrected Stage-5 snapshot is still in title/ending-overlay layout:
# $8000-$8FFF contains overlay code, while the first $1000 bytes of the
# flight master map are parked under C64 I/O at $D000-$DFFF.
# $CFA3 swaps those 16 pages when gameplay begins. The remaining
# $9000-$A3FF portion of the 96x96 map is already resident.
macro=m[0xD000:0xE000] + m[0x9000:0xA400]
assert len(macro)==96*96

master=[list(macro[y*96:(y+1)*96]) for y in range(96)]
transport_destinations=[
    {"x":i%96,"y":i//96}
    for i,v in enumerate(macro)
    if v==0x77
]

world=[]
counts=collections.Counter()
for my in range(96):
    rows=[[] for _ in range(5)]
    for mx in range(96):
        mid=macro[my*96+mx]
        b=m[0x269C+mid*25:0x269C+mid*25+25]
        for sy in range(5):
            rows[sy].extend(b[sy*5:sy*5+5])
    for r in rows:
        world.append(list(r))
        counts.update(r)

out=Path(r"E:\Projects\Parallax\Godot\data")
out.mkdir(parents=True,exist_ok=True)
payload={
    "width":480,
    "height":480,
    "master_width":96,
    "master_height":96,
    "master_tiles":master,
    "transport_destinations":transport_destinations,
    "tiles":world,
}
(out/"world_480.json").write_text(json.dumps(payload,separators=(",",":")))

print("macro_unique",len(set(macro)))
print("world_unique",len(counts))
print("transport_destinations",transport_destinations)
print("top",counts.most_common(24))
print("landing_blockers",sum(counts[x] for x in range(0x0D,0x11)))
