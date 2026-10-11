from pathlib import Path
import hashlib, json

D64 = Path(r"E:\Projects\Parallax\Source\PARALLAX.D64")
OUT = Path(r"E:\Projects\Parallax\Extracted")
OUT.mkdir(parents=True, exist_ok=True)

def spt(track):
    if 1 <= track <= 17: return 21
    if 18 <= track <= 24: return 19
    if 25 <= track <= 30: return 18
    if 31 <= track <= 35: return 17
    raise ValueError(track)

def sector_offset(track, sector):
    if sector < 0 or sector >= spt(track): raise ValueError((track, sector))
    return (sum(spt(t) for t in range(1, track)) + sector) * 256

data = D64.read_bytes()

def sector(track, sec):
    o = sector_offset(track, sec)
    return data[o:o+256]

def petscii_name(raw):
    raw = raw.rstrip(b"\xa0\x00")
    return ''.join(chr(b) if 32 <= b < 127 else f'_{b:02X}' for b in raw)

entries = []
t, s = 18, 1
seen = set()
while t:
    if (t,s) in seen: raise RuntimeError("directory loop")
    seen.add((t,s))
    blk = sector(t,s)
    nt, ns = blk[0], blk[1]
    for i in range(8):
        e = blk[2+i*32:2+(i+1)*32]
        ftype = e[0]
        if ftype == 0: continue
        start_t, start_s = e[1], e[2]
        name = petscii_name(e[3:19])
        blocks = e[30] | (e[31] << 8)
        entries.append(dict(index=len(entries), type=ftype, start_track=start_t, start_sector=start_s, name=name, blocks=blocks))
    t, s = nt, ns

def extract_chain(t, s):
    out = bytearray(); chain=[]; seen=set()
    while t:
        if (t,s) in seen: raise RuntimeError(f"file loop at {(t,s)}")
        seen.add((t,s)); chain.append((t,s))
        blk = sector(t,s)
        nt, ns = blk[0], blk[1]
        if nt == 0:
            used = max(0, ns - 1)
            out += blk[2:2+used]
            break
        out += blk[2:]
        t, s = nt, ns
    return bytes(out), chain

manifest=[]
for e in entries:
    payload, chain = extract_chain(e["start_track"], e["start_sector"])
    safe = ''.join(c if c.isalnum() or c in '._-' else '_' for c in e["name"]).strip('_') or f'file_{e["index"]:02d}'
    suffix = '.prg' if (e["type"] & 7) == 2 else '.bin'
    p = OUT / f'{e["index"]:02d}_{safe}{suffix}'
    p.write_bytes(payload)
    sha=hashlib.sha256(payload).hexdigest()
    load = payload[0] | (payload[1]<<8) if len(payload)>=2 and suffix=='.prg' else None
    item={**e,"extracted":str(p),"bytes":len(payload),"sha256":sha,"load_address":load,"chain":chain}
    manifest.append(item)

(OUT/"manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
print(f"D64 bytes: {len(data)} SHA256={hashlib.sha256(data).hexdigest()}")
for x in manifest:
    typ=x["type"]&7
    loadtxt = "-" if x["load_address"] is None else f"\${x['load_address']:04X}"
    print(f'{x["index"]:02d} type={typ} blocks={x["blocks"]:3d} start={x["start_track"]:02d}/{x["start_sector"]:02d} bytes={x["bytes"]:6d} load={loadtxt} name={x["name"]!r}')
