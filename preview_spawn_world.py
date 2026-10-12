import json
from pathlib import Path
w=json.loads(Path(r"E:\Projects\Parallax\Godot\data\world_480.json").read_text())["tiles"]
# Verified player centre after the C64's 20-frame startup pre-scroll.
cx,cy=29,39
for y in range(max(0,cy-20),min(480,cy+21)):
 s=""
 for x in range(max(0,cx-10),min(480,cx+51)):
  v=w[y][x]
  if 0x0D<=v<=0x10: ch="#"
  elif 0x31<=v<0x3D: ch="+"
  elif v in (0x48,0x58): ch="X"
  elif v==0x2A: ch="."
  else: ch=" "
  if x==cx and y==cy: ch="@"
  s+=ch
 print(f"{y:03d} "+s)
