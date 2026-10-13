from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
for target in (0x0225,0x0226,0x022A,0x022D):
 print(f'\nTARGET {target:04X}')
 for a in range(0x0800,0xFFFD):
  op=m[a]
  # abs indexed read/write/inc/dec families with 16-bit operand
  if op in (0xBD,0xB9,0x9D,0x99,0xDD,0xD9,0xFD,0xF9,0x3D,0x39,0x1D,0x19,0x5D,0x59,0x7D,0x79,0xDE,0xFE) and (m[a+1]|m[a+2]<<8)==target:
   ln,t=d.instruction_at(a); print(f'{a:04X}: {t}')
print('\n=== FC20-FC70 ===')
pc=0xFC20
while pc<0xFC70:
 ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln