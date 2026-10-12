from pathlib import Path
mem=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()

def s8(x): return x-256 if x>=128 else x

print("0DD0-0E2F")
for p in range(0x0DD0,0x0E30,16):
    chunk=mem[p:p+16]
    print(f"{p:04X}: "+" ".join(f"{b:02X}" for b in chunk)+"   "+ " ".join(f"{s8(b):4d}" for b in chunk))

print("\nheading target pairs mode0 from 0DD0(Y),0E00(X)")
for h in range(16):
    y=s8(mem[0x0DD0+h]); x=s8(mem[0x0E00+h])
    print(f"h={h:02d} x={x:4d} y={y:4d}")

print("\nheading target pairs mode1 from 0DE0(Y),0E10(X)")
for h in range(16):
    y=s8(mem[0x0DE0+h]); x=s8(mem[0x0E10+h])
    print(f"h={h:02d} x={x:4d} y={y:4d}")
