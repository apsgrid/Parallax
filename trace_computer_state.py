from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
cpu=MPU(); cpu.memory[:]=m; d=Disassembler(cpu)

def dump(a,b):
 print('\n=== %04X-%04X ==='%(a,b)); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join('%02X'%m[pc+i] for i in range(ln)); print('%04X: %-9s %s'%(pc,bs,t)); pc+=ln

for a,b in [(0xEC80,0xED2C),(0xEF00,0xEF3C),(0xE960,0xE9A0),(0xF3AC,0xF460),(0xF560,0xF620),(0x6D20,0x6E00),(0x4B30,0x4D20)]: dump(a,b)

print('\n=== CF00 init/xrefs ===')
for target in range(0xCF00,0xCF36):
 xs=[]
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and (m[a+1]|m[a+2]<<8)==target:
   xs.append(a)
 if xs:
  print('%04X:'%target,' '.join('%04X'%x for x in xs[:30]))

print('\n=== printable runs 4B00-4D40 / 6D00-6E80 / F560-F620 ===')
for lo,hi in [(0x4B00,0x4D40),(0x6D00,0x6E80),(0xF560,0xF620)]:
 i=lo
 while i<hi:
  j=i; s=[]
  while j<hi:
   v=m[j]&0x7f
   if 0x20<=v<=0x5f:
    s.append(chr(v)); j+=1
   else: break
  if len(s)>=4:
   print('%04X: %s'%(i,''.join(s))); i=j
  else: i+=1