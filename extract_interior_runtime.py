from pathlib import Path
import json

ROOT = Path(r"E:\Projects\Parallax")
ram = (ROOT / "Unpacked" / "playable_ram.bin").read_bytes()
out = ROOT / "Godot" / "data" / "interior_runtime.json"
out.parent.mkdir(parents=True, exist_ok=True)

# E321 builds a fixed 8x4 metatile room at $7C00 from IDs at $F489.
meta_ids = ram[0xF489:0xF489 + 32]
screen = [[0x20 for _ in range(40)] for __ in range(20)]
for gy in range(4):
    for gx in range(8):
        mid = meta_ids[gy * 8 + gx]
        meta = ram[0x269C + mid * 25:0x269C + mid * 25 + 25]
        if len(meta) != 25:
            raise RuntimeError("interior metatile extraction failed")
        for yy in range(5):
            for xx in range(5):
                screen[gy * 5 + yy][gx * 5 + xx] = meta[yy * 5 + xx]

patterns = {
    "bank": {
        "rows": 4,
        "cols": 4,
        "data": list(ram[0xF523:0xF523 + 16]),
    },
    "shop": {
        "rows": 6,
        "cols": 4,
        "data": list(ram[0xF523 + 0x10:0xF523 + 0x10 + 24]),
    },
    "password": {
        "rows": 6,
        "cols": 6,
        "data": list(ram[0xF523 + 0x28:0xF523 + 0x28 + 36]),
    },
}

# E866 indexes five region-anchor coordinate pairs at $E85C.
special_coords = [
    [ram[0xE85C + i * 2], ram[0xE85D + i * 2]]
    for i in range(5)
]

password_bytes = ram[0xF22A:0xF243]
passwords = [
    password_bytes[i:i + 5].decode("ascii", errors="replace")
    for i in range(0, 25, 5)
]

payload = {
    "schema": "parallax-interior-runtime-v1",
    "base_tiles": screen,
    "seed_base": 0x0900,
    "seed_bytes": list(ram[0x0900:0x2100]),
    # $207A increments a byte cursor and reads $C000,Y before masking to
    # three bits. Preserve that exact 256-byte resident source locally.
    "damage_random_bytes": list(ram[0xC000:0xC100]),
    "patterns": patterns,
    "special_coords": special_coords,
    "passwords": passwords,
    "source": {
        "room_metatile_ids": [int(x) for x in meta_ids],
        "entry": "0xE444",
        "room_builder": "0xE321/0xE395",
        "dynamic_builder": "0xE866/0xE900/0xE94F",
    },
}

out.write_text(json.dumps(payload, separators=(",", ":")), encoding="utf-8")
print(out)
print("passwords", passwords)
print("special_coords", special_coords)
print("bytes", out.stat().st_size)
