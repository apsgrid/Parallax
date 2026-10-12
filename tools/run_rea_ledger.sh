#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
ROOT=/mnt/e/Projects/Parallax
mkdir -p "$ROOT/rea_audit"
node "$ROOT/tools/build_rea_ledger.mjs" > "$ROOT/rea_audit/ledger_request.json"
rea build-reconstruction-obligation-ledger "$ROOT/rea_audit/ledger_request.json" --format json --full-output > "$ROOT/rea_audit/reconstruction_ledger.json"
python3 - <<'PY'
import json
p="/mnt/e/Projects/Parallax/rea_audit/reconstruction_ledger.json"
d=json.load(open(p))
print(json.dumps(d,indent=2)[:20000])
PY
