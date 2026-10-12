from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
for start,end in [(0xE4B8,0xE507),(0xE960,0xEA30),(0xEBE0,0xEC30),(0xF000,0xF080)]:
 print('\n=== {:04X}-{:04X} ==='.format(start,end))
 pc=start
 while pc<end:
  ln,txt=d.instruction_at(pc)
  bs=' '.join('{:02X}'.format(m[pc+i]) for i in range(ln))
  print('{:04X}: {:<9} {}'.format(pc,bs,txt))
  pc+=ln
