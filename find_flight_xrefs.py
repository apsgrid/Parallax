from pathlib import Path
mem=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()
for target in (0xC9A3,0xC9D9,0x0E65,0x0F0D,0x165A,0x10BB,0x0F78,0x107B,0x10DA,0x135F,0x19D5,0x0B42):
 lo=target&255;hi=target>>8; hits=[]
 for a in range(0x0800,0xFFFD):
  if mem[a+1]==lo and mem[a+2]==hi and mem[a] in (0x20,0x4c):
   hits.append((a,mem[a]))
 print(f"{target:04X}: "+", ".join(f"{a:04X} {'JSR' if op==0x20 else 'JMP'}" for a,op in hits))
