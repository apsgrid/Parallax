from pathlib import Path
import json

ROOT=Path(r"E:\Projects\Parallax")
m=(ROOT/"Unpacked"/"playable_ram.bin").read_bytes()

def require(addr, expected, label):
    got=m[addr:addr+len(expected)]
    if got!=expected:
        raise SystemExit(f"{label} mismatch @{addr:04X}: expected {expected.hex(' ')}, got {got.hex(' ')}")
    print(f"PASS {label} @ {addr:04X}")

require(0xCFA3, bytes.fromhex("A2 10 A9 80 D0 02 A9 50 85 FD"), "overlay/world swap selects $8000 source window")
require(0xCFB7, bytes.fromhex("A9 D0 85 8C A0 00 B1 8B 48 B1 FC 91 8B 68 91 FC"), "overlay/world swap pairs $8000 with RAM under $D000 I/O")

runtime_master=m[0xD000:0xE000] + m[0x9000:0xA400]
assert len(runtime_master)==96*96
assert len(set(runtime_master))==204
print("PASS corrected runtime master map is 96x96 with 204 distinct metatile IDs")

markers=[(i%96,i//96) for i,v in enumerate(runtime_master) if v==0x77]
assert len(markers)==18
assert (90,59) in markers
print("PASS corrected runtime master map contains 18 $77 transporter destinations")

world=[]
codes=set()
for my in range(96):
    rows=[[] for _ in range(5)]
    for mx in range(96):
        mid=runtime_master[my*96+mx]
        block=m[0x269C+mid*25:0x269C+mid*25+25]
        for sy in range(5):
            rows[sy].extend(block[sy*5:sy*5+5])
    for row in rows:
        world.append(list(row))
        codes.update(row)

assert len(world)==480 and all(len(row)==480 for row in world)
assert len(codes)==202
glyphs={m[0x4000+c*8:0x4000+c*8+8] for c in codes}
assert len(glyphs)==146
print("PASS corrected expansion is 480x480 with 202 tile codes / 146 glyph bitmaps")

generated=ROOT/"Godot"/"data"/"world_480.json"
if generated.exists():
    payload=json.loads(generated.read_text())
    flat_master=bytes(v for row in payload["master_tiles"] for v in row)
    assert flat_master==runtime_master
    assert payload["tiles"]==world
    generated_markers=[(int(x["x"]),int(x["y"])) for x in payload["transport_destinations"]]
    assert generated_markers==markers
    print("PASS generated Godot world JSON matches corrected runtime master/expanded world")

qualifying=[p for p in markers if p[0]-4>=0x50 and p[1]-2<0x50]
assert qualifying==[(90,59)]
print("PASS unique final transporter marker is (90,59) -> viewport macro (86,57)")
print("PARALLAX WORLD OVERLAY-SWAP VERIFICATION: PASS")
