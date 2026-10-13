from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
for a,b in [(0xF6E0,0xF850),(0xFD40,0xFEA0),(0xFEA0,0x10000)]: dump(a,b)
for target in (0xF700,0xF703,0xF76D,0xF773,0xFD50,0xFD6E,0xFDF6,0xFE80):
 print(f'\nREFS {target:04X}')
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0x20,0x4C) and (m[a+1]|m[a+2]<<8)==target:
   print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')