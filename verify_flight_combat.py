from pathlib import Path

m = Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()


def require(addr: int, expected: bytes, label: str) -> None:
    actual = m[addr:addr + len(expected)]
    assert actual == expected, f"{label} @ {addr:04X}: {actual.hex()} != {expected.hex()}"
    print(f"PASS {label} @ {addr:04X}")


# Laser gate/spawn and projectile state.
require(0x10FC, bytes.fromhex("AD 02 CF C9 07 10 F7 AD 7B 07 F0 01 60"), "$CF02<7 and no active laser fire gate")
require(0x110E, bytes.fromhex("A9 54 8D 79 07 A9 75 8D 7A 07"), "laser spawn X=$54 Y=$75")
require(0x1118, bytes.fromhex("AD BD 0D 8D 6B 11"), "laser snapshots 16-step heading")
require(0x111E, bytes.fromhex("A9 1E 8D 7B 07"), "laser live state starts at $1E")
require(0x1123, bytes.fromhex("AD 78 07 8D 7C 07"), "laser snapshots firing height into $077C")

# Terrain classifier ordering and classes.
assert list(m[0x0CE0:0x0CE9]) == [0x07,0x09,0x03,0x01,0x08,0x06,0x04,0x02,0x05]
print("PASS recovered 3x3 collision priority table")
require(0x0C9B, bytes.fromhex("C9 31 30 04 C9 3D 30 3B"), "$31-$3C collision class")
require(0x0CA3, bytes.fromhex("A0 02 C9 48 F0 35"), "$48 collision class 2")
require(0x0CA9, bytes.fromhex("A0 05 C9 58 F0 2F"), "$58 collision class 5")
require(0x0CC3, bytes.fromhex("A5 8C C9 14 30 0E"), "height $14 gate for extra terrain classes")
require(0x0CC9, bytes.fromhex("A5 8F A0 03 C9 3D F0 0D A0 04 C9 64 F0 07"), "$3D/$64 high-flight classes")
assert m[0x1349:0x135D] == bytes.fromhex("02 05 0B 00 02 06 01 21 02 06 01 21 02 02 0B 00 02 03 0B 00")
print("PASS five recovered collision response records")

# Dynamic collision interval.
require(0x097C, bytes.fromhex("A9 94 8D 2C 01 A9 93 8D 2D 01"), "startup dynamic thresholds $94/$93")
require(0x2420, bytes.fromhex("AD C9 23 4A 4A 4A 85 8E 18 69 94 8D 2C 01 A9 93 38 E5 8E 8D 2D 01"), "$23C9/8 dynamic threshold expansion")

# Destructible response and score award.
require(0x1339, bytes.fromhex("B9 47 13 48 C9 01 D0 03 20 7F 14"), "response selector 1 enters destructible handler")
assert m[0x14E2:0x14EB] == bytes([0,1,2,40,41,42,80,81,82])
assert m[0x14EB:0x14F4] == bytes.fromhex("3E 04 3E 04 40 04 3E 04 3E")
print("PASS transient 3x3 destructible blast pattern")
require(0x1495, bytes.fromhex("A2 00 BD E2 14 A8 BD EB 14 91 FC E8 E0 09 D0 F2"), "blast pattern loop exits with X=9")
require(0x14A5, bytes.fromhex("A9 0F 8D 2D 02 4C 57 1A"), "destructible hit queues 15 points then jumps to master writeback")
require(0x1AA2, bytes.fromhex("A4 FE B1 FC DD B4 1A F0 04 CA D0 F8 60 BD B9 1A 91 FC"), "$1A57 master writeback uses caller X")
assert m[0x1ABD] == 0xF7 and m[0x1AC2] == 0x00
print("PASS direct laser writeback pair at X=9 is $F7->$00")

# Common score consumer.
require(0x2275, bytes.fromhex("AD 2D 02 18 6D 2A 02 8D 2A 02"), "pending award adds into least-significant ASCII score digit")
require(0x2297, bytes.fromhex("A2 00 A0 00 8C 2D 02"), "pending score award is cleared after carry normalization")

# Moving object hit gate and award.
assert m[0xFC3B:0xFC43] == bytes.fromhex("07 60 14 23 00 14 1C 32")
print("PASS four recovered moving-object height bands")
require(0xFBFF, bytes.fromhex("AD 7B 07 F0 04 C9 80 30 01 60"), "moving-object collision accepts only live non-exploding laser")
require(0xFC09, bytes.fromhex("AD 28 F8 29 03 0A AA AD 78 07 DD 3B FC 30 05 DD 3C FC 30 01 60"), "object category indexes current craft-height band")
require(0xFC1E, bytes.fromhex("AD 79 07 38 ED 25 F8 C9 0A 10 13 C9 F5 30 0F"), "object X hit window is signed -11..+9")
require(0xFC2D, bytes.fromhex("AD 7A 07 38 ED 26 F8 C9 0A 10 04 C9 F5 10 07"), "object Y hit window is signed -11..+9")
require(0xFC43, bytes.fromhex("A9 00 8D 7B 07 AD 28 F8 0A 8D 2D 02"), "object hit clears laser and queues 2*object_state points")

print("PARALLAX FLIGHT COMBAT STATIC VERIFICATION: PASS")
