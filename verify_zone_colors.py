from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
for target in [0x164E,0x164F,0x1650,0x1651,0x1652,0x1653]:
 print(f"XREF-ish {target:04X}")
 lo=target&255;hi=target>>8
 for a in range(0x0800,0xfffd):
  if m[a+1]==lo and m[a+2]==hi and m[a] in (0xAD,0xBD,0xB9,0x8D,0x9D,0x99):
   print(f" {a:04X} op {m[a]:02X}")
print("\n15D0-1630")
pc=0x15D0
while pc<0x1630:
 ln,txt=d.instruction_at(pc)
 bs=" ".join(f"{m[pc+i]:02X}" for i in range(ln))
 print(f"{pc:04X}: {bs:<9} {txt}")
 pc+=ln
