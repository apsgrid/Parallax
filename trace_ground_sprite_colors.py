from pathlib import Path
m=Path(r'E:\Projects\Parallax\Unpacked\playable_ram.bin').read_bytes()
ops={0x8D:'STA',0x9D:'STA,X',0x99:'STA,Y'}
for t in (0xD025,0xD026,0xD028,0xD029):
 print('TARGET',hex(t))
 for a in range(0x0800,0xFFFD):
  if m[a] in ops and (m[a+1]|(m[a+2]<<8))==t:
   print(hex(a),ops[m[a]],'prev',m[max(0,a-8):a+4].hex(' '))
