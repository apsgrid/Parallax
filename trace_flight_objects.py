from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
c=MPU(); c.memory[:]=m; d=Disassembler(c)

def dump(a,b):
    print(f'\n=== {a:04X}-{b:04X} ===')
    pc=a
    while pc<b:
        ln,t=d.instruction_at(pc)
        print(f'{pc:04X}: {" ".join(f"{m[pc+i]:02X}" for i in range(ln)):<12} {t}')
        pc+=ln

for a,b in [
    (0xF840,0xF980),
    (0xF980,0xFB90),
    (0xF600,0xF680),
    (0x0DD0,0x0E40),
]:
    dump(a,b)

for target in (0xF874,0xF8E3,0xF703,0xF700,0xFBCE,0xFC97,0xF629,0xF871,0xF828,0xF825,0xF826):
    print(f'\n=== refs {target:04X} ===')
    for a in range(0x0800,0xFFFD):
        op=m[a]; w=m[a+1]|(m[a+2]<<8)
        if op in (0x20,0x4C) and w==target:
            print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')
        if target>=0xF800 and op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and w==target:
            print(f'{a:04X}: op{op:02X}')
