from pathlib import Path
import json,collections
m=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()
macro=m[0x8000:0xA400]
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
(out/"world_480.json").write_text(json.dumps({"width":480,"height":480,"tiles":world},separators=(",",":")))
print("macro_unique",len(set(macro)))
print("world_unique",len(counts))
print("top",counts.most_common(24))
print("landing_blockers",sum(counts[x] for x in range(0x0D,0x11)))
