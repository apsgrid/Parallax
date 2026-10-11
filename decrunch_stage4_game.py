from pathlib import Path
import hashlib,json
base=Path(r"E:\Projects\Parallax\Unpacked")
mem=bytearray((base/"overlay_game_ram.bin").read_bytes())
TABLE=0x8DE8
source=TABLE
dest=0xDA8C
bitbuf=0xF8
carry=0
mem[0x071C:0x081C]=mem[TABLE:TABLE+256]
stats={"source_bytes":0,"dest_bytes":0,"literal_bytes":0,"match_bytes":0,"matches":0,"literal_runs":0,"match_groups":0}
def read_source():
 global source
 source=(source-1)&0xFFFF;stats["source_bytes"]+=1;return mem[source]
def write_dest(v):
 global dest
 mem[dest]=v&255;stats["dest_bytes"]+=1;dest=(dest-1)&0xFFFF
def rol(v,c): return (((v<<1)&255)|(c&1),(v>>7)&1)
def adc(a,b,c):
 s=a+b+c;return s&255,1 if s>255 else 0
def getbits(n):
 global bitbuf,carry
 a3=a4=0
 for _ in range(n):
  carry=(bitbuf>>7)&1;bitbuf=(bitbuf<<1)&255
  if bitbuf==0:
   a=read_source();a,carry=rol(a,carry);bitbuf=a
  a3,carry=rol(a3,carry);a4,carry=rol(a4,carry)
 return a3,a4
def code(initial_y=0x1F,increment_first=True):
 global carry
 y=initial_y;first=True
 while True:
  if increment_first or not first:y=(y+1)&255
  first=False
  a3,a4=getbits(1)
  if a3:continue
  if y==0x30:raise StopIteration
  n=mem[0x071C+y]
  if n:a3,a4=getbits(n)
  else:a3=0
  a,carry=adc(a3,mem[0x072C+y],carry)
  return a
try:
 while True:
  litlen=code();stats["literal_runs"]+=1
  for _ in range(litlen):write_dest(read_source());stats["literal_bytes"]+=1
  aa=code();stats["match_groups"]+=1
  while aa:
   mlen=code(initial_y=0,increment_first=False);saved=mlen;y=(mlen-1)&255
   if y==0:
    a3,a4=getbits(3);low=a3;high=0
   else:
    y=(y-1)&255
    if y==0:idxbase=0;xbase=0
    else:idxbase=4;xbase=1
    a3,a4=getbits(xbase+2);idx,carry=adc(idxbase,a3,carry);yi=idx
    n=mem[0x075C+yi];a3,a4=getbits(n)
    low,carry=adc(a3,mem[0x0769+yi],carry);high,carry=adc(a4,mem[0x0776+yi],carry)
    if yi==4 and low==0:
     yi=0x0C;n=mem[0x075C+yi];a3,a4=getbits(n)
     low,carry=adc(a3,mem[0x0769+yi],carry);high,carry=adc(a4,mem[0x0776+yi],carry)
   match=(dest+((high<<8)|low)+1)&0xFFFF
   stats["matches"]+=1
   for i in range(saved):write_dest(mem[(match-i)&0xFFFF]);stats["match_bytes"]+=1
   aa=(aa-1)&255
except StopIteration:
 pass
lo=(dest+1)&0xFFFF;hi=0xDA8C
(base/"final_game_ram.bin").write_bytes(mem)
(base/"final_game_image.bin").write_bytes(mem[lo:hi+1])
report={"compressed_boundary":TABLE,"compressed_final":source,"output_low":lo,"output_high":hi,"entry":0x0801,"bitbuf_final":bitbuf,"stats":stats,"sha256":hashlib.sha256(mem[lo:hi+1]).hexdigest()}
(base/"final_game_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
print(json.dumps(report,indent=2))
