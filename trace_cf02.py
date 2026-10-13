from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
c=MPU(); c.memory[:]=m; d=Disassembler(c)
target=0xCF02
print('value',m[target])
refs=[]
for a in range(0x0800,0xFFFD):
    op=m[a]; w=m[a+1]|(m[a+2]<<8)
    if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE,0x2C) and w==target:
        ln,t=d.instruction_at(a); refs.append((a,t))
print(refs)
for a,_ in refs:
    start=max(0x0800,a-20); end=min(0x10000,a+28)
    print(f'\n-- {a:04X} --')
    pc=start
    while pc<end:
      ln,t=d.instruction_at(pc); print(f'{pc:04X}: {" ".join(f"{m[pc+i]:02X}" for i in range(ln)):<12} {t}'); pc+=ln
