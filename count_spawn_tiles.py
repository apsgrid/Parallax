import json,collections
from pathlib import Path
w=json.loads(Path(r"E:\Projects\Parallax\Godot\data\world_480.json").read_text())["tiles"]
c=collections.Counter()
for y in range(26,95):
  for x in range(0,75):
    c[w[y][x]]+=1
print("tiles",sum(c.values()),"unique",len(c))
for code,n in c.most_common(30):
  print(f"{code:02X} {n}")
