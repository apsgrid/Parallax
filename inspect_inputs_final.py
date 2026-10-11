from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\final_game_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)
def dump(start,count):
 print(f"\n--- {start:04X} ---");pc=start
 for _ in range(count):
  ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}");pc+=ln
for s,c in [(0x0B20,100),(0x2030,80),(0x2280,90),(0x3950,90)]:
 dump(s,c)
