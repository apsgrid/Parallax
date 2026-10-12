from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\final_game_ram.bin").read_bytes())
m=MPU(); m.memory[:]=mem; d=Disassembler(m)

starts=[0x097D,0x3FEC,0x1AC1,0x0CE9,0x0969,0x4D62,0x0AB9,0x0D58,0x18AE,0x0B2D,0x3FF7,0x0B4B]

def dump(start, maxins=120):
    print(f"\n===== {start:04X} =====")
    pc=start
    for i in range(maxins):
        ln,txt=d.instruction_at(pc)
        bs=" ".join(f"{mem[pc+j]:02X}" for j in range(ln))
        print(f"{pc:04X}: {bs:<9} {txt}")
        op=mem[pc]
        pc+=ln
        if op in (0x60,0x40) and i>3:
            break

for s in starts:
    dump(s)
