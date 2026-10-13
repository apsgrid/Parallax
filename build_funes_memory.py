from pathlib import Path
import json, subprocess, datetime

root=Path(r"E:\Projects\Parallax")
outdir=root/".memory_source"
outdir.mkdir(exist_ok=True)
out=outdir/"parallax-reconstruction.funes.jsonl"

docs=[
    ("project-overview","README.md"),
    ("reverse-engineering-notes","RE_NOTES.md"),
    ("flight-state","FLIGHT_STATE.md"),
    ("transition-state","TRANSITION_STATE.md"),
    ("supply-state","SUPPLY_STATE.md"),
    ("ground-state","GROUND_STATE.md"),
    ("world-format","WORLD_FORMAT.md"),
    ("tile-graphics","TILE_GRAPHICS.md"),
    ("re-tooling","RE_TOOLING.md"),
    ("rea-audit","REA_AUDIT.md"),
    ("godot-prototype","Godot/README.md"),
]

turns=[]
seq=0
session="parallax-reconstruction-2026-10-12"
ts0=datetime.datetime(2026,10,12,0,0,0,tzinfo=datetime.timezone.utc)

def add(role,text,label):
    global seq
    t={
      "format":1,
      "session_id":session,
      "cwd":"/mnt/e/Projects/Parallax",
      "turn_uuid":f"{session}-{seq:04d}-{label}",
      "seq":seq,
      "ts":(ts0+datetime.timedelta(seconds=seq)).isoformat().replace("+00:00","Z"),
      "role":role,
      "blocks":[{"block_type":"text","text":text}],
      "harness":"parallax-re"
    }
    if seq:
      t["parent_uuid"]=turns[-1]["turn_uuid"]
    turns.append(t); seq+=1

add("user","Build a durable memory of the verified Parallax C64 reverse-engineering findings. Distinguish verified facts, strong interpretations, open questions, and corrected dead ends.","memory-goal")

for label,rel in docs:
    p=root/rel
    add("user",f"Record the current authoritative project document {rel}.","request-"+label)
    add("assistant",f"SOURCE: {rel}\n\n"+p.read_text(encoding="utf-8",errors="replace"),label)

log=subprocess.check_output(["git","-C",str(root),"log","--reverse","--format=%H\t%ad\t%s","--date=iso-strict"],text=True,encoding="utf-8",errors="replace")
add("user","Record the reconstruction milestone history.","request-git-history")
add("assistant","GIT MILESTONES:\n"+log,"git-history")

with out.open("w",encoding="utf-8",newline="\n") as f:
    for t in turns:
        f.write(json.dumps(t,ensure_ascii=False,separators=(",",":"))+"\n")
print(out)
print("turns",len(turns),"bytes",out.stat().st_size)
