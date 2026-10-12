from pathlib import Path
from PIL import Image

ram=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()
out=Path(r"E:\Projects\Parallax\Godot\generated")
out.mkdir(parents=True,exist_ok=True)

# Pepto-style C64 palette, chosen to stay close to common emulator output.
palette=[
 (0,0,0),(255,255,255),(104,55,43),(112,164,178),
 (111,61,134),(88,141,67),(53,40,121),(184,199,111),
 (111,79,37),(67,57,0),(154,103,89),(68,68,68),
 (108,108,108),(154,210,132),(108,94,181),(149,149,149),
]

# $D021 = 0, $D022 = 11. $D023 changes by vertical region.
zone_mc2=[14,5,6,4,3,0]
char_color=1 # color RAM is $09 => multicolor flag + white individual colour.

for zone,mc2 in enumerate(zone_mc2):
    img=Image.new("RGB",(16*8,16*8),palette[0])
    px=img.load()
    for code in range(256):
        glyph=ram[0x4000+code*8:0x4000+code*8+8]
        ox=(code&15)*8
        oy=(code>>4)*8
        colors=[palette[0],palette[11],palette[mc2&15],palette[char_color]]
        for y,b in enumerate(glyph):
            for pair in range(4):
                value=(b >> (6-pair*2)) & 0x03
                c=colors[value]
                x=ox+pair*2
                px[x,oy+y]=c
                px[x+1,oy+y]=c
    img.save(out/f"tiles_zone_{zone}.png")

# Large nearest-neighbour preview for RE/reference.
preview=Image.open(out/"tiles_zone_0.png").resize((1024,1024),Image.Resampling.NEAREST)
preview.save(out/"tiles_zone_0_preview.png")
print("generated",len(zone_mc2),"atlases at",out)
