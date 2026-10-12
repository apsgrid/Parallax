from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
for start,end in [(0x8F90,0x9030),(0xE830,0xE8A0),(0x14F0,0x1570),(0x1620,0x1660)]:
 print(f"\n===== {start:04X}-{end:04X} =====")
 pc=start
 while pc<end:
  ln,txt=d.instruction_at(pc)
  bs=" ".join(f"{m[pc+j]:02X}" for j in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc+=ln
