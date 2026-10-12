from pathlib import Path
from PIL import Image
import json

root=Path(r"E:\Projects\Parallax")
ram=(root/"Unpacked/playable_ram.bin").read_bytes()
world=json.loads((root/"Godot/data/world_480.json").read_text())["tiles"]

palette=[
 (0,0,0),(255,255,255),(104,55,43),(112,164,178),
 (111,61,134),(88,141,67),(53,40,121),(184,199,111),
 (111,79,37),(67,57,0),(154,103,89),(68,68,68),
 (108,108,108),(154,210,132),(108,94,181),(149,149,149),
]
# Verified flight startup: D021=0, D022=11, D023=14, color RAM=09 -> individual white.
colors=[palette[0],palette[11],palette[14],palette[1]]

origin_x,origin_y=10,30
cols,rows=40,18
img=Image.new("RGB",(cols*8,rows*8),palette[0])
px=img.load()
for sy in range(rows):
  for sx in range(cols):
    code=world[origin_y+sy][origin_x+sx]
    glyph=ram[0x4000+code*8:0x4000+code*8+8]
    ox=sx*8; oy=sy*8
    for y,b in enumerate(glyph):
      for pair in range(4):
        val=(b>>(6-pair*2))&3
        c=colors[val]
        x=ox+pair*2
        px[x,oy+y]=c; px[x+1,oy+y]=c

# Mark craft collision center only in a second debug copy.
img.save(root/"World/reconstructed_start_view.png")
img.resize((960,432),Image.Resampling.NEAREST).save(root/"World/reconstructed_start_view_3x.png")
print("saved")
