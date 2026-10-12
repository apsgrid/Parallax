from pathlib import Path
m=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()
ops={0x8D:"STA",0x8E:"STX",0x8C:"STY"}
for target in range(0x0703,0x0709):
 print(hex(target))
 for a in range(0x0800,0xFFFD):
  if m[a] in ops and m[a+1]==(target&255) and m[a+2]==(target>>8):
   lo=max(0x0800,a-8); hi=min(0x10000,a+12)
   print(hex(a),ops[m[a]]," ".join(f"{x:02X}" for x in m[lo:hi]))
