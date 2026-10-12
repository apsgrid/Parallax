from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)
pc=0x1FC0
for _ in range(180):
    ln,txt=d.instruction_at(pc); bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
    print(f"{pc:04X}: {bs:<9} {txt}")
    pc=(pc+ln)&0xffff
