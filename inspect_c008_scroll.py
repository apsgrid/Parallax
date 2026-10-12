from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin").read_bytes())
m=MPU(); m.memory[:]=mem; d=Disassembler(m)
pc=0xBFE0
while pc<0xC0C0:
    ln,txt=d.instruction_at(pc)
    bs=' '.join('{:02X}'.format(mem[pc+i]) for i in range(ln))
    print('{:04X}: {:<9} {}'.format(pc,bs,txt))
    pc+=ln
