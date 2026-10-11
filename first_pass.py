from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
import re

mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\ram_after_decrunch.bin").read_bytes())
m=MPU()
m.memory[:]=mem
d=Disassembler(m)

print("ENTRY DISASSEMBLY")
pc=0x0801
for _ in range(140):
    ln,txt=d.instruction_at(pc)
    bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
    print(f"{pc:04X}: {bs:<9} {txt}")
    pc+=ln

print("\nASCII/PETSCII-LIKE STRINGS >=6 IN GAME RANGE")
blob=bytes(mem[0x0801:0xD6C0])
for mat in list(re.finditer(rb"[ -~]{6,}",blob))[:120]:
    addr=0x0801+mat.start()
    s=mat.group().decode("latin1","replace")
    print(f"{addr:04X}: {s}")

print("\nCOMMON C64 HARDWARE REFERENCES")
targets=[0xD011,0xD012,0xD015,0xD016,0xD018,0xD019,0xD01A,0xD020,0xD021,0xD400,0xD404,0xD418,0xDC00,0xDC01,0xDD00]
for t in targets:
    lo=t&255; hi=t>>8
    hits=[]
    for a in range(0x0801,0xD6BE):
        if mem[a+1]==lo and mem[a+2]==hi and mem[a] in (0xAD,0x8D,0xAE,0x8E,0xAC,0x8C,0x2C,0xCD,0xCC,0xEC,0xEE,0xCE,0x0D,0x2D,0x4D,0x6D,0xED):
            hits.append(a)
    if hits:
        print(f"{t:04X}: "+", ".join(f"{x:04X}" for x in hits[:40]))
