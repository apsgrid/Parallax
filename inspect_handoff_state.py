from pathlib import Path
for fn in ["final_game_ram.bin","playable_ram.bin"]:
 mem=Path(r"E:\Projects\Parallax\Unpacked")/fn
 b=mem.read_bytes()
 print(fn)
 print("ZP 80-A0:", " ".join(f"{x:02X}" for x in b[0x80:0xA0]))
 print("7BF0-7C20:", " ".join(f"{x:02X}" for x in b[0x7BF0:0x7C20]))
 print("C000-C030:", " ".join(f"{x:02X}" for x in b[0xC000:0xC030]))
