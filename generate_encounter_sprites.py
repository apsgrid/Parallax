from pathlib import Path
from PIL import Image

ram=Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes()
out=Path(r'E:\Projects\Parallax\Godot\generated\encounter_sprites')
out.mkdir(parents=True,exist_ok=True)

# Recovered sprite pointers used by local entities and the stun projectile:
# simple moving entities $40-$43, stun projectile $44-$47,
# stunned scientist $55, impact animation $9D-$A4,
# roaming/following scientist frames $A5-$B0.
pointers=list(range(0x40,0x48))+[0x55]+list(range(0x9D,0xB1))
colors=[(0,0,0,0),(0,0,0,255),(255,255,255,255),(154,210,132,255)]

for ptr in pointers:
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
                px[x,y]=c
                px[x+1,y]=c
    img.save(out/f'ptr_{ptr:02X}.png')

cols=8
rows=(len(pointers)+cols-1)//cols
atlas=Image.new('RGBA',(24*cols,21*rows),(0,0,0,0))
for idx,ptr in enumerate(pointers):
    im=Image.open(out/f'ptr_{ptr:02X}.png')
    atlas.paste(im,((idx%cols)*24,(idx//cols)*21),im)
atlas.resize((24*cols*3,21*rows*3),Image.Resampling.NEAREST).save(out/'encounter_preview.png')
print('generated',len(pointers),'encounter sprite pointers')
