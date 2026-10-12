from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU(); mpu.memory[:]=mem; d=Disassembler(mpu)

def dump(start,end):
    print("\n=== {:04X}-{:04X} ===".format(start,end))
    pc=start
    while pc<end:
        ln,txt=d.instruction_at(pc)
        bs=" ".join("{:02X}".format(mem[pc+i]) for i in range(ln))
        print("{:04X}: {:<9} {}".format(pc,bs,txt))
        pc+=ln

for start,end in [(0x1F80,0x2050),(0x1C00,0x1DB0),(0x20F0,0x2130)]:
    dump(start,end)

print("\n=== INDEXED CF-BLOCK BASE ACCESSES ===")
bases={0xCEFF,0xCF00}
ops={0xBD:"LDA,X",0xB9:"LDA,Y",0x9D:"STA,X",0x99:"STA,Y",0xDD:"CMP,X",0xD9:"CMP,Y",0x3D:"AND,X",0x39:"AND,Y",0x1D:"ORA,X",0x19:"ORA,Y",0x5D:"EOR,X",0x59:"EOR,Y",0x7D:"ADC,X",0x79:"ADC,Y",0xFD:"SBC,X",0xF9:"SBC,Y"}
for a in range(0x0800,0xFFFD):
    op=mem[a]
    if op in ops:
        addr=mem[a+1]|(mem[a+2]<<8)
        if addr in bases or 0xCEC0 <= addr <= 0xCF33:
            print("{:04X}: {:<6} $".format(a,ops[op])+"{:04X}".format(addr))

print("\n=== CALLERS/JUMPS TO 1FA8 AND 1D48 ===")
for target in [0x1FA8,0x1D48]:
    lo=target&255; hi=target>>8
    print("target {:04X}".format(target))
    for a in range(0x0800,0xFFFD):
        if mem[a] in (0x20,0x4C) and mem[a+1]==lo and mem[a+2]==hi:
            print("{:04X} op {:02X}".format(a,mem[a]))
