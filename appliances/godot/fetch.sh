#!/usr/bin/env bash
# Thin-batteries test: determinism — restores the exact pinned appliance binary
# (URL + sha256 from PIN.json) so every session runs the identical Godot build.
set -euo pipefail
cd "$(dirname "$0")"

URL=$(python3 -c "import json;print(json.load(open('PIN.json'))['url'])")
SHA=$(python3 -c "import json;print(json.load(open('PIN.json'))['sha256'])")
ASSET=$(python3 -c "import json;print(json.load(open('PIN.json'))['asset'])")
BIN=$(python3 -c "import json;print(json.load(open('PIN.json'))['binary'])")

if [[ -x "$BIN" ]]; then
  echo "already present: $BIN"
else
  [[ -f "$ASSET" ]] || curl -sL -o "$ASSET" "$URL"
  echo "$SHA  $ASSET" | sha256sum -c -
  unzip -o -q "$ASSET"
  chmod +x "$BIN"
fi

ln -sf "$BIN" godot
./godot --version
