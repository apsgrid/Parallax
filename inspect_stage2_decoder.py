from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler

mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\ram_after_decrunch.bin").read_bytes())

# Reproduce page relocation exactly.
for a in range(0xD6BF,0x07BF,-1):
    mem[a+0x293F]=mem[a]

# Reproduce the copied decoder bytes: X=3A down to 1.
for x in range(0x3A,0,-1):
    mem[0x00FC+x]=mem[0x0832+x]

m=MPU(); m.memory[:]=mem; d=Disassembler(m)

print("BYTES 00F0-0160")
for p in range(0x00F0,0x0160,16):
    print(f"{p:04X}: "+" ".join(f"{b:02X}" for b in mem[p:p+16]))

print("\nDISASM FROM 00FD")
pc=0x00FD
for _ in range(90):
    ln,txt=d.instruction_at(pc)
    bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
    print(f"{pc:04X}: {bs:<9} {txt}")
    pc+=ln
