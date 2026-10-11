from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

r=Path(r"E:\Projects\Parallax\Extracted\00_PARALLAX.prg").read_bytes()
load=r[0] | (r[1]<<8)
m=MPU()
m.memory[load:load+len(r)-2]=r[2:]
d=Disassembler(m)

def dump(start,end,limit=300):
    pc=start
    n=0
    while pc<end and n<limit:
        ln,txt=d.instruction_at(pc)
        print(f"{pc:04X}: {txt}")
        pc+=ln
        n+=1

print("BOOT")
dump(0x080B,0x0822,40)
print("DEPACKER")
dump(0xBEA2,0xBFA2,200)
