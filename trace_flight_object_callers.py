from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
m=bytearray(Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes())
c=MPU(); c.memory[:]=m; d=Disassembler(c)
targets=[0xF874,0xF8CA,0xF6F0,0xF600,0xF629,0xF773,0xFBFF]
for target in targets:
 print(f'\nTARGET {target:04X}')
 for a in range(0x0800,0xFFFD):
  op=m[a]; w=m[a+1]|(m[a+2]<<8)
  if op in (0x20,0x4C) and w==target:
   print(f'{a:04X}: {"JSR" if op==0x20 else "JMP"}')
print('\nFC3B-FC43:', ' '.join(f'{x:02X}' for x in m[0xFC3B:0xFC43]))
print('F5FF-F610:', ' '.join(f'{x:02X}' for x in m[0xF5FF:0xF610]))
print('FDC9-FE20:', ' '.join(f'{x:02X}' for x in m[0xFDC9:0xFE20]))
print('FE7F-FEA0:', ' '.join(f'{x:02X}' for x in m[0xFE7F:0xFEA0]))
