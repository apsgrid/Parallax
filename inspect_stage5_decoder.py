from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\final_game_ram.bin").read_bytes())
# Reproduce 0801 relocation: source begins DA8D, dest FFFF, pages downward until source high reaches 07.
src_hi=0xDA; src_lo=0x8D; dst_hi=0xFF; dst_lo=0xFF
# This loop decrements high bytes at 0817/081A before each page copy.
s_hi=src_hi; d_hi=dst_hi
y=0
while True:
    s_hi=(s_hi-1)&255
    d_hi=(d_hi-1)&255
    for y in range(256):
        mem[(d_hi<<8)|0xFF + 0 if False else ((d_hi<<8)|0xFF)] = mem[(d_hi<<8)|0xFF]
    # actual indexed bases are DA8D/Y? Need show self-modified instruction bytes first.
    if s_hi==0x07: break

# Only inspect copied decoder directly; no relocation needed for it.
for x in range(0x6A,0,-1):
    mem[0x00FC+x]=mem[0x0832+x]
m=MPU();m.memory[:]=mem;d=Disassembler(m)
print("DECODER BYTES 00FC-0180")
for p in range(0x00FC,0x0180,16):
    print(f"{p:04X}: "+" ".join(f"{b:02X}" for b in mem[p:p+16]))
print("\nDECODER DISASM")
pc=0x00FD
for _ in range(120):
    ln,txt=d.instruction_at(pc)
    bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
    print(f"{pc:04X}: {bs:<9} {txt}")
    pc+=ln
