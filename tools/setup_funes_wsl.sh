#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.local/bin"

if [[ ! -x "$HOME/.local/bin/funes" ]]; then
  curl -fsSL https://huggingface.co/buckets/huggingface/funes/resolve/install.sh | sh
fi

if [[ ! -x "$HOME/.local/bin/trufflehog" ]]; then
  TMP="$(mktemp -d)"
  trap 'rm -rf "$TMP"' EXIT
  cd "$TMP"
  curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh -s -- -b "$HOME/.local/bin"
fi

PROFILE="$HOME/.profile"
touch "$PROFILE"
grep -F 'export PATH="$HOME/.local/bin:$PATH"' "$PROFILE" >/dev/null 2>&1 || echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
grep -F 'export FUNES_TRUFFLEHOG="$HOME/.local/bin/trufflehog"' "$PROFILE" >/dev/null 2>&1 || echo 'export FUNES_TRUFFLEHOG="$HOME/.local/bin/trufflehog"' >> "$PROFILE"

export PATH="$HOME/.local/bin:$PATH"
export FUNES_TRUFFLEHOG="$HOME/.local/bin/trufflehog"
funes --version
trufflehog --version
