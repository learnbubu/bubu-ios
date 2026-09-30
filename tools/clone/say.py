"""Says lines in a sampled voice with CosyVoice 3, run from its own environment:

    C:/Users/domch/bubu-voice/venv/Scripts/python tools/clone/say.py prompt.wav "what the prompt says" out_dir lines.txt [rl]

prompt.wav is 5 to 15 seconds of the voice to copy, and the second argument is exactly what is
said in it. Each line of lines.txt becomes out_dir/NN.wav. "rl" uses the model tuned for fewer
pronunciation mistakes (llm.rl.pt) in place of llm.pt. SPEED=0.85 says it slower; MODE=cross
takes the voice from a sample in another language (no transcript needed).
"""
import os, sys, time

HOME = os.environ.get("COSYVOICE_HOME", r"C:\Users\domch\bubu-voice\CosyVoice")
sys.path[:0] = [HOME, os.path.join(HOME, "third_party", "Matcha-TTS")]

import torch, torchaudio
from cosyvoice.cli.cosyvoice import AutoModel

MODEL = os.path.join(HOME, "pretrained_models", "Fun-CosyVoice3-0.5B")
# Left to itself the model pauses anywhere from a fifth of a second to nearly two between
# sentences, so a line of several is said a sentence at a time and joined with a steady pause.
PAUSE = 0.45
ENDS = "。！？!?"


def sentences(line):
    out, cur = [], ""
    for ch in line:
        cur += ch
        if ch in ENDS:
            out.append(cur); cur = ""
    if cur.strip():
        out.append(cur)
    return [s for s in out if s.strip()]


def trimmed(wav, sr, floor=0.06, least=0.06):
    """The clip without its silence before and after (a few ms kept either side). A breath or
    click in the silence (quiet, or shorter than `least` seconds) doesn't count as speech."""
    hop = sr // 100
    x = wav.squeeze(0)
    n = len(x) // hop
    rms = x[:n * hop].reshape(n, hop).pow(2).mean(dim=1).sqrt()
    on = (rms > floor * rms.max()).tolist()
    runs, i = [], 0
    while i < n:
        if on[i]:
            j = i
            while j < n and on[j]:
                j += 1
            if j - i >= least * 100:
                runs.append((i, j))
            i = j
        else:
            i += 1
    if not runs:
        return wav
    a = max(0, runs[0][0] * hop - int(0.03 * sr))
    b = min(wav.shape[1], runs[-1][1] * hop + int(0.08 * sr))
    return wav[:, a:b]

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
        sr = model.sample_rate
        pieces = []
        for s in sentences(line):
            if os.environ.get("MODE") == "instruct":
                # the voice from the sample, and how to say it from INSTRUCT (in Chinese, e.g.
                # 请说得清楚一点，慢一点。)
                said = torch.cat([j["tts_speech"] for j in model.inference_instruct2(
                    s, "You are a helpful assistant. " + os.environ.get("INSTRUCT", "") + "<|endofprompt|>", prompt,
                    stream=False, speed=float(os.environ.get("SPEED", "1")))], dim=1)
            elif os.environ.get("MODE") == "cross":
                # the prompt is in another language (an English sample speaking Mandarin): no
                # transcript, the voice only
                said = torch.cat([j["tts_speech"] for j in model.inference_cross_lingual(
                    "You are a helpful assistant.<|endofprompt|>" + s, prompt, stream=False,
                    speed=float(os.environ.get("SPEED", "1")))], dim=1)
            else:
                said = torch.cat([j["tts_speech"] for j in model.inference_zero_shot(
                    s, "You are a helpful assistant.<|endofprompt|>" + prompt_text, prompt, stream=False,
                    speed=float(os.environ.get("SPEED", "1")))], dim=1)
            if pieces:
                pieces.append(torch.zeros(1, int(PAUSE * sr)))
            pieces.append(trimmed(said, sr) if len(sentences(line)) > 1 else said)
        torchaudio.save(os.path.join(out, f"{n:02d}.wav"), torch.cat(pieces, dim=1), sr)
        print(f"{n:02d} {line} ({time.time() - t:.1f}s)", flush=True)
