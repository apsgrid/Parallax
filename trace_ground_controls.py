from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin").read_bytes())
m=MPU(); m.memory[:]=mem; d=Disassembler(m)

abs_ops={0xAD:'LDA',0xAE:'LDX',0xAC:'LDY',0x8D:'STA',0x8E:'STX',0x8C:'STY',0xBD:'LDA,X',0xB9:'LDA,Y',0x9D:'STA,X',0x99:'STA,Y',0xCD:'CMP',0xED:'SBC',0x6D:'ADC',0x2D:'AND',0x0D:'ORA'}

def dump(start,end):
    print('\n=== {:04X}-{:04X} ==='.format(start,end))
    pc=start
    while pc<end:
        ln,txt=d.instruction_at(pc)
        bs=' '.join('{:02X}'.format(mem[pc+i]) for i in range(ln))
        print('{:04X}: {:<9} {}'.format(pc,bs,txt))
        pc+=ln

for target in [0x0748,0x0749,0x074A,0x074B,0x074C,0x074D,0x0764,0x0770]:
    print('\n=== XREF {:04X} ==='.format(target))
    for a in range(0x0800,0xFFFD):
        op=mem[a]
        if op in abs_ops and (mem[a+1]|(mem[a+2]<<8))==target:
            print('{:04X}: {}'.format(a,abs_ops[op]))

for a,b in [(0xE120,0xE360),(0xED80,0xEE80),(0xE480,0xE5A0)]:
    dump(a,b)

print('\n=== GROUND REGION CIA1 PORT A REFS ===')
for a in range(0xE000,0xF000-2):
    if mem[a] in (0xAD,0x8D,0x2D,0x0D,0xCD) and (mem[a+1]|(mem[a+2]<<8))==0xDC00:
        print('{:04X}: {:02X}'.format(a,mem[a]))
