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

dump(0x0B80,0x0D20)
print('\n1345-1361:', ' '.join(f'{b:02X}' for b in m[0x1345:0x1361]))
print('14CE-14F4:', ' '.join(f'{b:02X}' for b in m[0x14CE:0x14F4]))
print('\nrecords:')
for cls in range(1,6):
    a=0x1345+cls*4
    print(cls, f'{a:04X}', list(m[a:a+4]))
print('destructible pattern offsets', list(m[0x14E2:0x14EB]))
print('destructible replacement', list(m[0x14EB:0x14F4]))
