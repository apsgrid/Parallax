from pathlib import Path
from py65.devices.mpu6502 import MPU
from py65.disassembler import Disassembler
import hashlib,json

base=Path(r"E:\Projects\Parallax\Unpacked")
mem=bytearray((base/"playable_ram.bin").read_bytes())
# Canonical Stage-5 image is exactly 0800-FFFF (0xF800 bytes).
img=bytes(mem[0x0800:0x10000])
(base/"playable_image.bin").write_bytes(img)
report=json.loads((base/"playable_report.json").read_text())
report.pop("output_end_wrapped",None)
report["output_bytes"]=len(img)
report["sha256"]=hashlib.sha256(img).hexdigest()
(base/"playable_report.json").write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))

m=MPU();m.memory[:]=mem;d=Disassembler(m)
def dump(start,count):
 print(f"\n--- {start:04X} ---")
 pc=start
 for _ in range(count):
  ln,txt=d.instruction_at(pc)
  bs=" ".join(f"{mem[pc+i]:02X}" for i in range(ln))
  print(f"{pc:04X}: {bs:<9} {txt}")
  pc=(pc+ln)&0xFFFF

dump(0x7C00,180)
dump(0x097D,120)
dump(0x3FEC,80)
