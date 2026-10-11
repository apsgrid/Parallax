from pathlib import Path
r=Path(r"E:\Projects\Parallax\Extracted\00_PARALLAX.prg").read_bytes()
load=r[0] | (r[1]<<8)
mem=bytearray(65536)
mem[load:load+len(r)-2]=r[2:]
for i in range(256):
    mem[0x00F0+i]=mem[0xBEA2+i]
for a,b in [(0x00F0,0x0110),(0x0146,0x01BF),(0xBDA2,0xBE20)]:
    print(f"RANGE {a:04X}-{b:04X}")
    for p in range(a,b,16):
        chunk=mem[p:min(p+16,b)]
        print(f"{p:04X}: "+" ".join(f"{x:02X}" for x in chunk))
