from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
cpu=MPU();cpu.memory[:]=m;d=Disassembler(cpu)

def dump(a,b):
 print('\n=== {:04X}-{:04X} ==='.format(a,b))
 pc=a
 while pc<b:
  ln,txt=d.instruction_at(pc)
  bs=' '.join('{:02X}'.format(m[pc+i]) for i in range(ln))
  print('{:04X}: {:<9} {}'.format(pc,bs,txt))
  pc+=ln

for a,b in [(0xEBE9,0xEC80),(0xED2C,0xEDF9),(0xEF3C,0xF026),(0xF12B,0xF248),(0xF248,0xF3C0)]:
 dump(a,b)

print('\n=== PRINTABLE RUNS 4B00-5000 / EF00-F400 ===')
for a,b in [(0x4B00,0x5000),(0xEF00,0xF400)]:
 i=a
 while i<b:
  j=i
  chars=[]
  while j<b:
   v=m[j]&0x7f
   if 0x20<=v<=0x5f:
    chars.append(chr(v)); j+=1
   else: break
  if len(chars)>=5:
   print('{:04X}: {}'.format(i,''.join(chars)))
   i=j
  else:
   i+=1
