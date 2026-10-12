from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin").read_bytes())
m=MPU(); m.memory[:]=mem; d=Disassembler(m)

def dump(start,end):
    print('\n=== {:04X}-{:04X} ==='.format(start,end))
    pc=start
    while pc<end:
        ln,txt=d.instruction_at(pc)
        bs=' '.join('{:02X}'.format(mem[pc+i]) for i in range(ln))
        print('{:04X}: {:<9} {}'.format(pc,bs,txt))
        pc+=ln

for a,b in [
    (0x0E20,0x0E50),(0x10D0,0x1110),(0x19A0,0x19E0),
    (0x1A30,0x1A70),(0x1B20,0x1B60),(0x1E40,0x1E70),
    (0xE000,0xE120),(0xE700,0xE750),(0xEB80,0xEBE0),
    (0xB630,0xB6D0),(0xB8D0,0xB920),(0xFF80,0xFFD0)
]:
    dump(a,b)

print('\n=== CALLERS/JUMPS TO E700-EC00 TARGETS ===')
targets=[0xE000,0xE720,0xE725,0xE729,0xEBB5,0xEBB9]
for target in targets:
    lo=target&255; hi=target>>8
    hits=[]
    for a in range(0x0800,0xFFFD):
        if mem[a] in (0x20,0x4C) and mem[a+1]==lo and mem[a+2]==hi:
            hits.append((a,mem[a]))
    print('{:04X}: {}'.format(target, ', '.join('{:04X}/{}'.format(a,'JSR' if op==0x20 else 'JMP') for a,op in hits)))
