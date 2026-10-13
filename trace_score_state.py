from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
targets=list(range(0x0225,0x022E))
for target in targets:
 print(f'\n=== refs {target:04X} ===')
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and (m[a+1]|m[a+2]<<8)==target:
   print(f'{a:04X} op{op:02X}')

print('\n=== immediate stores/adds around score refs ===')
seen=set()
for target in targets:
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE) and (m[a+1]|m[a+2]<<8)==target:
   start=max(0x0800,a-16); end=min(0x10000,a+24)
   key=(start,end)
   if key in seen: continue
   seen.add(key); pc=start; print(f'\n-- around {a:04X} target {target:04X} --')
   while pc<end:
    ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln