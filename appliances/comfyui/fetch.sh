#!/usr/bin/env bash
# Thin-batteries test: determinism — restores the exact pinned appliance
# (runtime commit + model revisions + sha256 from PIN.json) so every session
# generates against the identical stack. Idempotent; safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"

pin() { python3 -c "import json,sys;d=json.load(open('PIN.json'));print(eval('d'+sys.argv[1]))" "$1"; }

REPO=$(pin "['runtime']['repo']")
COMMIT=$(pin "['runtime']['commit']")

if [[ ! -d ComfyUI/.git ]]; then
  git clone -q "$REPO" ComfyUI
fi
git -C ComfyUI fetch -q origin "$COMMIT" 2>/dev/null || true
git -C ComfyUI checkout -q "$COMMIT"

if [[ ! -x ComfyUI/venv/bin/python ]]; then
  python3 -m venv ComfyUI/venv
  ComfyUI/venv/bin/pip install -q --upgrade pip
  ComfyUI/venv/bin/pip install -q torch torchvision --index-url https://download.pytorch.org/whl/cu124
  ComfyUI/venv/bin/pip install -q -r ComfyUI/requirements.txt
fi

python3 - <<'EOF'
import json, hashlib, pathlib, subprocess
pin = json.load(open("PIN.json"))
for m in pin["models"]["provisioned"]:
    p = pathlib.Path(m["file"])
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        print(f"fetching {m['key']}…")
        subprocess.run(["curl", "-sL", "-o", str(p), m["source"]], check=True)
    digest = hashlib.sha256(p.read_bytes()).hexdigest()
    if m["sha256"] == "PENDING_DOWNLOAD":
        print(f"  {m['key']}: sha256 {digest} (record in PIN.json)")
    elif digest != m["sha256"]:
        raise SystemExit(f"SHA MISMATCH {m['key']}: {digest} != {m['sha256']}")
    else:
        print(f"  {m['key']}: OK")
EOF
echo "appliance ready: $(git -C ComfyUI log --oneline -1)"
