"""Levels the rendered set (render/*.wav) for the app: loudness matched by role, peaks kept
under -1 dBFS, the silent tail trimmed with a short fade; 16-bit 44.1 kHz stereo WAV in final/."""
import glob, os, sys
import numpy as np, soundfile as sf, pyloudnorm as pyln

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "final"); os.makedirs(OUT, exist_ok=True)
SR = 44100
meter = pyln.Meter(SR)
# loudness by role: the every-answer sounds a little quieter than the celebrations; tap quietest
TARGET = {"tap": -26, "correct": -15.5, "wrong": -16.5, "combo": -15, "goal": -14, "complete": -14.5,
          "levelup": -14.5, "milestone": -14, "chest": -15.5, "relight": -16.5}

def lufs(x):
    pad = np.zeros((int(0.5 * SR), x.shape[1]))
    return meter.integrated_loudness(np.vstack([x, pad]))   # short sounds need >= 0.4 s

if __name__ == "__main__":
    if sys.argv[1:] == ["measure"]:
        for p in sorted(glob.glob(os.path.join(HERE, "..", "..", "native", "Bubu", "Resources", "Sounds", "*"))):
            x, sr = sf.read(p, always_2d=True)
            if sr != SR:
                import scipy.signal as ss; x = ss.resample_poly(x, SR, sr, axis=0)
            if x.shape[1] == 1: x = np.repeat(x, 2, axis=1)
            print(f"old {os.path.basename(p):16s} {lufs(x):6.1f} LUFS  peak {20*np.log10(np.abs(x).max()):5.1f} dB  {len(x)/SR:.2f}s")
        sys.exit()
    for p in sorted(glob.glob(os.path.join(HERE, "render", "*.wav"))):
        name = os.path.splitext(os.path.basename(p))[0]
        x, sr = sf.read(p, always_2d=True); assert sr == SR
        g = 10 ** ((TARGET[name] - lufs(x)) / 20)
        x = x * g
        pk = np.abs(x).max()
        if pk > 10 ** (-1 / 20): x *= 10 ** (-1 / 20) / pk          # never over -1 dBFS
        a = np.abs(x).max(axis=1)
        end = np.nonzero(a > a.max() * 10 ** (-60 / 20))[0][-1] + 1
        x = x[:end]
        f = min(len(x) // 4, int(0.06 * SR)); x[-f:] *= np.linspace(1, 0, f)[:, None] ** 2
        sf.write(os.path.join(OUT, name + ".wav"), x, SR, subtype="PCM_16")
        print(f"new {name:10s} {lufs(x):6.1f} LUFS  peak {20*np.log10(np.abs(x).max()):5.1f} dB  {len(x)/SR:.2f}s  {os.path.getsize(os.path.join(OUT, name + '.wav'))//1024} KB")
