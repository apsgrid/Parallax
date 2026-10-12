from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)

def dump(start,end):
    print("\n=== {:04X}-{:04X} ===".format(start,end))
    pc=start
    while pc<end:
        ln,txt=d.instruction_at(pc)
        bs=" ".join("{:02X}".format(mem[pc+i]) for i in range(ln))
        print("{:04X}: {:<9} {}".format(pc,bs,txt))
        pc+=ln

print("=== IMMEDIATE 26 LOADS ===")
for a in range(0x0800,0xFFFE):
    if mem[a] in (0xA2,0xA0,0xA9) and mem[a+1]==0x26:
        print("{:04X}: {:02X} 26".format(a,mem[a]))

for start,end in [(0x2050,0x219C),(0xE5E0,0xE7A0),(0xF350,0xF440)]:
    dump(start,end)

print("\n=== EXACT BYTES AT 1FA8 ===")
dump(0x1FA8,0x1FC7)
