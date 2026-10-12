#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT=/mnt/e/Projects/Parallax
mkdir -p "$ROOT/rea_audit"
rea import-reference-source "$ROOT/Godot" --format json --full-output > "$ROOT/rea_audit/godot_reference_wsl.json"
head -c 12000 "$ROOT/rea_audit/godot_reference_wsl.json"
