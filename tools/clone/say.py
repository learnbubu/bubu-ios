"""Says lines in a sampled voice with CosyVoice 3, run from its own environment:

    C:/Users/domch/bubu-voice/venv/Scripts/python tools/clone/say.py prompt.wav "what the prompt says" out_dir lines.txt [rl]

prompt.wav is 5 to 15 seconds of the voice to copy, and the second argument is exactly what is
said in it. Each line of lines.txt becomes out_dir/NN.wav. "rl" uses the model tuned for fewer
pronunciation mistakes (llm.rl.pt) in place of llm.pt.
"""
import os, sys, time

HOME = os.environ.get("COSYVOICE_HOME", r"C:\Users\domch\bubu-voice\CosyVoice")
sys.path[:0] = [HOME, os.path.join(HOME, "third_party", "Matcha-TTS")]

import torch, torchaudio
from cosyvoice.cli.cosyvoice import AutoModel

MODEL = os.path.join(HOME, "pretrained_models", "Fun-CosyVoice3-0.5B")

if __name__ == "__main__":
    prompt, prompt_text, out, lines = sys.argv[1:5]
    rl = len(sys.argv) > 5 and sys.argv[5] == "rl"
    os.makedirs(out, exist_ok=True)
    model = AutoModel(model_dir=MODEL)
    if rl:
        model.model.llm.load_state_dict(torch.load(os.path.join(MODEL, "llm.rl.pt"), map_location=model.model.device), strict=True)
    text = [l.strip() for l in open(lines, encoding="utf-8") if l.strip()]
    for n, line in enumerate(text, 1):
        t = time.time()
        parts = [j["tts_speech"] for j in model.inference_zero_shot(
            line, "You are a helpful assistant.<|endofprompt|>" + prompt_text, prompt, stream=False)]
        torchaudio.save(os.path.join(out, f"{n:02d}.wav"), torch.cat(parts, dim=1), model.sample_rate)
        print(f"{n:02d} {line} ({time.time() - t:.1f}s)", flush=True)
