from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)
for start in [0xBFC0,0xC000,0xC008,0xC00B,0xC100,0xC200,0xC300,0xC400,0xC440,0xC500]:
 print(f"\n===== {start:04X} =====")
 pc=start
 for i in range(220):
  ln,txt=d.instruction_at(pc)
  bs=" ".join(f"{mem[pc+j]:02X}" for j in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  op=mem[pc]; pc=(pc+ln)&0xffff
  if op in (0x60,0x40) and i>10: break
