#!/usr/bin/env python3
# Thin-batteries test: DETERMINISM — Tier-1 audio gates must verdict
# bit-identically across sessions. Promoted from the ephemeral gate math
# validated in the M1 music smoke test (2026-07-12).
# Requires torchaudio — run under the appliance venv:
#   appliances/comfyui/ComfyUI/venv/bin/python gate_tier1_audio.py …
"""Usage: gate_tier1_audio.py <audio> --class <bgm|stinger|sfx> [--duration <target_s>] [--report <path>]"""
import json, sys, pathlib
import torch, torchaudio

THRESHOLDS = {
    "bgm":     {"dur_tol": 0.10, "rms": (0.02, 0.5), "edge_rms_min": 0.005,
                "centroid": (200, 4000)},
    "stinger": {"dur_tol": 0.25, "rms": (0.02, 0.6), "edge_rms_min": 0.0,
                "centroid": (150, 6000)},
    "sfx":     {"dur_tol": 0.50, "rms": (0.01, 0.8), "edge_rms_min": 0.0,
                "centroid": (100, 12000)},
}

def run(path, klass, target_s=None):
    t = THRESHOLDS[klass]
    wav, sr = torchaudio.load(path)
    dur = wav.shape[1] / sr
    rms = wav.pow(2).mean().sqrt().item()
    peak = wav.abs().max().item()
    head = wav[:, :2 * sr].pow(2).mean().sqrt().item() if dur > 4 else rms
    tail = wav[:, -2 * sr:].pow(2).mean().sqrt().item() if dur > 4 else rms
    win = torch.hann_window(2048)
    spec = torch.stft(wav[0], n_fft=2048, window=win, return_complex=True).abs().mean(dim=1)
    freqs = torch.linspace(0, sr / 2, spec.shape[0])
    centroid = float((spec * freqs).sum() / spec.sum())
    gates = {
        "rms in %s" % str(t["rms"]): t["rms"][0] <= rms <= t["rms"][1],
        "no clipping (peak < 1.0)": peak < 1.0,
        "spectral centroid %s Hz" % str(t["centroid"]): t["centroid"][0] <= centroid <= t["centroid"][1],
    }
    if target_s:
        lo, hi = target_s * (1 - t["dur_tol"]), target_s * (1 + t["dur_tol"])
        gates[f"duration {round(lo,1)}-{round(hi,1)}s"] = lo <= dur <= hi
    if t["edge_rms_min"] > 0:
        gates["head not silent"] = head > t["edge_rms_min"]
        gates["tail not silent"] = tail > t["edge_rms_min"]
    return {"gate": "tier1_audio", "file": str(path), "class": klass,
            "gates": {k: bool(v) for k, v in gates.items()},
            "measured": {"duration_s": round(dur, 1), "sr": sr, "channels": wav.shape[0],
                         "rms": round(rms, 4), "peak": round(peak, 3),
                         "centroid_hz": round(centroid)},
            "status": "green" if all(gates.values()) else "red"}

if __name__ == "__main__":
    argv = sys.argv
    klass = argv[argv.index("--class") + 1]
    target = float(argv[argv.index("--duration") + 1]) if "--duration" in argv else None
    result = run(argv[1], klass, target)
    if "--report" in argv:
        rp = pathlib.Path(argv[argv.index("--report") + 1])
        rp.parent.mkdir(parents=True, exist_ok=True)
        rp.write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=1))
    sys.exit(0 if result["status"] == "green" else 1)
