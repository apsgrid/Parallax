from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print('\n=== %04X-%04X ==='%(a,b)); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join('%02X'%m[pc+i] for i in range(ln)); print('%04X: %-9s %s'%(pc,bs,t)); pc+=ln
for a,b in [(0xF026,0xF12B),(0x2100,0x21E0),(0xEDE0,0xEF00),(0xE980,0xEA80),(0xEA80,0xEBE9)]: dump(a,b)
print('\n=== writes to CF09-CF11 including indexed absolute ===')
for a in range(0x0800,0xFFFC):
 op=m[a]; addr=m[a+1]|(m[a+2]<<8)
 if op in (0x8D,0x9D,0x99,0xEE,0xCE) and 0xCF09<=addr<=0xCF11:
  print('%04X op%02X -> %04X'%(a,op,addr))