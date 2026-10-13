from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
cpu=MPU();cpu.memory[:]=m;d=Disassembler(cpu)
def dump(a,b):
 print('\n=== {:04X}-{:04X} ==='.format(a,b)); pc=a
 while pc<b:
  ln,txt=d.instruction_at(pc); bs=' '.join('{:02X}'.format(m[pc+i]) for i in range(ln)); print('{:04X}: {:<9} {}'.format(pc,bs,txt)); pc+=ln
for a,b in [(0xE5D0,0xE620),(0xF460,0xF4C9),(0xF489,0xF4C9)]: dump(a,b)

print('\nF470 offsets:', ' '.join('{:02X}'.format(x) for x in m[0xF470:0xF489]))
print('F489 metatile ids:', ' '.join('{:02X}'.format(x) for x in m[0xF489:0xF4A9]))

# Rebuild the E321 40x20 screen for initial A=0.
screen=[[None for _ in range(40)] for __ in range(20)]
meta_ids=m[0xF489:0xF489+32]
for group_y in range(4):
 for group_x in range(8):
  mid=meta_ids[group_y*8+group_x]
  meta=m[0x269C+mid*25:0x269C+mid*25+25]
  for yy in range(5):
   for xx in range(5):
    screen[group_y*5+yy][group_x*5+xx]=meta[yy*5+xx]

triggers={0xD0:'B',0xCE:'B',0xCD:'B',0xCF:'B',0xD2:'S',0xD1:'S',0xD5:'K',0xD3:'K',0xD6:'K',0xD4:'K',0x20:'E'}
passable={0xC0,0xDE,0xDF,0x1F,0x4D,*range(0x80,0x8A),0x1B,0x2A}
print('\n=== INTERIOR 40x20 SYMBOL MAP ===')
for y,row in enumerate(screen):
 s=''
 for v in row:
  if v in triggers: ch=triggers[v]
  elif v in passable: ch='.'
  else: ch='#'
  s+=ch
 print('{:02d} {}'.format(y,s))

print('\n=== TRIGGER/EXIT LOCATIONS ===')
for y,row in enumerate(screen):
 for x,v in enumerate(row):
  if v in triggers:
   print('{:02X} {} at {},{}'.format(v,triggers[v],x,y))

# swapped interior charset source 5A30/5B30 -> 4400/4500: decode trigger glyph bytes
for t in sorted(triggers):
 src=0x5A30+t*8 if t<32 else None
# Actual char destination 4400 + t*8, source is 5A30 offset by same 0..511 wrapping across 5A30/5B30.
for t in sorted(triggers):
 src=0x5A30+t*8
 glyph=m[src:src+8]
 print('glyph {:02X} src {:04X}: {}'.format(t,src,' '.join('{:02X}'.format(b) for b in glyph)))
