"""Bùbù's sound effects from Stable Audio Open 1.0 (Stability AI Community Licence), on the GPU.

Every prompt shares one style line, so the set sounds like one family. Each sound gets TAKES
takes; each is trimmed, faded and levelled, then saved as out/ai/<sound>/<n>.wav and .mp3.

    .venv/Scripts/python gen_ai.py            (all sounds)
    ONLY=correct,wrong .venv/Scripts/python gen_ai.py
"""
import os
import subprocess
import time

import numpy as np
import soundfile as sf
import torch
from diffusers import StableAudioPipeline

OUT = os.path.join(os.path.dirname(__file__), "out", "ai")
TAKES = int(os.environ.get("TAKES", 6))
# the house styles being tried (STYLES=marimba,guzheng ...); each goes to out/ai/<style>/<sound>/
STYLE_LINES = {
    "marimba": "polished mobile game UI sound effect, bright marimba and soft glockenspiel",
    "guzheng": "polished mobile game UI sound effect, plucked guzheng and a small bright bell, Chinese pentatonic",
    "bubbly":  "polished mobile game UI sound effect, soft bubbly synth pops, playful and cartoonish",
    "chime":   "polished mobile game UI sound effect, sparkling bell chime and celesta, bright and premium",
}
CLEAN = "clean, crisp, high quality, studio recording, no background noise"
NEG = "low quality, noise, hiss, distortion, speech, vocals, muddy, long reverb"

# name: (prompt, seconds generated, longest kept, peak dBFS)
SOUNDS = {
    "tap":       ("very short soft wooden click, button tap", 1.0, 0.15, -6),
    "correct":   ("short cheerful two-note rising chime, correct answer ding", 1.5, 0.9, -2),
    "wrong":     ("short soft gentle low two-note falling tone, wrong answer, friendly not harsh", 1.5, 0.9, -4),
    "combo":     ("quick rising three-note sparkle arpeggio, streak bonus", 1.5, 1.0, -2),
    "goal":      ("short bright ascending arpeggio, goal reached", 2.0, 1.6, -2),
    "complete":  ("short triumphant happy jingle, lesson complete fanfare", 3.0, 2.6, -1),
    "levelup":   ("magical level up, rising arpeggio ending in a shimmering sparkle", 3.0, 2.6, -1),
    "milestone": ("grand achievement unlocked fanfare with a soft gong and bells", 4.0, 3.6, -1),
    "chest":     ("treasure chest opening with coins and a sparkling magical shimmer", 3.0, 2.6, -1),
    "relight":   ("small fire ignites with a soft whoosh, then a warm gentle chime", 2.5, 2.2, -2),
}


def tidy(x, sr, keep, peak_db):
    """Stereo (n, 2) float: trim silence at both ends, cap the length, fade, set the peak."""
    mono = np.abs(x).max(axis=1)
    thr = mono.max() * 10 ** (-45 / 20)
    on = np.nonzero(mono > thr)[0]
    if len(on) == 0:
        return x
    a = max(0, on[0] - int(0.003 * sr))
    b = min(len(x), on[-1] + 1, a + int(keep * sr))
    x = x[a:b].copy()
    fi, fo = int(0.002 * sr), min(len(x) // 3, int(0.04 * sr))
    x[:fi] *= np.linspace(0, 1, fi)[:, None]
    x[-fo:] *= np.linspace(1, 0, fo)[:, None]
    return x / np.abs(x).max() * 10 ** (peak_db / 20)


def main():
    only = [s for s in os.environ.get("ONLY", "").split(",") if s]
    # gentle on a PC someone's gaming on: low priority, the model kept mostly in RAM (a small
    # share of the graphics memory), one take at a time with a rest between (GENTLE=0 for full speed)
    gentle = os.environ.get("GENTLE", "1") == "1"
    pipe = StableAudioPipeline.from_pretrained("stabilityai/stable-audio-open-1.0", torch_dtype=torch.float16)
    if gentle:
        try:
            import psutil
            psutil.Process().nice(psutil.IDLE_PRIORITY_CLASS)
        except Exception:
            pass
        torch.cuda.set_per_process_memory_fraction(0.35)
        pipe.enable_model_cpu_offload()
    else:
        # fast, but the PC still usable: below-normal priority and 90% of the graphics memory
        try:
            import psutil
            psutil.Process().nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
        except Exception:
            pass
        torch.cuda.set_per_process_memory_fraction(0.9)
        pipe = pipe.to("cuda")
    sr = pipe.vae.sampling_rate
    styles = [x for x in os.environ.get("STYLES", "marimba").split(",") if x]
    for style, (name, (prompt, secs, keep, peak)) in [(st, kv) for st in styles for kv in SOUNDS.items()]:
        if only and name not in only:
            continue
        STYLE = f"{STYLE_LINES[style]}, {CLEAN}"
        d = os.path.join(OUT, style, name)
        os.makedirs(d, exist_ok=True)
        audio = []
        for t in range(TAKES if gentle else 1):
            g = torch.Generator("cuda").manual_seed(1000 + len(name) * 31 + t)
            audio += list(pipe(f"{prompt}, {STYLE}", negative_prompt=NEG, num_inference_steps=100,
                               audio_end_in_s=secs, num_waveforms_per_prompt=1 if gentle else TAKES,
                               generator=g).audios)
            if gentle:
                time.sleep(4)
        for i, a in enumerate(audio):
            x = tidy(a.T.float().cpu().numpy(), sr, keep, peak)
            p = os.path.join(d, f"{i + 1}.wav")
            sf.write(p, x, sr)
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", p, "-b:a", "160k", p[:-4] + ".mp3"], check=True)
        print(style, name, "done", flush=True)


if __name__ == "__main__":
    main()
