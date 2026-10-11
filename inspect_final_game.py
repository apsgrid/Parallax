from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
import re
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\final_game_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)
def dump(start,count):
 print(f"\n--- {start:04X} ---");pc=start
 for _ in range(count):
  ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}");pc+=ln
dump(0x0801,220)
print("\nHARDWARE REFS")
ops=(0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0x2C,0xCD,0xCC,0xEC,0xEE,0xCE,0x0D,0x2D,0x4D,0x6D,0xED)
for t in (0xDC00,0xDC01,0xD011,0xD012,0xD015,0xD019,0xD01A,0xD020,0xD021,0xD400,0xD418):
 lo=t&255;hi=t>>8;hits=[]
 for a in range(0x0801,0xDA89):
  if mem[a+1]==lo and mem[a+2]==hi and mem[a] in ops:hits.append(a)
 print(f"{t:04X}: "+", ".join(f"{x:04X}" for x in hits[:80]))
print("\nREADABLE WORD HITS")
for word in (b"PARALLAX",b"PASSWORD",b"SCIENT",b"LAZER",b"SHIELD",b"COMPUTER",b"CARD",b"HANGAR"):
 pos=0;arr=[]
 while True:
  p=bytes(mem).find(word,pos)
  if p<0:break
  arr.append(p);pos=p+1
 print(word.decode()+": "+", ".join(f"{x:04X}" for x in arr[:30]))
