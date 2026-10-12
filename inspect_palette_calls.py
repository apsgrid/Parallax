from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
for start in [0xE2F0,0xE720,0xE780,0xE960,0xEBC0,0xEDF0,0x8040]:
 print(f"\n===== {start:04X} =====")
 pc=start
 for _ in range(110):
  ln,txt=d.instruction_at(pc)
  bs=" ".join(f"{m[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc+=ln
