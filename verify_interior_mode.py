from pathlib import Path

ROOT = Path(r"E:\Projects\Parallax")
mem = (ROOT / "Unpacked" / "playable_ram.bin").read_bytes()


def require(address: int, expected: bytes, label: str) -> None:
    actual = mem[address:address + len(expected)]
    if actual != expected:
        raise SystemExit(
            "{} mismatch at {:04X}: expected {}, got {}".format(
                label, address, expected.hex(" "), actual.hex(" ")
            )
        )
    print("PASS {} @ {:04X}".format(label, address))


# E444 saves outdoor fine scroll, swaps/builds the local room and assigns
# the recovered local-player spawn.
require(0xE444, bytes.fromhex("AD 03 07 85 04 AD 04 07 85 05"), "E444 fine-scroll save")
require(0xE45F, bytes.fromhex("A9 3E 8D 42 E4 A9 62 8D 43 E4"), "upper local spawn")
require(0xE469, bytes.fromhex("A5 53 C9 C3 30 05 A9 8A 8D 43 E4"), "C3 lower-spawn branch")

# Interior loop exits only when the LEFT collision sample in zp $46 is space.
require(0xE4DA, bytes.fromhex("A5 46 C9 20 D0 B1"), "left-space interior exit")

# Local pixel coordinates -> 40-column screen pointer transform.
require(0xE5E6, bytes.fromhex("8A 38 E9 0C 4A 4A 4A 85 8F"), "interior X-to-cell transform")
require(0xE5EF, bytes.fromhex("98 38 E9 2D 4A 4A 29 FE A8"), "interior Y-to-row transform")

# E803 swaps the local charset; E821 restores it.
require(0xE803, bytes.fromhex("A0 00 B9 00 44 99 00 5D B9 30 5A 99 00 44"), "interior charset swap")
require(0xE821, bytes.fromhex("A0 00 B9 00 5D 99 00 44"), "interior charset restore")

# EBEB direction-indexed terminal families:
# right, left, down, up.
assert mem[0xEC23:0xEC27] == bytes([0xD0, 0xCE, 0xCD, 0xCF])
assert mem[0xEC27:0xEC2B] == bytes([0xD2, 0xD1, 0x00, 0x00])
assert mem[0xEC2B:0xEC2F] == bytes([0xD5, 0xD3, 0xD6, 0xD4])
print("PASS terminal dispatch code families")

# Dynamic room content patterns written by E94F.
assert mem[0xF523:0xF533] == bytes.fromhex(
    "09 CD 0B C0 D0 04 CE DE 49 CF 4B DE DF DE DE DE"
)
print("PASS COMPUTABANK 4x4 pattern")

assert mem[0xF533:0xF54B] == bytes.fromhex(
    "09 04 0B C0 D2 0C D1 DE D2 2C D1 DE "
    "D2 4C D1 DE 49 4A 4B DE DF DE DE DE"
)
print("PASS COMPUTASHOP 4x6 pattern")

assert mem[0xF54B:0xF56F] == bytes.fromhex(
    "09 D6 D6 D6 0B C0 "
    "D5 3D 3D 3D D3 DE "
    "D5 3D 3D 3D D3 DE "
    "D5 3D 3D 3D D3 DE "
    "49 D4 D4 D4 4B DE "
    "DF DE DE DE DE DE"
)
print("PASS KARD/password 6x6 pattern")

passwords = [
    mem[0xF22A + i * 5:0xF22F + i * 5].decode("ascii")
    for i in range(5)
]
assert passwords == ["STACK", "JEWEL", "PARCH", "SALON", "GLOBE"]
print("PASS progression passwords:", ", ".join(passwords))

print("PARALLAX INTERIOR STATIC VERIFICATION: PASS")
