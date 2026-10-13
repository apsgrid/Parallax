from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
c=MPU(); c.memory[:]=m; d=Disassembler(c)
for target in (0x1A50,0xF700,0xF874,0xFDF6,0xF8CA):
    print(f'\nTARGET {target:04X}')
    for a in range(0x0800,0xFFFD):
        op=m[a]; w=m[a+1]|(m[a+2]<<8)
        if op in (0x20,0x4C) and w==target:
            print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')
# absolute stores of F8 74 low/high or 00 F7 pointer bytes are too broad; inspect IRQ vectors & indirect jumps vicinity.
print('\nVECTORS 0314-0334:', ' '.join(f'{x:02X}' for x in m[0x0314:0x0334]))
