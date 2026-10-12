from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)
for start in (0x0E30,0x3D0D,0x6BEA,0x9AC7,0xC9A3):
 print(f"\n--- {start:04X} ---")
 pc=start
 for _ in range(22):
  ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc+=ln

print("\nword occurrences of bank starts")
for target in (0x0E3F,0x3D1C,0x6BF9,0x9AD6,0xC9B3,0xC9D9):
 pat=bytes((target&255,target>>8)); hits=[]
 for i in range(0x0800,0xFFFE):
  if mem[i:i+2]==pat:hits.append(i)
 print(f"{target:04X}: "+", ".join(f"{h:04X}" for h in hits[:50]))
