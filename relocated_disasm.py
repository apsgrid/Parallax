from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

r=Path(r"E:\Projects\Parallax\Extracted\00_PARALLAX.prg").read_bytes()
load=r[0] | (r[1]<<8)
m=MPU()
m.memory[load:load+len(r)-2]=r[2:]
for i in range(256):
    m.memory[0x00F0+i]=m.memory[0xBEA2+i]
d=Disassembler(m)

pc=0x00F0
while pc<0x01F0:
    ln,txt=d.instruction_at(pc)
    print(f"{pc:04X}: {txt}")
    pc+=ln
