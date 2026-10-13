from pathlib import Path

ROOT=Path(r"E:\Projects\Parallax")
m=(ROOT/"Unpacked"/"playable_ram.bin").read_bytes()

def require(addr, expected, label):
    got=m[addr:addr+len(expected)]
    if got!=expected:
        raise SystemExit(f"{label} mismatch @{addr:04X}: expected {expected.hex(' ')}, got {got.hex(' ')}")
    print(f"PASS {label} @ {addr:04X}")

# Ground-session encounter gates.
require(0xE0B2, bytes.fromhex("A9 01 8D 98 E9 8D 60 F0"), "ground init enables entity spawn and one KARD offer")
require(0xE482, bytes.fromhex("20 81 E9 AD E5 E9 C9 06 D0 05 A9 00 8D 60 F0"), "room entry spawns entity and disables reoffer for type 6")

# Current progression-region gate: floor(($0708+1)/18) == $030E.
require(0xE833, bytes.fromhex("AD 08 07 18 69 01 A2 FF E8 38 E9 12 B0 FA A9 00 EC 0E 03 D0 01 60 A9 01 60"), "current progression-region check")

# Entity spawn uses E977 random stream, 128..191 X, 70..133 Y and region table.
require(0xE99E, bytes.fromhex("20 77 E9 29 3F 69 80 8D E2 E9"), "entity random X 128..191")
require(0xE9A9, bytes.fromhex("20 77 E9 29 3F 69 46 8D E3 E9"), "entity random Y 70..133")
require(0xE9BE, bytes.fromhex("AD 08 07 0A 18 6D 07 07 AA BD 00 10 29 07 AA BD E7 E9"), "entity type selector from macro region table")
assert list(m[0xE9E7:0xE9EF]) == [1,3,4,4,4,4,4,1]
print("PASS effective eight-entry entity type table")

# Entity movement: type 5 skips movement; type 4 uses one-pixel cardinal tables.
require(0xEA1B, bytes.fromhex("AD E5 E9 C9 05 F0 4A"), "type 5 stunned entity skips movement")
assert list(m[0xE9EE:0xE9F2]) == [1,255,0,0]
assert list(m[0xE9F6:0xE9FA]) == [0,0,1,255]
print("PASS one-pixel entity cardinal movement tables")

# Scientist rendering semantics.
require(0xEAE4, bytes.fromhex("B9 4E E0 18 69 55 AE E5 E9 E0 04 F0 02 A9 55"), "type 4 scientist animation / type 5 fixed sprite")
require(0xEAF3, bytes.fromhex("E0 06 D0 20 AD 02 D0 18 69 10 8D 06 D0 8D E2 E9"), "type 6 follows sixteen pixels right of player")

# Stun projectile fire conditions and ammo consumption.
require(0xEE08, bytes.fromhex("AD 31 CF F0 0C AD 32 CF F0 07 AD 00 DC 29 10 F0 01 60"), "stun fire requires carried stun-gun, ammo and FIRE")
require(0xEE1A, bytes.fromhex("20 33 E8 D0 FA CE 32 CF"), "stun fire progression gate and one-ammo consumption")
require(0xEE22, bytes.fromhex("AD 42 E4 8D F9 ED AD 43 E4 8D FA ED AD 48 E0 8D FB ED CE FB ED"), "stun projectile starts at player with facing-1 direction")

assert list(m[0xEEDD:0xEEE1]) == [4,252,0,0]
assert list(m[0xEEE1:0xEEE5]) == [0,0,4,252]
assert list(m[0xEED9:0xEEDD]) == [0x46,0x47,0x45,0x44]
print("PASS four-pixel projectile vectors and direction sprite pointers")

# Projectile/entity collision accepts signed deltas -6..+5 on both axes.
require(0xEE9A, bytes.fromhex("AD F9 ED 38 ED E2 E9 C9 06 10 2D C9 FA 30 29"), "projectile/entity X hit window -6..+5")
require(0xEEA9, bytes.fromhex("AD FA ED 38 ED E3 E9 C9 06 10 1E C9 FA 30 1A"), "projectile/entity Y hit window -6..+5")
require(0xEEB8, bytes.fromhex("A9 80 8D FB ED A9 00 8D 98 E9"), "entity hit starts impact and disables respawn")
require(0xEEC2, bytes.fromhex("AD E5 E9 C9 04 F0 04 C9 06 D0 06 A9 05 8D E5 E9"), "type 4/6 stun hit becomes type 5")
require(0xEED3, bytes.fromhex("A9 00 8D E2 E9 60"), "other hit entity is removed")

# Impact lasts eight two-frame animation states ($80->$87), then clears.
require(0xEEE9, bytes.fromhex("EE FC ED AD FC ED C9 02 D0 13 A2 00 8E FC ED EE FB ED AD FB ED C9 88 D0 04 8E F9 ED 60"), "projectile impact two-frame cadence and terminal $88 clear")

# Stunned scientist approach / KARD offer / capture.
require(0xF026, bytes.fromhex("AD E2 E9 D0 01 60 AD E5 E9 C9 05 F0 01 60"), "KARD interaction requires visible type 5")
require(0xF034, bytes.fromhex("AD 42 E4 38 ED E2 E9 C9 09 10 20 C9 F7 30 1C"), "KARD offer X approach window -9..+8")
require(0xF043, bytes.fromhex("AD 43 E4 38 ED E3 E9 C9 06 10 11 C9 FA 30 0D"), "KARD offer Y approach window -6..+5")
require(0xF052, bytes.fromhex("20 61 F0 AD 06 CF D0 05 A9 06 8D E5 E9"), "KARD offer then type-6 promotion when no scientist aboard")
require(0xF061, bytes.fromhex("AD 60 F0 29 0F D0 01 60"), "one KARD offer per ground outing")
require(0xF096, bytes.fromhex("A9 00 8D 60 F0"), "KARD generation consumes outing offer flag")
require(0xF0AA, bytes.fromhex("20 CE 47 C9 59 F0 07 C9 4E D0 EC"), "KARD prompt accepts Y or N")

print("PARALLAX SCIENTIST ENCOUNTER STATIC VERIFICATION: PASS")
