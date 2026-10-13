from pathlib import Path
m=bytearray(Path(r'E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin').read_bytes())
ops={0xBD:'LDA abs,X',0xB9:'LDA abs,Y',0x9D:'STA abs,X',0x99:'STA abs,Y',0xDD:'CMP abs,X',0xD9:'CMP abs,Y',0xBC:'LDY abs,X',0xBE:'LDX abs,Y',0xFE:'INC abs,X',0xDE:'DEC abs,X'}
for a in range(0x0800,0xFFFD):
    op=m[a]; w=m[a+1]|(m[a+2]<<8)
    if op in ops and 0xCF00<=w<=0xCF3F:
        print('%04X: %s $%04X' % (a,ops[op],w))
print('pointer setups')
for a in range(0x0800,0xFFFB):
    if m[a]==0xA9 and m[a+1]==0xCF:
        print('%04X: LDA #$CF' % a)