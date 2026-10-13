from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
for a,b in [(0x8160,0x82E8),(0x86F0,0x87A0),(0x87E0,0x8920),(0x8F40,0x9000)]: dump(a,b)

print('\n=== printable ASCII runs 8000-9000 len>=4 ===')
start=None
for i in range(0x8000,0x9001):
 b=m[i] if i<len(m) else 0
 if 0x20 <= b <= 0x7e:
  if start is None: start=i
 else:
  if start is not None and i-start>=4:
   print(f'{start:04X}:',bytes(m[start:i]).decode('ascii','replace'))
  start=None

for target in (0x816F,0x8810,0x8FB7,0x8727,0x8702,0x8F63):
 print(f'\n=== refs {target:04X} ===')
 for a in range(0x8000,0x9000):
  op=m[a]
  if op in (0x20,0x4C) and (m[a+1]|m[a+2]<<8)==target:
   print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')