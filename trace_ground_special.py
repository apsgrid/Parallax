from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
pc=0xE440
while pc<0xE4C0:
 ln,txt=d.instruction_at(pc)
 bs=' '.join('{:02X}'.format(m[pc+i]) for i in range(ln))
 print('{:04X}: {:<9} {}'.format(pc,bs,txt))
 pc+=ln
print('\nCALLERS/JUMPS TO E444')
for a in range(0x0800,0xFFFD):
 if m[a] in (0x20,0x4C) and m[a+1]==0x44 and m[a+2]==0xE4:
  print('{:04X} {}'.format(a,'JSR' if m[a]==0x20 else 'JMP'))
