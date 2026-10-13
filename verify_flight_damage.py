from pathlib import Path
import hashlib

RAM_PATH = Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin')
RAM_SHA256 = '232471c51e24254873f182b865378aca60a0b171490d75c66123e007e1cdb137'
m = RAM_PATH.read_bytes()
assert hashlib.sha256(m[0x0800:]).hexdigest() == RAM_SHA256, 'canonical $0800-$FFFF output hash mismatch'

def require(address, data, label):
    actual = m[address:address + len(data)]
    assert actual == data, f'{label}: expected {data.hex()} at ${address:04X}, got {actual.hex()}'
    print(f'PASS {label} @ ${address:04X}')

require(0x1CA0, b'L.GEAR', 'damage panel L.GEAR label')
require(0x1CA8, b'ENGINE', 'damage panel ENGINE label')
require(0x1CB0, b'LAZERS', 'damage panel LAZERS label')
require(0x1CB8, b'FUEL', 'inventory FUEL label for $CF03')

require(0x2022, bytes.fromhex(
    'AD 15 CF D0 01 60 AA C9 01 D0 05 A9 00 8D 13 CF '
    '20 7A 20 29 07 18 69 02 BC FF CE 7D FF CE 9D FF CE '
    'A9 00 8D 15 CF C0 00 D0 06 E8 E8 8A 20 A8 1F A0 0A 4C 40 C4'
), '$CF15 impact consumer / 2..9 indexed damage')

require(0x2058, bytes.fromhex(
    'EE 57 20 AD 57 20 C9 5A F0 01 60 A9 00 8D 57 20 '
    'A0 03 B9 FF CE F0 06 38 E9 01 99 FF CE 88 D0 F2 60'
), '90-tick $CF00-$CF02 damage recovery')

require(0x207A, bytes.fromhex('EE 79 20 AC 79 20 B9 00 C0 60'), '$C000,Y damage random source')
require(0x093C, bytes.fromhex('AE 01 CF E0 28 30 08 A2 00 8E 09 07 8E 0B 07'), 'ENGINE >= 40 velocity suppression')
require(0x10EF, bytes.fromhex('AD 01 CF C9 28 10 04 A9 01 85 F4'), 'ENGINE < 40 landing transition gate')
require(0x10FC, bytes.fromhex('AD 02 CF C9 07 10 F7'), 'LAZERS >= 7 fire lockout')
require(0x2009, bytes.fromhex('AD 27 CF D0 01 60 A9 00 8D 27 CF AD 26 CF 49 01 8D 26 CF 18 69 06 4C A8 1F'), '$CF26 shield toggle/status path')

ops = {0xAD,0x8D,0xCD,0x2D,0x0D,0x4D}
refs = []
for a in range(0x0800, 0xFFFD):
    if m[a] in ops and (m[a+1] | (m[a+2] << 8)) == 0xCF26:
        refs.append(a)
assert refs == [0x1D48, 0x2014, 0x2019], f'unexpected direct $CF26 consumers: {[hex(x) for x in refs]}'
print('PASS $CF26 direct references remain status/toggle only:', ', '.join(f'${x:04X}' for x in refs))

print('PARALLAX FLIGHT DAMAGE STATIC VERIFICATION: PASS')
