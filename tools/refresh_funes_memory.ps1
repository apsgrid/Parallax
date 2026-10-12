$ErrorActionPreference='Stop'
$root='E:\Projects\Parallax'
python "$root\build_funes_memory.py"
wsl.exe -d Ubuntu -- bash /mnt/e/Projects/Parallax/tools/index_funes_memory.sh
