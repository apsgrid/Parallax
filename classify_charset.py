from pathlib import Path
import collections, json
m=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()
world=json.loads(Path(r"E:\Projects\Parallax\Godot\data\world_480.json").read_text())["tiles"]
used=sorted({v for row in world for v in row})
groups=collections.defaultdict(list)
for code in used:
    sig=bytes(m[0x4000+code*8:0x4000+code*8+8])
    groups[sig].append(code)
print("used_codes",len(used))
print("unique_glyphs_among_used",len(groups))
for sig,codes in sorted(groups.items(),key=lambda kv:(-len(kv[1]),kv[1][0]))[:35]:
    print("codes"," ".join(f"{c:02X}" for c in codes),"bytes",sig.hex(" "))
