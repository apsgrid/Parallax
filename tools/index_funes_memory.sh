#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export FUNES_HOME=/mnt/e/Projects/Parallax/.funes
export FUNES_TRUFFLEHOG="$HOME/.local/bin/trufflehog"
SOURCE=/mnt/e/Projects/Parallax/.memory_source/parallax-reconstruction.funes.jsonl
funes index --check "$SOURCE"
funes index "$SOURCE" --yes
funes status
