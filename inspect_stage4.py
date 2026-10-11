from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
mem=bytearray(Path(r"E:\Projects\Parallax\Unpacked\overlay_game_ram.bin").read_bytes())
# copy stage-4 depacker
for i in range(256): mem[0x00F0+i]=mem[0x8EE8+i]
m=MPU();m.memory[:]=mem;d=Disassembler(m)
print("BYTES")
for p in range(0x00F0,0x01C0,16):
 print(f"{p:04X}: "+" ".join(f"{b:02X}" for b in mem[p:p+16]))
print("\nDISASM")
pc=0x00F0
for _ in range(120):
 ln,txt=d.instruction_at(pc);bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
 print(f"{pc:04X}: {bs:<9} {txt}");pc+=ln
