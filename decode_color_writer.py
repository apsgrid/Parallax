from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
for start,count in [(0x8F70,180),(0xE810,180),(0x8420,120),(0x095F,110),(0x0A70,100)]:
 print(f"\n===== {start:04X} =====")
 pc=start
 for i in range(count):
  ln,txt=d.instruction_at(pc)
  bs=" ".join(f"{m[pc+j]:02X}" for j in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  op=m[pc];pc=(pc+ln)&0xffff
  if op in (0x60,0x40) and i>10: break
