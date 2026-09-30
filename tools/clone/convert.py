"""Voice conversion with CosyVoice 3: each clip in a folder said again in a sampled voice,
keeping its timing and tones (the source's pronunciation, the sample's voice). Run from its own
environment:

    C:/Users/domch/bubu-voice/venv/Scripts/python tools/clone/convert.py sample.wav source_dir out_dir
"""
import os, sys, glob

HOME = os.environ.get("COSYVOICE_HOME", r"C:\Users\domch\bubu-voice\CosyVoice")
sys.path[:0] = [HOME, os.path.join(HOME, "third_party", "Matcha-TTS")]

import torch, torchaudio
from cosyvoice.cli.cosyvoice import AutoModel

MODEL = os.path.join(HOME, "pretrained_models", "Fun-CosyVoice3-0.5B")

if __name__ == "__main__":
    sample, src, out = sys.argv[1:4]
    os.makedirs(out, exist_ok=True)
    model = AutoModel(model_dir=MODEL)
    for f in sorted(glob.glob(os.path.join(src, "*.wav"))):
        parts = [j["tts_speech"] for j in model.inference_vc(f, sample, stream=False)]
        torchaudio.save(os.path.join(out, os.path.basename(f)), torch.cat(parts, dim=1), model.sample_rate)
        print(os.path.basename(f), flush=True)
