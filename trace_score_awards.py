from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
for a,b in [(0x1430,0x14AD),(0xFBE0,0xFC90)]: dump(a,b)
for target in (0x14A5,0xFC43,0xFC4C):
 print(f'\n=== callers/refs {target:04X} ===')
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0x20,0x4C) and (m[a+1]|m[a+2]<<8)==target:
   print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')