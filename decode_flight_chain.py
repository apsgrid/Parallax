from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)
def dump(start,count):
 print(f"\n===== {start:04X} =====");pc=start
 for _ in range(count):
  ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc=(pc+ln)&0xffff
for s,c in [(0x0AE5,120),(0xC9A3,220),(0x0E65,100),(0x0F0D,180),(0x165A,150),(0x10BB,130),(0x0F78,130),(0x107B,100),(0x10DA,120),(0x135F,180),(0x19D5,160)]:
 dump(s,c)
