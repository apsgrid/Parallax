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


require(0xF8C6, bytes.fromhex('4C F6 FD'), 'three-object scheduler tail-calls hostile projectile updater')

require(0xFACC, bytes.fromhex(
    'AD 26 F8 C9 05 10 04 C9 FA 10 0B '
    'AD 25 F8 C9 01 10 0C C9 C8 30 08 '
    'A9 00 8D 28 F8 68 68 60 '
    '20 C4 FB 29 07 C9 04 F0 01 60 '
    'AE 25 F8 AC 26 F8 4C 58 FF'
), '$FACC bounds/fire gate and $FF58 handoff')

require(0xFBC4, bytes.fromhex('EE C3 FB AC C3 FB B9 00 09 60'), 'independent hostile-fire RNG cursor over $0900')

require(0xFF58, bytes.fromhex(
    '85 8F AD F1 FD D0 1F '
    '8E F1 FD 8C F2 FD AD 28 F8 8D F5 FD '
    '29 01 49 01 0A 0A 0A 8D F4 FD '
    '20 B9 FB 29 07 8D F3 FD 60'
), 'first persistent hostile projectile slot')

require(0xFF7E, bytes.fromhex(
    'AD 80 FE D0 1F '
    '8E 80 FE 8C 81 FE AD 28 F8 8D 84 FE '
    '29 01 49 01 0A 0A 0A 0A 8D 83 FE '
    '20 B9 FB 29 07 8D 82 FE 60'
), 'second persistent hostile projectile slot')

require(0xFDF6, bytes.fromhex(
    'AD F1 FD D0 03 4C 85 FE '
    'AD F5 FD C9 FF F0 F6 '
    'AD 09 07 18 69 08 A8 B9 86 FA 85 8F '
    'AE F3 FD AD F1 FD 18 65 8F 18 7D 3F FB 8D F1 FD '
    'AD F2 FD 18 6D 0B 07 18 7D 47 FB 8D F2 FD'
), 'first hostile projectile movement with craft compensation')

require(0xFF0F, bytes.fromhex(
    'EE 4F FF AD 4F FF C9 04 D0 12 A2 00 8E 4F FF '
    'EE 50 FF AD 50 FF C9 06 D0 03 8E 50 FF'
), 'shared four-tick/six-pointer hostile animation counter')
require(0xFF52, bytes.fromhex('56 57 58 59 58 57'), 'hostile active sprite pointer cycle')

require(0xF62A, bytes.fromhex(
    'AD 73 F8 F0 01 60 '
    'AD F1 FD F0 2A 8D 25 F8 '
    'AD F2 FD 8D 26 F8 AD F5 FD 8D 28 F8 '
    'A9 01 8D 29 F6 20 73 F7 '
    'A2 00 8E 29 F6 C9 FF D0 0A '
    'A9 FF 8D F5 FD A9 BE 8D F4 FD'
), 'hostile slot collision bridge into ordinary object/craft collision')

require(0xF68F, bytes.fromhex(
    'AD F5 FD C9 FF D0 25 '
    'EE F3 FD AD F3 FD 29 01 D0 03 '
    'EE F4 FD AD F4 FD 8D FB 7B 8D FB 7F '
    'C9 C7 D0 0B A9 00 8D F1 FD 8D F5 FD 8D 4D 07'
), '$BE-$C7 hostile impact/explosion sequence')

require(0xFFA3, bytes.fromhex(
    'A5 F4 F0 01 60 20 B9 FB 29 03 AA BD B5 FF 8D 15 CF 60'
), 'hostile impact queues shared $CF15 craft-damage event')
require(0xFFB5, bytes.fromhex('02 02 03 02'), 'shared craft-damage event-code table')

print('PARALLAX AUX PROJECTILE STATIC VERIFICATION: PASS')
