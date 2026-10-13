from pathlib import Path
from PIL import Image

ROOT = Path(r"E:\Projects\Parallax")
ram = (ROOT / "Unpacked" / "playable_ram.bin").read_bytes()
out = ROOT / "Godot" / "generated"
out.mkdir(parents=True, exist_ok=True)

palette = [
    (0,0,0),(255,255,255),(104,55,43),(112,164,178),
    (111,61,134),(88,141,67),(53,40,121),(184,199,111),
    (111,79,37),(67,57,0),(154,103,89),(68,68,68),
    (108,108,108),(154,210,132),(108,94,181),(149,149,149),
]
zone_mc2 = [14,5,6,4,3,0]
char_color = 1

# E803 preserves $4400-$45FF and copies $5A30-$5C2F into those bytes.
# Within the $4000 VIC charset this replaces codes $80-$BF only.
charset = bytearray(ram[0x4000:0x4800])
charset[0x400:0x600] = ram[0x5A30:0x5C30]

for zone, mc2 in enumerate(zone_mc2):
    img = Image.new("RGB", (16*8, 16*8), palette[0])
    px = img.load()
    colors = [palette[0], palette[11], palette[mc2 & 15], palette[char_color]]
    for code in range(256):
        glyph = charset[code*8:code*8+8]
        ox = (code & 15) * 8
        oy = (code >> 4) * 8
        for y, b in enumerate(glyph):
            for pair in range(4):
                value = (b >> (6-pair*2)) & 3
                c = colors[value]
                x = ox + pair*2
                px[x, oy+y] = c
                px[x+1, oy+y] = c
    img.save(out / f"interior_tiles_zone_{zone}.png")

preview = Image.open(out / "interior_tiles_zone_0.png").resize((1024,1024), Image.Resampling.NEAREST)
preview.save(out / "interior_tiles_preview.png")
print("generated interior atlases", len(zone_mc2))
