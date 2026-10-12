from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
mpu=MPU(); mpu.memory[:]=mem; d=Disassembler(mpu)

ops={0xAD:"LDA",0xAE:"LDX",0xAC:"LDY",0x8D:"STA",0x8E:"STX",0x8C:"STY",
     0xBD:"LDA,X",0xB9:"LDA,Y",0x9D:"STA,X",0x99:"STA,Y",
     0x2D:"AND",0x0D:"ORA",0x4D:"EOR",0xCD:"CMP",0xED:"SBC",0x6D:"ADC"}

def ins_at(pc):
    ln,txt=d.instruction_at(pc)
    bs=" ".join("{:02X}".format(mem[pc+i]) for i in range(ln))
    return ln,bs,txt

for target in [0xCF26,0xCF27]:
    print("\n=== XREFS $"+"{:04X} ===".format(target))
    hits=[]
    for a in range(0x0800,0xFFFD):
        op=mem[a]
        if op in ops and (mem[a+1] | (mem[a+2]<<8)) == target:
            hits.append(a)
    for a in hits:
        print("\n-- {:04X} {} $".format(a,ops[mem[a]])+"{:04X} --".format(target))
        pc=max(0x0800,a-24)
        for _ in range(28):
            ln,bs,txt=ins_at(pc)
            mark=" >>>" if pc==a else ""
            print("{:04X}: {:<9} {}{}".format(pc,bs,txt,mark))
            pc=(pc+ln)&0xffff
            if pc>a+28:
                break

print("\n=== SHIELD STRINGS ===")
for needle in [b"SHIELD",b"SHIELDS"]:
    pos=0
    while True:
        i=bytes(mem).find(needle,pos)
        if i<0:
            break
        print(needle.decode(),"{:04X}".format(i),bytes(mem[i:i+40]))
        pos=i+1
