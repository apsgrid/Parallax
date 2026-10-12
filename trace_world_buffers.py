from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)

# Scan for absolute stores into candidate map/work ranges and indexed stores with base there.
ops={0x8D:"STA",0x8E:"STX",0x8C:"STY",0x9D:"STA,X",0x99:"STA,Y"}
for lo,hi in [(0x7800,0x9fff),(0x2600,0x3fff),(0x0300,0x06ff)]:
 print(f"\n=== WRITES {lo:04X}-{hi:04X} ===")
 hits=[]
 for a in range(0x0800,0xfffd):
  op=mem[a]
  if op in ops:
   addr=mem[a+1]|(mem[a+2]<<8)
   if lo<=addr<=hi:
    hits.append((a,ops[op],addr))
 for h in hits[:500]:
  print(f"{h[0]:04X} {h[1]:5} {h[2]:04X}")

# pointer-table xrefs
for target in [0x03fc,0x04fc,0x05fc,0x05fd,0x269c,0x7800]:
 print(f"\nXREF-ish {target:04X}")
 lo=target&255;hi=target>>8
 for a in range(0x0800,0xfffd):
  if mem[a+1]==lo and mem[a+2]==hi and mem[a] in (0xAD,0xAE,0xAC,0x8D,0x8E,0x8C,0xBD,0xB9,0x9D,0x99,0x20,0x4c):
   print(f"{a:04X} op={mem[a]:02X}")

# dump candidate loaders around suspicious writes
for start in [0x08c0,0x2300,0x2400,0x2500,0x2600,0x3100,0x4500,0x4800,0xa000]:
 print(f"\n--- {start:04X} ---")
 pc=start
 for _ in range(80):
  ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc=(pc+ln)&0xffff
