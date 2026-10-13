from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)

def dump(a,b):
 print('\n=== %04X-%04X ==='%(a,b)); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join('%02X'%m[pc+i] for i in range(ln)); print('%04X: %-9s %s'%(pc,bs,t)); pc+=ln

for a,b in [(0xE430,0xE4C0),(0xE760,0xE7C0),(0xF120,0xF210),(0xE1A0,0xE216)]: dump(a,b)

print('\n=== F060 direct accesses ===')
for a in range(0x0800,0xFFFD):
 op=m[a]
 if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and (m[a+1]|m[a+2]<<8)==0xF060:
  print('%04X op%02X'%(a,op))

print('\n=== E998 direct accesses ===')
for a in range(0x0800,0xFFFD):
 op=m[a]
 if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and (m[a+1]|m[a+2]<<8)==0xE998:
  print('%04X op%02X'%(a,op))

print('\n=== type/sprite tables ===')
for a,b in [(0xE04E,0xE05E),(0xE9E7,0xEA02),(0xEED9,0xEEE9)]:
 print('%04X:'%a,' '.join('%02X'%x for x in m[a:b]))