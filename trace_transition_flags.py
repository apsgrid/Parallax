from pathlib import Path
mem=bytearray(Path(r"E:\\Projects\\Parallax\\Unpacked\\playable_ram.bin").read_bytes())

zp_ops={
0xA5:'LDA',0xA6:'LDX',0xA4:'LDY',0x85:'STA',0x86:'STX',0x84:'STY',
0x05:'ORA',0x25:'AND',0x45:'EOR',0x65:'ADC',0xE5:'SBC',0xC5:'CMP',
0xE6:'INC',0xC6:'DEC',0x06:'ASL',0x46:'LSR',0x26:'ROL',0x66:'ROR'
}
abs_call={0x20:'JSR',0x4C:'JMP'}

for target in (0xF3,0xF4):
    print('\n=== ZERO PAGE {:02X} ==='.format(target))
    for a in range(0x0800,0xFFFF):
        op=mem[a]
        if op in zp_ops and mem[a+1]==target:
            print('{:04X}: {} {:02X}'.format(a,zp_ops[op],target))

print('\n=== CALLERS/JUMPS TO E000 ===')
for a in range(0x0800,0xFFFD):
    op=mem[a]
    if op in abs_call and mem[a+1]==0x00 and mem[a+2]==0xE0:
        print('{:04X}: {}'.format(a,abs_call[op]))
