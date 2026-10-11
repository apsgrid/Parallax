from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
import re
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\runtime_ram.bin").read_bytes())
m=MPU(); m.memory[:]=mem; d=Disassembler(m)
print("RUNTIME ENTRY 0B40")
pc=0x0B40
for _ in range(220):
    ln,txt=d.instruction_at(pc)
    bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
    print(f"{pc:04X}: {bs:<9} {txt}")
    pc+=ln
print("\nTEXT >=8")
for mat in re.finditer(rb"[ -~]{8,}",bytes(mem[0x0800:0xD6DC])):
    addr=0x0800+mat.start()
    if addr<0xB000:
        print(f"{addr:04X}: {mat.group().decode('latin1','replace')}")
