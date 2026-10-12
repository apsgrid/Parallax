from pathlib import Path
m=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()
ops={0x8D:"STA",0x8E:"STX",0x8C:"STY",0x9D:"STA,X",0x99:"STA,Y"}
for lo,hi in [(0xD800,0xDBFF)]:
 print(f"WRITES {lo:04X}-{hi:04X}")
 for a in range(0x0800,0xFFFD):
  op=m[a]
  if op in ops:
   addr=m[a+1]|(m[a+2]<<8)
   if lo<=addr<=hi:
    print(f"{a:04X} {ops[op]:5} {addr:04X}")
print("D022/D023/D021 refs")
for t in (0xD021,0xD022,0xD023):
 for a in range(0x0800,0xFFFD):
  if m[a+1]==(t&255) and m[a+2]==(t>>8) and m[a] in ops:
   print(f"{t:04X} <- {a:04X} {ops[m[a]]}")
