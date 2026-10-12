from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)

def xrefs(addr):
    lo=addr&255; hi=addr>>8
    out=[]
    for a in range(0x0800,0x10000-2):
        op=mem[a]
        if op in (0x20,0x4C) and mem[a+1]==lo and mem[a+2]==hi:
            out.append((a,op))
    return out

for target in (0x0B4B,0xDC00,0xDC01):
    print(f"\nXREFS {target:04X}")
    if target<0xD000:
        print(", ".join(f"{a:04X}:{'JSR' if op==0x20 else 'JMP'}" for a,op in xrefs(target)))
    else:
        lo=target&255;hi=target>>8
        hits=[]
        for a in range(0x0800,0xFFFD):
            if mem[a+1]==lo and mem[a+2]==hi and mem[a] in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0x2C,0xCD,0xCC,0xEC,0xEE,0xCE,0x0D,0x2D,0x4D,0x6D,0xED):
                hits.append(a)
        print(", ".join(f"{a:04X}" for a in hits))

def dump(start,count=100):
    print(f"\n--- {start:04X} ---");pc=start
    for _ in range(count):
        ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
        print(f"{pc:04X}: {bs:<9} {txt}")
        pc=(pc+ln)&0xffff

dump(0x0B40,120)
for s in (0x1120,0x2040,0x2290,0x3960,0x61E0,0x6B10,0x6D90,0xC0B0,0xC6F0,0xC990,0xCDC0):
    dump(s,50)

print("\nDIRECT STORES/LOADS $0700-$077F")
ops={0xAD:'LDA',0xAE:'LDX',0xAC:'LDY',0x8D:'STA',0x8E:'STX',0x8C:'STY',0xEE:'INC',0xCE:'DEC',0x0D:'ORA',0x2D:'AND',0x4D:'EOR',0x6D:'ADC',0xED:'SBC',0xCD:'CMP'}
for a in range(0x0800,0xFFFD):
    op=mem[a]
    if op in ops:
        addr=mem[a+1]|(mem[a+2]<<8)
        if 0x0700<=addr<=0x077F:
            print(f"{a:04X} {ops[op]:3} {addr:04X}")
