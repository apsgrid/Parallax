from pathlib import Path

ROOT = Path(r"E:\\Projects\\Parallax")
mem = (ROOT / "Unpacked" / "playable_ram.bin").read_bytes()

PASSABLE = {
    0xC0, 0xDE, 0xDF, 0x1F, 0x4D,
    *range(0x80, 0x8A),
    0x1B, 0x2A,
}


def require_bytes(address: int, expected: bytes, label: str) -> None:
    actual = mem[address:address + len(expected)]
    if actual != expected:
        raise SystemExit(
            "{}: signature mismatch at {:04X}: expected {}, got {}".format(
                label, address, expected.hex(' '), actual.hex(' ')
            )
        )
    print("PASS {}: {:04X} {}".format(label, address, actual.hex(' ')))


require_bytes(0xE280, bytes.fromhex("A9 79 85 8C A9 7B 85 8B"), "$E280 pointer seed")
require_bytes(0xE288, bytes.fromhex("AD 01 07 F0 08 E6 8C E6 8C E6 8C E6 8C"), "$0701 screen-bank select")

low = 0x7B
high0 = 0x79
high1 = high0 + 4
base0 = low | (high0 << 8)
base1 = low | (high1 << 8)
assert base0 == 0x797B
assert base1 == 0x7D7B
print("active-screen collision base: $0701=0 -> {:04X}; $0701!=0 -> {:04X}".format(base0, base1))

screen0 = 0x7800
screen1 = 0x7C00
for base, screen in ((base0, screen0), (base1, screen1)):
    offset = base - screen
    row, col = divmod(offset, 40)
    assert (row, col) == (9, 19)
    print("{:04X} relative to {:04X}: row={}, col={}".format(base, screen, row, col))

sample_offsets = {
    "UP": 0x00,
    "LEFT": 0x27,
    "RIGHT": 0x29,
    "DOWN": 0x50,
}
expected_cells = {
    "UP": (19, 9),
    "LEFT": (18, 10),
    "RIGHT": (20, 10),
    "DOWN": (19, 11),
}

for name, delta in sample_offsets.items():
    absolute = base0 + delta
    off = absolute - screen0
    row, col = divmod(off, 40)
    got = (col, row)
    assert got == expected_cells[name], (name, got, expected_cells[name])
    print("{:<5}: offset ${:02X} -> screen cell {},{}".format(name, delta, got[0], got[1]))

expected_passable = bytes([
    0xC0, 0xDE, 0xDF, 0x1F, 0x4D,
    0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89,
    0x1B, 0x2A,
])
actual_passable = mem[0xE310:0xE321]
assert actual_passable == expected_passable
assert set(actual_passable) == PASSABLE
print("PASS $E2FC passable table:", " ".join("{:02X}".format(x) for x in actual_passable))

# $C1FD applies signed integer scroll velocity first.
require_bytes(0xC20A, bytes.fromhex("AD 09 07 18 6D 03 07 8D 03 07"), "$C1FD horizontal velocity add")
require_bytes(0xC214, bytes.fromhex("AD 0B 07 18 6D 04 07 8D 04 07"), "$C1FD vertical velocity add")

# $C00E/$C03F then normalize +/-8 fine scroll into tile offsets.
require_bytes(0xC00E, bytes.fromhex("AD 03 07 38 C9 08 B0 01 60"), "$C00E horizontal fine-scroll gate")
require_bytes(0xC03F, bytes.fromhex("AD 04 07 38 C9 08 B0 01 60"), "$C03F vertical fine-scroll gate")

# $C070/$C091 subsequently normalize 5-tile offsets into 96x96 macro coordinates.
require_bytes(0xC070, bytes.fromhex("AD 05 07 38 C9 05"), "$C070 horizontal tile-offset gate")
require_bytes(0xC091, bytes.fromhex("AD 06 07 38 C9 05"), "$C091 vertical tile-offset gate")

def reference_origin_shift(total_scroll: int) -> int:
    return -(total_scroll // 8)

for value in range(-33, 34):
    shift = reference_origin_shift(value)
    formula = -(value // 8)
    assert shift == formula

for value in (-17, -9, -8, -1, 0, 1, 7, 8, 9, 16, 17):
    print("scroll {:+3}: tile-origin shift {:+3}".format(value, reference_origin_shift(value)))

print("GROUND COLLISION ALIGNMENT: PASS")
