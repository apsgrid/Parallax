from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
for start,end in [(0x0D40,0x0D90),(0xE0E0,0xE140),(0xE430,0xE450)]:
 print('\n=== {:04X}-{:04X} ==='.format(start,end))
 pc=start
 while pc<end:
  ln,txt=d.instruction_at(pc)
  bs=' '.join('{:02X}'.format(m[pc+i]) for i in range(ln))
  print('{:04X}: {:<9} {}'.format(pc,bs,txt))
  pc+=ln
