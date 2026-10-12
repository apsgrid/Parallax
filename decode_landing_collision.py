from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes())
m=MPU();m.memory[:]=mem;d=Disassembler(m)
def dump(start,count):
 print(f"\n===== {start:04X} =====");pc=start
 for _ in range(count):
  ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc=(pc+ln)&0xffff

for s,c in [(0x0BEB,80),(0x0C1B,180),(0x1211,130),(0x1714,100),(0x3FE8,80)]:
 dump(s,c)

print("\nCF13 accesses")
ops={0xAD:'LDA',0x8D:'STA',0xAE:'LDX',0x8E:'STX',0xAC:'LDY',0x8C:'STY',0xEE:'INC',0xCE:'DEC',0xCD:'CMP'}
for a in range(0x0800,0xFFFD):
 op=mem[a]
 if op in ops and (mem[a+1]|(mem[a+2]<<8))==0xCF13:
  print(f"{a:04X} {ops[op]} CF13")

print("\n10BA accesses")
for a in range(0x0800,0xFFFD):
 op=mem[a]
 if op in ops and (mem[a+1]|(mem[a+2]<<8))==0x10BA:
  print(f"{a:04X} {ops[op]} 10BA")
