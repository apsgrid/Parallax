from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
for a,b in [(0x0940,0x09A0),(0x23F0,0x2460),(0x2200,0x2260)]: dump(a,b)
for target in (0x097E,0x0983,0x242B,0x2433):
 print(f'\nCALLERS {target:04X}')
 for a in range(0x800,0xfffd):
  if m[a] in (0x20,0x4c) and (m[a+1]|m[a+2]<<8)==target: print(f'{a:04X}', 'JSR' if m[a]==0x20 else 'JMP')