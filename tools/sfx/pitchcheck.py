import json, os, numpy as np, soundfile as sf
K = "kit"
man = json.load(open(f"{K}/manifest.json"))
def f0(x, sr=44100):
    x = x[int(0.01*sr):int(0.35*sr)]
    x = x * np.hanning(len(x))
    n = 1 << 17
    sp = np.abs(np.fft.rfft(x, n))
    fr = np.fft.rfftfreq(n, 1/sr)
    hps = sp.copy()
    for h in (2, 3):
        d = sp[::h]; hps[:len(d)] *= d
    lo, hi = np.searchsorted(fr, 60), np.searchsorted(fr, 5000)
    peak = fr[lo + np.argmax(sp[lo:hi])]          # strongest partial
    hpk = fr[lo + np.argmax(hps[lo:hi // 3])]     # harmonic estimate
    return peak, hpk
for inst, v in man.items():
    if v["kind"] != "pitched": continue
    out = []
    for m in v["notes"]:
        x, sr = sf.read(f"{K}/wav/{inst}/{m}.wav")
        p, h = f0(x)
        mp = 69 + 12*np.log2(p/440)
        out.append(f"{m}:{mp:.1f}")
    print(inst, " ".join(out))

# --- fix the manifest: real pitch = name + the instrument's octave offset; drop samples whose
# measured pitch doesn't match; keep each one's tuning error (cents) so playback corrects it
fixed = {}
for inst, v in man.items():
    if v["kind"] != "pitched":
        fixed[inst] = v; continue
    meas = {}
    for m in v["notes"]:
        x, sr = sf.read(f"{K}/wav/{inst}/{m}.wav")
        p, h = f0(x)
        meas[m] = 69 + 12*np.log2(p/440)
    diffs = [round((meas[m]-m)/12)*12 for m in meas]
    off = int(np.median(diffs))
    entries = []
    for m, d in meas.items():
        err = d - (m + off)
        if abs(err) <= 0.6:
            entries.append({"midi": m + off, "key": m, "cents": round(err*100)})
    fixed[inst] = {"kind": "pitched", "entries": sorted(entries, key=lambda e: e["midi"])}
    print(inst, "offset", off, "kept", len(entries), "of", len(meas), "range", entries[0]["midi"] if entries else None, "-", entries[-1]["midi"] if entries else None)
json.dump(fixed, open(f"{K}/manifest.json", "w"), indent=1)
