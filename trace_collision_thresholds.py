from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
c=MPU(); c.memory[:]=m; d=Disassembler(c)
for target in (0x012C,0x012D):
    print(f'VALUE {target:04X}={m[target]:02X}')
    print('refs:')
    for a in range(0x0800,0xFFFD):
        op=m[a]; w=m[a+1]|(m[a+2]<<8)
        if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE,0x2C) and w==target:
            ln,t=d.instruction_at(a)
            print(f'{a:04X}: {t}')
