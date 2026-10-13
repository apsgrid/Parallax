from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
cpu=MPU(); cpu.memory[:]=m; d=Disassembler(cpu)

def dump(a,b):
 print(f'\n=== {a:04X}-{b:04X} ===')
 pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln

for a,b in [(0x0800,0x0960),(0x0860,0x0900),(0xF1E0,0xF230),(0x1300,0x1420),(0x1900,0x1A80)]: dump(a,b)

for target in (0x030E,0xF229,0x089C,0x089F,0x08A0,0x08A1,0x08A2,0x08A3):
 print(f'\n=== direct refs target {target:04X} ===')
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0xCD,0xCE,0xEE,0x2C) and (m[a+1]|(m[a+2]<<8))==target:
   print(f'{a:04X} op {op:02X}')
  if op in (0x20,0x4C) and (m[a+1]|(m[a+2]<<8))==target:
   print(f'{a:04X} {"JSR" if op==0x20 else "JMP"}')