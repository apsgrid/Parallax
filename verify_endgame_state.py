from pathlib import Path

ROOT=Path(r"E:\Projects\Parallax")
m=(ROOT/"Unpacked"/"playable_ram.bin").read_bytes()

def require(addr, expected, label):
    got=m[addr:addr+len(expected)]
    if got!=expected:
        raise SystemExit(f"{label} mismatch @{addr:04X}: expected {expected.hex(' ')}, got {got.hex(' ')}")
    print(f"PASS {label} @ {addr:04X}")

# Stage-5 progression and transporter trigger.
require(0xF202, bytes.fromhex("A2 80 A0 F5 20 89 E5 A9 01 8D 29 F2 EE 0E 03"), "password success sets outing flag and increments progression")
require(0x0FC9, bytes.fromhex("C9 5D D0 03 4C 11 12 C9 70 D0 03 4C 14 17"), "flight cross-sample dispatches tile $70 to transporter")
require(0x1714, bytes.fromhex("AD 1D 19 F0 01 60"), "transporter respects re-entry cooldown")
require(0x1788, bytes.fromhex("A9 32 8D 1D 19"), "transporter sets 50-frame cooldown")

# Destination scan / selection.
require(0x17FB, bytes.fromhex("A9 00 85 8F AE 2B 16 BD C2 17 85 FF A9 14 85 8E"), "transporter scans current vertical band")
require(0x181F, bytes.fromhex("B1 8B C9 77 D0 03"), "transporter destination master metatile is $77")
require(0x17C9, bytes.fromhex("46 8F EE C8 17 AD C8 17 29 0F C5 8F 10 F4 0A A8"), "persistent low-nibble destination selector")
require(0x1795, bytes.fromhex("20 FB 17 20 C9 17 B9 AE 17 38 E9 04 8D 07 07 B9 AF 17 18 69 02 8D 08 07"), "$1795 writes marker X-4 / Y+2")
require(0x1748, bytes.fromhex("8E 09 07 A0 08 8C 0B 07 A9 14 8D 4B 14"), "transporter runs twenty +8 Y-scroll frames")

# Exact final gate after those twenty tile scrolls.
require(0x089C, bytes.fromhex("AD 0E 03 C9 05 D0 0E AD 07 07 C9 50 30 07 AD 08 07 C9 50 10 C3"), "stage 5 plus macro X>=80 / Y<80 final gate")

# Final effect waits for FIRE, then tags restored overlay with $7B.
require(0x3FAF, bytes.fromhex("AD 01 DC 2D 00 DC 29 10 F0 0D"), "final effect waits for FIRE")
require(0x3FC6, bytes.fromhex("20 B1 08 A9 00 8D 5D 07 8D 49 E0 A9 7B 8D 0D 03 4C 46 CF"), "victory handoff writes $030D=$7B and restores overlay")

# Overlay recognizes $7B and enters dedicated ending route.
require(0x80CB, bytes.fromhex("AD 0D 03 C9 7B D0 10 A9 00 20 B7 8F A2 00 20 27 87 20 27 87 4C 6F 81"), "restored overlay selects special ending path")
require(0x816F, bytes.fromhex("A9 00 8D 15 D0 8D 0D 03"), "ending route clears sprite enable and $030D marker")

# Ending only proceeds if current six-digit ASCII score beats stored best score.
require(0x8810, bytes.fromhex("A2 FF E8 BD 5B 83 38 DD 26 02 F0 F6 90 03 4C 14 80"), "ending score must strictly beat best-score record")
assert m[0x835B:0x8361] == b"000010"
assert m[0x8366:0x836B] == b"CHRIX"
print("PASS initial best-score record 000010 / CHRIX")

# Player-facing ending strings in the restored overlay.
ending_blob=m[0x8889:0x8918]
for text in (
    b"WELL DONE CAP'N",
    b"EVEN THOUGH ALL OUR BOYS WERE",
    b"BLOWN TO PIECES..",
    b"YOU STILL INFLICTED ENOUGH DAMAGE ON",
    b"THE ENEMY TO BECOME A MEGA HERO",
):
    if text not in ending_blob:
        raise SystemExit(f"ending text missing: {text!r}")
print("PASS recovered ending message strings")

# Five-character joystick name entry: UP increments, DOWN decrements, FIRE accepts.
require(0x8EAE, bytes.fromhex("AD AB 8E F0 08 AD 00 DC 29 10 D0 01 60"), "name entry FIRE/release gate")
require(0x8ED1, bytes.fromhex("AD 00 DC 85 8F 29 08 D0 03 FE 0E 7F A5 8F 29 04 D0 03 DE 0E 7F"), "UP/DOWN modify current name character")
require(0x8EE6, bytes.fromhex("BD 0E 7F 29 3F 9D 0E 7F"), "name character is six-bit screen code")
require(0x8F00, bytes.fromhex("EE AD 8E AD AD 8E C9 05 F0 09"), "five accepted characters complete name entry")

# Score/name record update and return to title.
require(0x8F13, bytes.fromhex("A2 06 BD 25 02 9D 5A 83 BD 0C 7F"), "ending copies six score digits and entered name into best record")
require(0x8F5B, bytes.fromhex("A2 32 20 27 87 4C C0 BF"), "ending teardown jumps to title/save trampoline")
require(0xBFFD, bytes.fromhex("4C 14 80"), "post-ending path returns to title loop")

# Correct runtime master-map source: first $1000 bytes are parked under I/O
# until $CFA3 swaps them into $8000-$8FFF.
require(0xCFA3, bytes.fromhex("A2 10 A9 80 D0 02 A9 50 85 FD"), "overlay/world swap selects $8000 source window")
require(0xCFB7, bytes.fromhex("A9 D0 85 8C A0 00 B1 8B 48 B1 FC 91 8B 68 91 FC"), "overlay/world swap pairs $8000 window with RAM under $D000 I/O")
runtime_master=m[0xD000:0xE000] + m[0x9000:0xA400]
assert len(runtime_master)==96*96
markers=[(i%96,i//96) for i,v in enumerate(runtime_master) if v==0x77]
assert len(markers)==18
qualifying=[p for p in markers if p[0]-4>=0x50 and p[1]-2<0x50]
assert qualifying==[(90,59)]
print("PASS corrected runtime master map has 18 $77 markers and unique winner (90,59)->(86,57)")

print("PARALLAX ENDGAME STATIC VERIFICATION: PASS")
