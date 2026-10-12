from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)

targets=[0x0C1B,0x0BEB]
for target in targets:
 print(f"\nXREF {target:04X}")
 lo=target&255;hi=target>>8
 for a in range(0x0800,0xFFFD):
  if m[a]==0x20 and m[a+1]==lo and m[a+2]==hi:
   print(f"caller {a:04X}")
   pc=max(0x0800,a-36)
   end=min(0x10000,a+12)
   while pc<end:
    ln,txt=d.instruction_at(pc)
    bs=" ".join(f"{m[pc+i]:02X}" for i in range(ln))
    marker=" >>>" if pc==a else ""
    print(f"{pc:04X}: {bs:<9} {txt}{marker}")
    pc+=ln
