from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
for start,count in [(0x0BE0,170),(0x13D0,90),(0x0D58,70)]:
 print(f"\n=== {start:04X} ===")
 pc=start
 for _ in range(count):
  ln,txt=d.instruction_at(pc)
  bs=" ".join(f"{m[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc=(pc+ln)&0xffff
