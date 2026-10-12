from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU();mpu.memory[:]=m;d=Disassembler(mpu)
pc=0x0A80
while pc<0x0AC0:
 ln,txt=d.instruction_at(pc)
 bs=" ".join(f"{m[pc+i]:02X}" for i in range(ln))
 print(f"{pc:04X}: {bs:<9} {txt}")
 pc+=ln
