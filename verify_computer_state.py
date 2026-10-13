from pathlib import Path

ROOT = Path(r"E:\Projects\Parallax")
m = (ROOT / "Unpacked" / "playable_ram.bin").read_bytes()

def require(addr, expected, label):
    got=m[addr:addr+len(expected)]
    if got!=expected:
        raise SystemExit(f"{label} mismatch @{addr:04X}: {got.hex(' ')}")
    print(f"PASS {label} @ {addr:04X}")

# Startup state table pairs.
pairs={m[a]:m[a+1] for a in range(0x2113,0x2131,2)}
assert pairs[0x03]==99
assert pairs[0x09]==1
assert pairs[0x0B]==2 and pairs[0x0C]==8 and pairs[0x0D]==5
assert pairs[0x2E]==20
print("PASS startup endurance=99, KARD 0-285, credits=20")

assert list(m[0xF10B:0xF11B]) == [1,0,2,0,3,0,4,0,5,0,1,0,2,0,3,0]
print("PASS random KARD class table")
require(0xE977, bytes.fromhex("EE 76 E9 AC 76 E9 B9 00 09 60"), "shared random-byte stream cursor over $0900 table")
require(0xF069, bytes.fromhex("20 77 E9 4A 29 0F A8 B9 0B F1 8D 07 F1"), "generated KARD class selection")
require(0xF07C, bytes.fromhex("A2 03 20 77 E9 29 07 9D 07 F1"), "generated KARD three 0-7 digits")
require(0xF0B8, bytes.fromhex("AD 09 CF C9 02 F0 1A"), "KARD two-slot capacity branch")
require(0xF0D9, bytes.fromhex("CE 09 CF A2 04 AD 0A CF F0 E2 D0 E2"), "full KARD replacement preserves class-0 slot A")

# KARD terminal/password table.
assert m[0xF22A:0xF243] == b"STACKJEWELPARCHSALONGLOBE"
assert list(m[0xF243:0xF248]) == [0,5,10,15,20]
print("PASS five passwords and region offsets")

# Shop exact mutations.
require(0xEF7F, bytes.fromhex("AD 2E CF 38 E9 14 8D 2E CF"), "shop subtract 20 credits")
require(0xEF8E, bytes.fromhex("AD 03 CF 18 69 1E C9 64 30 02 A9 63 8D 03 CF"), "shop +30 endurance cap 99")
require(0xEF9D, bytes.fromhex("AD 30 CF 18 69 14 C9 32 30 02 A9 31 8D 30 CF"), "shop +20 carried oxygen cap 49")
require(0xEFAC, bytes.fromhex("AD 32 CF 18 69 14 C9 32 30 02 A9 31 8D 32 CF"), "shop +20 carried ammo cap 49")
require(0xEFBB, bytes.fromhex("EE 05 CF"), "shop +1 drug")

# Password success.
require(0xF202, bytes.fromhex("A2 80 A0 F5 20 89 E5 A9 01 8D 29 F2 EE 0E 03"), "password success flag + progression increment")
assert m[0xF211:0xF21B] == bytes.fromhex("A2 05 A9 2D 9D 28 CF CA D0 FA")
print("PASS password display reset")

# Scientist bridge from carried state.
require(0xE01F, bytes.fromhex("AD 33 CF F0 05 A9 06 8D E5 E9"), "carried scientist -> local type 6")
require(0xE793, bytes.fromhex("AD 29 F2 D0 0D A9 01 8D 06 CF A9 00 8D 34 CF"), "unsolved scientist returns to ship")

# RETURN -> KARD/PASS display.
require(0x20C4, bytes.fromhex("20 85 20 C9 0D F0 10"), "RETURN key dispatch")
require(0x20DB, bytes.fromhex("A9 01 8D 28 CF 60"), "RETURN sets KARD/PASS event")
require(0x1FD7, bytes.fromhex("AD 28 CF D0 01 60 A9 00 8D 28 CF A9 08 20 A8 1F 20 31 21 60"), "RETURN event invokes status builder")
require(0x213B, bytes.fromhex("AD 09 CF F0 4B"), "status builder checks KARD count")
require(0x218B, bytes.fromhex("A2 05 BD 28 CF 9D A2 1F CA D0 F7"), "status builder copies PASS display")

print("PARALLAX COMPUTER STATIC VERIFICATION: PASS")
