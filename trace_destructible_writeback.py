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
for a,b in [(0x19A0,0x1B20),(0xC000,0xC180),(0xC180,0xC300)]:
    dump(a,b)
for target in (0x1A57,0x19C9,0x1857,0xC008,0xC00B,0xC176,0xC1FD):
    print(f'\nrefs {target:04X}')
    for a in range(0x0800,0xFFFD):
        op=m[a]; w=m[a+1]|(m[a+2]<<8)
        if op in (0x20,0x4C) and w==target:
            print(f'{a:04X} {"JSR" if op==0x20 else "JMP"}')
