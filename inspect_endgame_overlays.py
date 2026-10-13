from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
root=Path(r'E:\\Projects\\Parallax\\Unpacked')
files=['playable_ram.bin','overlay_game_ram.bin','final_game_ram.bin','runtime_ram.bin']
def get(path): return bytearray((root/path).read_bytes())
for fn in files:
 m=get(fn); print('\nFILE',fn,'len',len(m))
 print('8000:', ' '.join(f'{b:02X}' for b in m[0x8000:0x8030]))
 print('80C0:', ' '.join(f'{b:02X}' for b in m[0x80C0:0x8190]))
 print('030D:',m[0x030D] if len(m)>0x030D else None)

m=get('playable_ram.bin'); c=MPU(); c.memory[:]=m; d=Disassembler(c)
def dump(a,b):
 print(f'\n=== playable {a:04X}-{b:04X} ==='); pc=a
 while pc<b:
  ln,t=d.instruction_at(pc); bs=' '.join(f'{m[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln
dump(0x8000,0x81B0)

for fn in files[1:]:
 mm=get(fn); cc=MPU(); cc.memory[:]=mm; dd=Disassembler(cc)
 print(f'\n=== {fn} 8000-81B0 ==='); pc=0x8000
 while pc<0x81B0:
  ln,t=dd.instruction_at(pc); bs=' '.join(f'{mm[pc+i]:02X}' for i in range(ln)); print(f'{pc:04X}: {bs:<10} {t}'); pc+=ln