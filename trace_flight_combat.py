from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
cpu=MPU(); cpu.memory[:]=m; d=Disassembler(cpu)

def dump(a,b):
    print(f'\n=== {a:04X}-{b:04X} ===')
    pc=a
    while pc<b:
        ln,t=d.instruction_at(pc)
        bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln))
        print(f'{pc:04X}: {bs:<12} {t}')
        pc+=ln

for a,b in [
    (0x10A0,0x11C0),
    (0x11C0,0x1320),
    (0x1320,0x14AD),
    (0x14AD,0x1510),
    (0x2250,0x22C0),
    (0xF7F0,0xF890),
    (0xFB80,0xFCD0),
]:
    dump(a,b)

for target in (0x113A,0x116D,0x12F0,0x147F,0x14AD,0x1A57,0x2268,0x2275,0xFBFF,0xFC43):
    print(f'\n=== refs/callers {target:04X} ===')
    for a in range(0x0800,0xFFFD):
        op=m[a]
        w=m[a+1]|(m[a+2]<<8)
        if op in (0x20,0x4C) and w==target:
            print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')
