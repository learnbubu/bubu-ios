"""Audio-to-audio with Stable Audio Open: start from a sound we give it (our own melody), add
some noise, and let the model redraw it toward a prompt. Little noise keeps the input's notes
and timing; more lets the prompt take over.

    INPUTS=out/lantern/correct.wav,out/jade/correct.wav SIGMAS=6,15 .venv/Scripts/python restyle.py
"""
import os

import numpy as np
import soundfile as sf
import torch
from diffusers import StableAudioPipeline

from gen_ai import CLEAN, NEG, tidy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "out", "restyle")
PROMPTS = {
    "chime":   "bright sparkling bell chime, celesta, correct answer, polished mobile game UI sound effect",
    "marimba": "warm wooden marimba, cheerful correct answer, polished mobile game UI sound effect",
    "bouncy":  "bright bouncy synth bell ding, playful correct answer, polished mobile game UI sound effect",
}


def main():
    inputs = os.environ.get("INPUTS", "out/lantern/correct.wav,out/jade/correct.wav").split(",")
    sigmas = [float(s) for s in os.environ.get("SIGMAS", "6,15").split(",")]
    styles = os.environ.get("STYLES", ",".join(PROMPTS)).split(",")
    keep = float(os.environ.get("KEEP", 1.0))
    try:
        import psutil
        psutil.Process().nice(psutil.BELOW_NORMAL_PRIORITY_CLASS)
    except Exception:
        pass
    torch.cuda.set_per_process_memory_fraction(0.9)
    pipe = StableAudioPipeline.from_pretrained("stabilityai/stable-audio-open-1.0", torch_dtype=torch.float16).to("cuda")
    sr = pipe.vae.sampling_rate
    n_lat = pipe.transformer.config.sample_size
    n_audio = int(n_lat * pipe.vae.hop_length)
    sigma_max0 = pipe.scheduler.config.sigma_max
    os.makedirs(OUT, exist_ok=True)
    for path in inputs:
        x, isr = sf.read(os.path.join(HERE, path), always_2d=True)
        assert isr == sr, (path, isr)
        x = np.repeat(x[:, :1], 2, axis=1) if x.shape[1] == 1 else x[:, :2]
        secs = max(1.0, len(x) / sr + 0.3)
        audio = np.zeros((2, n_audio), dtype=np.float32)
        audio[:, : len(x)] = x.T[:, :n_audio]
        with torch.no_grad():
            enc = pipe.vae.encode(torch.from_numpy(audio)[None].to("cuda", torch.float16)).latent_dist.mean
        src = os.path.splitext(os.path.basename(os.path.dirname(path)))[0]
        for style in styles:
            for s in sigmas:
                pipe.scheduler.register_to_config(sigma_max=s)
                g = torch.Generator("cuda").manual_seed(7)
                noise = torch.randn(enc.shape, generator=g, device="cuda", dtype=enc.dtype)
                # the pipeline multiplies what it's given by init_noise_sigma = sqrt(s^2 + 1)
                lat = (enc + noise * s) / (s ** 2 + 1) ** 0.5
                out = pipe(f"{PROMPTS[style]}, {CLEAN}", negative_prompt=NEG, num_inference_steps=100,
                           audio_end_in_s=secs, latents=lat, generator=g).audios[0]
                y = tidy(out.T.float().cpu().numpy(), sr, keep, -2)
                name = f"{src}-{style}-s{int(s)}"
                sf.write(os.path.join(OUT, name + ".wav"), y, sr)
                os.system(f'ffmpeg -y -loglevel error -i "{os.path.join(OUT, name + ".wav")}" -b:a 160k "{os.path.join(OUT, name + ".mp3")}"')
                print(name, flush=True)
    pipe.scheduler.register_to_config(sigma_max=sigma_max0)


if __name__ == "__main__":
    main()
