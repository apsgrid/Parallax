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
 (0x08F0,0x0A20),(0xC440,0xC4B0),(0xE780,0xE860),
 (0xEC20,0xECE0),(0xF790,0xF810),(0xEB20,0xEBC0)
]:
    dump(a,b)

print('\n=== F3 XREFS WITH NEARBY OPCODES ===')
zp={0xA5:'LDA',0x85:'STA',0x05:'ORA',0x25:'AND',0x45:'EOR',0xC5:'CMP',0xE6:'INC',0xC6:'DEC'}
for a in range(0x0800,0xFFFF):
    if mem[a] in zp and mem[a+1]==0xF3:
        print('{:04X}: {}'.format(a,zp[mem[a]]))
