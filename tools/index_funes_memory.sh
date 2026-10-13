#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export FUNES_HOME=/mnt/e/Projects/Parallax/.funes
export FUNES_TRUFFLEHOG="$HOME/.local/bin/trufflehog"
SOURCE=/mnt/e/Projects/Parallax/.memory_source/parallax-reconstruction.funes.jsonl

# Project memory is an authoritative current-state index, not a revision archive.
# Rebuild it so corrected RE facts replace superseded chunks instead of coexisting
# with stale earlier wording.
funes index --check "$SOURCE"
rm -rf "$FUNES_HOME/memory"
funes index "$SOURCE" --yes
funes status
