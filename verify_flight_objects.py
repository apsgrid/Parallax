from pathlib import Path
import hashlib

RAM_PATH = Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin')
RAM_SHA256 = '232471c51e24254873f182b865378aca60a0b171490d75c66123e007e1cdb137'
m = RAM_PATH.read_bytes()

assert hashlib.sha256(m[0x0800:]).hexdigest() == RAM_SHA256, 'canonical $0800-$FFFF output hash mismatch'

def require(address, data, label):
    actual = m[address:address + len(data)]
    assert actual == data, f'{label}: expected {data.hex()} at ${address:04X}, got {actual.hex()}'
    print(f'PASS {label} @ ${address:04X}')

# $F874 owns the three-slot scheduler and copies 12 live bytes through $F825.
require(0xF874, bytes.fromhex('8D 73 F8 A9 00 8D 71 F8 8D 5F 07 8D 65 07'), 'scheduler entry/reset')
require(0xF88A, bytes.fromhex('A2 00 B9 35 F8 9D 25 F8 B9 36 F8 9D 26 F8 C8 C8 E8 E8 E0 0C D0 EC'), '12-byte slot-to-scratch copy')
require(0xF8BC, bytes.fromhex('EE 71 F8 AD 71 F8 C9 03 D0 BC 4C F6 FD'), 'exact three-slot loop')

# Per-slot update order: spawn/materialize, motion, aux-fire, animation/render, laser hit, craft/overlap collision.
require(0xF8CA, bytes.fromhex('AD 28 F8 C9 FF D0 03 4C 97 FC 20 EA F8 20 D0 F9 20 CC FA 20 8A FB 20 4F FB 20 FF FB 20 6D F7 60'), 'per-slot scheduler call chain')

# Object footprint maps VIC/screen coordinates back into the active character viewport.
require(0xF727, bytes.fromhex('AD 03 07 4A 85 8F 8A 38 E5 8F E9 0B 4A 4A 85 8F 98 38 E9 2F ED 04 07 4A 4A 29 FE A8'), 'object terrain footprint transform')

# Exact recovered movement tables.
require(0xFA7C, bytes([0,1,0,0xFF,0]), 'surface cardinal X table')
require(0xFA81, bytes([0xFF,0,1,0,0]), 'surface cardinal Y table')
require(0xFA86, bytes(x & 0xFF for x in [-4,-3,-3,-2,-2,-1,-1,0,0,0,1,1,2,2,3,3,4]), 'craft-X compensation table')
require(0xFB3F, bytes([0,1,2,1,0,0xFF,0xFE,0xFF]), 'edge-object X table')
require(0xFB47, bytes([0xFE,0xFF,0,1,2,1,0,0xFF]), 'edge-object Y table')

# Height gates shared by laser/object and craft/object collision paths.
require(0xFC3B, bytes.fromhex('07 60 14 23 00 14 1C 32'), 'four object height bands')

# Recovered sprite-pointer animation tables.
require(0xFD91, bytes.fromhex('C9 CA CB CC C9 CA CB CC'), 'state-1 sprite table')
require(0xFD99, bytes.fromhex('B9 BA BB BC B9 BA BB BC'), 'state-2 sprite table')
require(0xFDA1, bytes.fromhex('4C 4D 4E 4F 4C 4D 4E 4F'), 'state-3 sprite table')
require(0xFDB1, bytes.fromhex('48 49 4A 4B 48 49 4A 4B'), 'state-5 sprite table')
require(0xFDB9, bytes.fromhex('50 51 52 53 54 53 52 51'), 'state-6 sprite table')

# Five region rows x eight state entries.
require(0xFDC9, bytes([
    0,2,5,8,0,13,4,3,
    0,10,8,9,0,14,2,4,
    0,9,10,13,0,2,5,14,
    0,5,14,9,0,8,10,13,
    0,14,4,3,0,12,9,10,
]), 'region/state colour table')

# $FFA3 selects one of [2,2,3,2] for the downstream craft-collision event.
require(0xFFB5, bytes.fromhex('02 02 03 02'), 'craft-collision event-code table')

print('PARALLAX FLIGHT OBJECT STATIC VERIFICATION: PASS')
