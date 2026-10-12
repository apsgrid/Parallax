from pathlib import Path
m=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()
for target in [0xE84C,0xE833,0x8FB5]:
 lo=target&255;hi=target>>8
 print(f"XREF {target:04X}")
 for a in range(0x0800,0xFFFD):
  if m[a]==0x20 and m[a+1]==lo and m[a+2]==hi:
   print(f"{a:04X}")
