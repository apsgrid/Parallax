from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
c=MPU(); c.memory[:]=m; d=Disassembler(c)

def dump(a,b):
 print('\n=== %04X-%04X ==='%(a,b)); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join('%02X'%m[pc+i] for i in range(ln)); print('%04X: %-9s %s'%(pc,bs,t)); pc+=ln

for a,b in [
(0xE970,0xEA80),(0xEA80,0xEBE9),(0xEE80,0xEF3C),(0xF000,0xF061),(0xF061,0xF120),
(0xE270,0xE321),(0xED80,0xEE80),(0x47A0,0x4820),(0xE000,0xE060)
]:
 dump(a,b)

print('\n=== direct E9E5 accesses ===')
for a in range(0x0800,0xFFFD):
 op=m[a]
 if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and (m[a+1]|m[a+2]<<8)==0xE9E5:
  print('%04X op%02X'%(a,op))

print('\n=== direct EECD calls/jumps ===')
for target in (0xEECD,0xF026,0xF061,0xE9E5,0xE9E2,0xE9E3,0xE9E4):
 print('target %04X'%target)
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0x20,0x4C) and (m[a+1]|m[a+2]<<8)==target:
   print('%04X %s'%(a,'JSR' if op==0x20 else 'JMP'))