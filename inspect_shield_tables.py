from pathlib import Path
m=Path(r"E:\Projects\Parallax\Unpacked\playable_ram.bin").read_bytes()

for a,b,name in [(0x1B80,0x1C00,"inventory/status tables"),(0xE700,0xE720,"ground state index tables")]:
    print("\n",name)
    for p in range(a,b,16):
        print("{:04X}: ".format(p)+" ".join("{:02X}".format(x) for x in m[p:min(p+16,b)]))

table=m[0x1BB5:0x1C00]
print("\n0x26 offsets in 1BB5-1BFF:",[hex(0x1BB5+i) for i,x in enumerate(table) if x==0x26])
print("0x26 offsets in E700-E71F:",[hex(0xE700+i) for i,x in enumerate(m[0xE700:0xE720]) if x==0x26])
