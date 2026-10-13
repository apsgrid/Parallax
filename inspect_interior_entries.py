import json
from pathlib import Path
root=Path(r'E:\\Projects\\Parallax')
world=json.loads((root/'Godot/data/world_480.json').read_text())['tiles']
ram=(root/'Unpacked/playable_ram.bin').read_bytes()

targets=[0xC1,0xC2,0xC3]
for t in targets:
 pos=[(x,y) for y,row in enumerate(world) for x,v in enumerate(row) if v==t]
 print('\nCODE {:02X} count {}'.format(t,len(pos)))
 print('positions',pos[:200])
 for x,y in pos[:20]:
  print(' context at {},{}'.format(x,y))
  for yy in range(max(0,y-3),min(480,y+4)):
   print('  '+' '.join('{:02X}'.format(world[yy][xx]) for xx in range(max(0,x-4),min(480,x+5))))

for t in targets+[0x20]:
 glyph=ram[0x4000+t*8:0x4000+t*8+8]
 print('\nGLYPH {:02X}: {}'.format(t,' '.join('{:02X}'.format(b) for b in glyph)))
 for b in glyph:
  bits=''.join('##' if ((b>>(6-2*i))&3) else '  ' for i in range(4))
  print(bits)
