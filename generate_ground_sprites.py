from pathlib import Path
from PIL import Image

ram=Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes()
out=Path(r'E:\Projects\Parallax\Godot\generated\ground_sprites')
out.mkdir(parents=True,exist_ok=True)

# Ground animation codes $50-$5B become VIC sprite pointers code+$7D.
# Ground mode has sprite multicolor enabled. Flight init leaves D025=0;
# D026 is the shared secondary color. Use a transparent background plus
# high-contrast faithful C64-style colors; per-sprite color can animate later.
colors=[(0,0,0,0),(0,0,0,255),(255,255,255,255),(154,210,132,255)]

for frame in range(0x50,0x5C):
    ptr=(frame+0x7D)&0xFF
    addr=0x4000+ptr*64
    data=ram[addr:addr+63]
    img=Image.new('RGBA',(24,21),(0,0,0,0))
    px=img.load()
    for y in range(21):
        row=data[y*3:y*3+3]
        for byte_i,b in enumerate(row):
            for pair in range(4):
                v=(b>>(6-pair*2))&3
                c=colors[v]
                x=byte_i*8+pair*2
                px[x,y]=c; px[x+1,y]=c
    img.save(out/f'ground_{frame:02X}.png')

atlas=Image.new('RGBA',(24*4,21*3),(0,0,0,0))
for idx,frame in enumerate(range(0x50,0x5C)):
    im=Image.open(out/f'ground_{frame:02X}.png')
    atlas.paste(im,((idx%4)*24,(idx//4)*21),im)
atlas.resize((24*4*4,21*3*4),Image.Resampling.NEAREST).save(out/'ground_preview.png')
print('generated frames',hex(0x50),'-',hex(0x5B))
