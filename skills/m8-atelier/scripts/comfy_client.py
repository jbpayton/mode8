#!/usr/bin/env python3
# Thin-batteries test: ECONOMY — this call runs for every candidate of every
# asset of every build (thousands of invocations); re-deriving the submit/
# poll/fetch dance live each time would be waste. It contains ZERO judgment:
# workflows are composed by the agent, results are judged by the gate cascade.
"""Submit a ComfyUI workflow (API-format JSON), wait, save outputs.

Usage: comfy_client.py <workflow.json> --out-dir <dir> [--host http://127.0.0.1:8188]
       [--timeout 600] [--set node_id.field=value ...]

--set patches workflow inputs before submit (e.g. --set 6.text="a potion"
--set 3.seed=42) so one workflow file serves many jobs. Values parse as JSON
when possible, else string. Prints one JSON line: {"prompt_id", "files", "seconds"}.
"""
import json, sys, time, uuid, pathlib, urllib.request, urllib.parse

def api(host, path, data=None):
    req = urllib.request.Request(host + path,
                                 data=json.dumps(data).encode() if data is not None else None,
                                 headers={"Content-Type": "application/json"} if data is not None else {})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())

def main(argv):
    wf_path = argv[1]
    host = argv[argv.index("--host") + 1] if "--host" in argv else "http://127.0.0.1:8188"
    out_dir = pathlib.Path(argv[argv.index("--out-dir") + 1])
    timeout = int(argv[argv.index("--timeout") + 1]) if "--timeout" in argv else 600
    wf = json.load(open(wf_path))

    for i, a in enumerate(argv):
        if a == "--set":
            key, _, val = argv[i + 1].partition("=")
            node, field = key.split(".", 1)
            try: val = json.loads(val)
            except json.JSONDecodeError: pass
            wf[node]["inputs"][field] = val

    t0 = time.time()
    client_id = uuid.uuid4().hex
    resp = api(host, "/prompt", {"prompt": wf, "client_id": client_id})
    pid = resp["prompt_id"]

    while True:
        if time.time() - t0 > timeout:
            raise SystemExit(f"timeout after {timeout}s (prompt {pid})")
        hist = api(host, f"/history/{pid}")
        if pid in hist:
            entry = hist[pid]
            status = entry.get("status", {})
            if status.get("status_str") == "error":
                msgs = [m for m in status.get("messages", []) if m[0] == "execution_error"]
                raise SystemExit(f"execution error: {json.dumps(msgs)[:2000]}")
            if entry.get("outputs"):
                break
        time.sleep(0.5)

    out_dir.mkdir(parents=True, exist_ok=True)
    saved = []
    for node_id, out in hist[pid]["outputs"].items():
        for img in out.get("images", []) + out.get("audio", []):
            q = urllib.parse.urlencode({"filename": img["filename"],
                                        "subfolder": img.get("subfolder", ""),
                                        "type": img.get("type", "output")})
            with urllib.request.urlopen(f"{host}/view?{q}", timeout=120) as r:
                dest = out_dir / img["filename"]
                dest.write_bytes(r.read())
                saved.append(str(dest))
    print(json.dumps({"prompt_id": pid, "files": saved, "seconds": round(time.time() - t0, 1)}))
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv))
