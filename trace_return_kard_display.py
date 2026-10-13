from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()); c=MPU(); c.memory[:]=m; d=Disassembler(c)
for a,b in [(0x1FC0,0x2055),(0x20C0,0x2101),(0x1F70,0x1FC0)]:
 print('\n=== %04X-%04X ==='%(a,b)); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join('%02X'%m[pc+i] for i in range(ln)); print('%04X: %-9s %s'%(pc,bs,t)); pc+=ln