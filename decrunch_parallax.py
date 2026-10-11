from pathlib import Path
import hashlib, json

src=Path(r"E:\Projects\Parallax\Extracted\00_PARALLAX.prg")
outdir=Path(r"E:\Projects\Parallax\Unpacked")
outdir.mkdir(parents=True,exist_ok=True)

r=src.read_bytes()
load=r[0] | (r[1]<<8)
mem=bytearray(65536)
mem[load:load+len(r)-2]=r[2:]

# Loader copies a 256-byte decrunch table/block from BDA2 to 071C.
mem[0x071C:0x081C]=mem[0xBDA2:0xBEA2]

source=0xBDA2
dest=0xD6BF
bitbuf=0xC0
carry=0
stats={"source_bytes":0,"dest_bytes":0,"literal_bytes":0,"match_bytes":0,"matches":0,"literal_runs":0,"match_groups":0}

def read_source():
    global source
    source=(source-1)&0xFFFF
    stats["source_bytes"]+=1
    return mem[source]

def write_dest(v):
    global dest
    mem[dest]=v&0xFF
    stats["dest_bytes"]+=1
    dest=(dest-1)&0xFFFF

def rol(v,c):
    return (((v<<1)&0xFF)|(c&1), (v>>7)&1)

def adc(a,b,c):
    s=a+b+c
    return s&0xFF, 1 if s>0xFF else 0

def getbits(n):
    global bitbuf,carry
    a3=a4=0
    for _ in range(n):
        carry=(bitbuf>>7)&1
        bitbuf=(bitbuf<<1)&0xFF
        if bitbuf==0:
            a=read_source()
            a,carry=rol(a,carry)
            bitbuf=a
        a3,carry=rol(a3,carry)
        a4,carry=rol(a4,carry)
    return a3,a4

def code(initial_y=0x1F, increment_first=True):
    global carry
    y=initial_y
    first=True
    while True:
        if increment_first or not first:
            y=(y+1)&0xFF
        first=False
        a3,a4=getbits(1)
        if a3!=0:
            continue
        if y==0x30:
            raise StopIteration
        n=mem[0x071C+y]
        if n:
            a3,a4=getbits(n)
        else:
            a3=0
        a,carry=adc(a3,mem[0x072C+y],carry)
        return a

try:
    while True:
        litlen=code()
        stats["literal_runs"]+=1
        for _ in range(litlen):
            write_dest(read_source())
            stats["literal_bytes"]+=1

        group=code()
        stats["match_groups"]+=1
        aa=group
        while aa:
            mlen=code(initial_y=0,increment_first=False)
            saved_len=mlen
            y=(mlen-1)&0xFF

            if y==0:
                a3,a4=getbits(3)
                low=a3
                high=0
            else:
                y=(y-1)&0xFF
                if y==0:
                    idxbase=0
                    xbase=0
                else:
                    idxbase=4
                    xbase=1
                a3,a4=getbits(xbase+2)
                idx,carry=adc(idxbase,a3,carry)
                yidx=idx
                n=mem[0x075C+yidx]
                a3,a4=getbits(n)
                low,carry=adc(a3,mem[0x0769+yidx],carry)
                high,carry=adc(a4,mem[0x0776+yidx],carry)
                if yidx==4:
                    if low==0:
                        yidx=0x0C
                        n=mem[0x075C+yidx]
                        a3,a4=getbits(n)
                        low,carry=adc(a3,mem[0x0769+yidx],carry)
                        high,carry=adc(a4,mem[0x0776+yidx],carry)

            offset=(high<<8)|low
            matchptr=(dest+offset+1)&0xFFFF
            stats["matches"]+=1
            for i in range(saved_len):
                v=mem[(matchptr-i)&0xFFFF]
                write_dest(v)
                stats["match_bytes"]+=1
            aa=(aa-1)&0xFF

except StopIteration:
    pass

lo=(dest+1)&0xFFFF
hi=0xD6BF
(outdir/"ram_after_decrunch.bin").write_bytes(mem)
(outdir/"game_unpacked.bin").write_bytes(mem[lo:hi+1])
report={
    "packed_prg":str(src),"load_address":load,
    "compressed_source_start":0xBDA1,"compressed_source_final":source,
    "output_high":hi,"output_low":lo,
    "entry_point":0x0801,"bitbuf_final":bitbuf,
    "stats":stats,
    "ram_sha256":hashlib.sha256(mem).hexdigest(),
    "game_sha256":hashlib.sha256(mem[lo:hi+1]).hexdigest()
}
(outdir/"decrunch_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report,indent=2))
