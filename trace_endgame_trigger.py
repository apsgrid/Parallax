from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
for a,b in [(0x0F60,0x1045),(0x1000,0x10C0),(0x1200,0x12F0),(0x22C0,0x2310)]: dump(a,b)
for target in (0x0FD4,0x0F98,0x1021,0x22D6,0xCF01,0xCF03):
 print(f'\n=== refs {target:04X} ===')
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0x20,0x4C) and (m[a+1]|m[a+2]<<8)==target:
   print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')
  if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and (m[a+1]|m[a+2]<<8)==target:
   print(f'{a:04X}: op{op:02X}')