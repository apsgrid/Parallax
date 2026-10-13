from pathlib import Path
from PIL import Image

ram = Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes()
out = Path(r'E:\\Projects\\Parallax\\Godot\\generated\\flight_object_sprites')
out.mkdir(parents=True, exist_ok=True)

# Recovered VIC-II sprite pointers used by the three-slot flight-object scheduler:
# materialization $B1-$B4; state 1 $C9-$CC; state 2 $B9-$BC;
# states 3/7 $4C-$4F; state 5 $48-$4B; state 6 $50-$54.
pointers = sorted(set(
    list(range(0x48, 0x55))
    + list(range(0xB1, 0xB5))
    + list(range(0xB9, 0xBD))
    + list(range(0xC9, 0xCD))
))

# Preserve the original multicolour shape as a neutral luminance mask.
# Godot applies the recovered per-object VIC colour at runtime.
mask_colors = [
    (0, 0, 0, 0),
    (92, 92, 92, 255),
    (255, 255, 255, 255),
    (166, 166, 166, 255),
]

for ptr in pointers:
    addr = 0x4000 + ptr * 64
    data = ram[addr:addr + 63]
    if len(data) != 63:
        raise RuntimeError(f'sprite ${ptr:02X} is outside recovered RAM image')

    img = Image.new('RGBA', (24, 21), (0, 0, 0, 0))
    px = img.load()
    for y in range(21):
        row = data[y * 3:y * 3 + 3]
        for byte_i, b in enumerate(row):
            for pair in range(4):
                value = (b >> (6 - pair * 2)) & 0x03
                colour = mask_colors[value]
                x = byte_i * 8 + pair * 2
                px[x, y] = colour
                px[x + 1, y] = colour
    img.save(out / f'ptr_{ptr:02X}.png')

cols = 8
rows = (len(pointers) + cols - 1) // cols
atlas = Image.new('RGBA', (24 * cols, 21 * rows), (0, 0, 0, 0))
for idx, ptr in enumerate(pointers):
    im = Image.open(out / f'ptr_{ptr:02X}.png')
    atlas.paste(im, ((idx % cols) * 24, (idx // cols) * 21), im)
atlas.resize((24 * cols * 3, 21 * rows * 3), Image.Resampling.NEAREST).save(out / 'flight_object_preview.png')

print('generated', len(pointers), 'flight-object sprite pointers')
print('pointers', ' '.join(f'{ptr:02X}' for ptr in pointers))
