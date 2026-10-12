#!/usr/bin/env bash
set -euo pipefail

NODE_VERSION="22.20.0"
BASE="$HOME/.local/node-v$NODE_VERSION"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$HOME/.local/bin"
cd "$TMP"

curl -fsSLO "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz"
curl -fsSLO "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt"
grep " node-v$NODE_VERSION-linux-x64.tar.xz$" SHASUMS256.txt > wanted.sha256
sha256sum -c wanted.sha256

rm -rf "$BASE"
mkdir -p "$BASE"
tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" --strip-components=1 -C "$BASE"

ln -sf "$BASE/bin/node" "$HOME/.local/bin/node"
ln -sf "$BASE/bin/npm" "$HOME/.local/bin/npm"
ln -sf "$BASE/bin/npx" "$HOME/.local/bin/npx"

export PATH="$HOME/.local/bin:$BASE/bin:$PATH"

node --version
npm --version
npm install --global --prefix "$HOME/.local" rea-agents@6.4.0
rea --version
