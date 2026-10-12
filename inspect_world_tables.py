from pathlib import Path
mem=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()

# Dump tables/pointers implicated by $0C1B and nearby setup.
ranges=[
 (0x03FC,0x06A0),
 (0x0C13,0x0D60),
 (0x1313,0x1360),
 (0x7800,0x8000),
]
for start,end in ranges:
 print(f"\n=== {start:04X}-{end-1:04X} ===")
 for p in range(start,end,16):
  b=mem[p:min(p+16,end)]
  print(f"{p:04X}: "+" ".join(f"{x:02X}" for x in b))
