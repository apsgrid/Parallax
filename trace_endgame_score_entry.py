from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
for a,b in [(0x8889,0x8A80),(0x8A80,0x8B40),(0x8E80,0x8F40)]: dump(a,b)
print('\nSCORE TEMPLATE',bytes(m[0x835B:0x8379]))
print('ENDING TEXT RAW',bytes(m[0x8889:0x8930]))