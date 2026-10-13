from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
for a,b in [(0x2200,0x22D0),(0xE860,0xE8D0),(0x3F80,0x4060),(0x3FE0,0x4010),(0x0960,0x0AB0)]: dump(a,b)
for target in (0x0877,0x0874,0x3F9C,0x2268,0xE8A0,0x3FEC):
 print(f'\n=== callers/refs {target:04X} ===')
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0x20,0x4C) and (m[a+1]|m[a+2]<<8)==target:
   print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')