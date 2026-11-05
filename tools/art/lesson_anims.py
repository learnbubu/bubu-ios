"""The lesson mascot's animations, keyed on the turnaround rig's front view (the owner, 5 Nov 2026: the new Bùbù in the lessons,
"Claude first, you fix"): Idle, Right (an answer got right), Wrong, Wave (his own front wave, as it was) and Cheer.

Each animation is poses at times: offsets from rest for the hips (a move: the whole body, the feet staying put unless the pose
says), the chest's and head's turn, the head's drop, each ear's turn, the face's look, and where each hand and foot goes
(document units from where it rests). Studio keeps them as the document's animations (each with its own hand and foot keys).

Makes, from Studio's Puppet Views (never changed):
- <out>/bubu-lesson.json: a document with all five, the front shown, Idle being edited
- <out>/bubu-lesson-<name>.json: one document an animation, to render as a video
From tools/art: ../sfx/.venv/Scripts/python -I lesson_anims.py <docs folder in> <docs folder out>
"""
import copy
import json
import os
import sys

src_dir, out_dir = sys.argv[1], sys.argv[2]
base = json.load(open(os.path.join(src_dir, "puppet-views.json"), encoding="utf-8"))

SMOOTH, OUT, HOLD = [0.42, 0, 0.58, 1], [0.16, 1, 0.3, 1], [1, 0, 1, 0]
IN = [0.55, 0, 0.9, 0.45]                              # (speeding up: a fall)
ROOM = 450                                             # (the previews' extra height above him, for the jumps)
HANDS = {"R": "Bizhnq98", "L": "bForearmL2"}           # (the front's: screen right, screen left)
FEET = {"R": "bShinR2", "L": "bShinL2"}

L0 = {l["id"]: l for l in base["layers"]}
B0 = {b["id"]: b for b in base["bones"]}
REST = {"hips": (L0["hips"]["x"], L0["hips"]["y"]), "torso": L0["torso"]["rotation"], "head": (L0["head"]["y"], L0["head"]["rotation"]),
        "earL": L0["earL"]["rotation"], "earR": L0["earR"]["rotation"], "face": (L0["face"]["x"], L0["face"]["y"])}
HAND0 = {k: (B0[b]["ik"]["tx"], B0[b]["ik"]["ty"]) for k, b in HANDS.items()}
FOOT0 = {k: (B0[b]["ik"]["tx"], B0[b]["ik"]["ty"]) for k, b in FEET.items()}


def pose(**k):
    """a pose: hips (dx, dy), torso (deg), head (dy, deg), earL / earR (deg), face (dx, dy), hR / hL (dx, dy), fR / fL (dx, dy)"""
    return k


def keys_of(timeline):
    """[(t, pose, ease)] -> the keys for every channel, rest wherever a pose doesn't say"""
    ch = {}
    for t, p, e in timeline:
        g = lambda k, d: p.get(k, d)
        hx, hy = g("hips", (0, 0)); ch.setdefault(("hips", "x"), []).append((t, REST["hips"][0] + hx, e)); ch.setdefault(("hips", "y"), []).append((t, REST["hips"][1] + hy, e))
        ch.setdefault(("torso", "rotation"), []).append((t, REST["torso"] + g("torso", 0), e))
        dy, rot = g("head", (0, 0)); ch.setdefault(("head", "y"), []).append((t, REST["head"][0] + dy, e)); ch.setdefault(("head", "rotation"), []).append((t, REST["head"][1] + rot, e))
        for ear in ("earL", "earR"):
            ch.setdefault((ear, "rotation"), []).append((t, REST[ear] + g(ear, 0), e))
        fx, fy = g("face", (0, 0)); ch.setdefault(("face", "x"), []).append((t, REST["face"][0] + fx, e)); ch.setdefault(("face", "y"), []).append((t, REST["face"][1] + fy, e))
        for s in ("R", "L"):
            dx, dy2 = g("h" + s, (0, 0)); ch.setdefault((HANDS[s], "tx"), []).append((t, HAND0[s][0] + dx, e)); ch.setdefault((HANDS[s], "ty"), []).append((t, HAND0[s][1] + dy2, e))
            dx, dy2 = g("f" + s, (0, 0)); ch.setdefault((FEET[s], "tx"), []).append((t, FOOT0[s][0] + dx, e)); ch.setdefault((FEET[s], "ty"), []).append((t, FOOT0[s][1] + dy2, e))
    return ch


def sparse_keys(timeline):
    """[(t, {channel: value}, ease)] -> keys only where a pose names a channel (so each part keeps its own timing: the ears
    trailing the head, one hand behind the other); a channel's value is its offset from rest. 'rest' keys every channel at rest"""
    ch, rest = {}, {("hips", "x"): REST["hips"][0], ("hips", "y"): REST["hips"][1], ("torso", "rotation"): REST["torso"],
                    ("torso", "sx"): 1, ("torso", "sy"): 1, ("head", "y"): REST["head"][0], ("head", "rotation"): REST["head"][1],
                    ("head", "sx"): 1, ("head", "sy"): 1, ("earL", "rotation"): REST["earL"], ("earR", "rotation"): REST["earR"],
                    ("face", "x"): REST["face"][0], ("face", "y"): REST["face"][1]}
    for s_ in ("R", "L"):
        rest[(HANDS[s_], "tx")], rest[(HANDS[s_], "ty")] = HAND0[s_]
        rest[(FEET[s_], "tx")], rest[(FEET[s_], "ty")] = FOOT0[s_]
    short = {"hx": ("hips", "x"), "hy": ("hips", "y"), "tilt": ("torso", "rotation"), "tsx": ("torso", "sx"), "tsy": ("torso", "sy"),
             "head": ("head", "y"), "hrot": ("head", "rotation"), "hsx": ("head", "sx"), "hsy": ("head", "sy"),
             "earL": ("earL", "rotation"), "earR": ("earR", "rotation"), "fx": ("face", "x"), "fy": ("face", "y")}
    for s_ in ("R", "L"):
        short["h" + s_ + "x"], short["h" + s_ + "y"] = (HANDS[s_], "tx"), (HANDS[s_], "ty")
        short["f" + s_ + "x"], short["f" + s_ + "y"] = (FEET[s_], "tx"), (FEET[s_], "ty")
    scale = {("torso", "sx"), ("torso", "sy"), ("head", "sx"), ("head", "sy")}
    for t, p, e in timeline:
        if p.get("rest"):
            for c, v in rest.items():
                ch.setdefault(c, []).append((t, v, e))
            continue
        for k, v in p.items():
            c = short[k]
            ch.setdefault(c, []).append((t, v if c in scale else rest[c] + v, e))
    return ch


REST_ALL = {"rest": True}
R0 = pose()
# Idle, round and round: breathing (the body rises and settles), a slow sway of the chest and head the other way, the face drifting,
# an ear flicking, the hands swaying with the body a beat behind
IDLE = [(0, R0, SMOOTH),
        (800, pose(hips=(0, -3), torso=1.2, head=(-2, -1.5), face=(4, -1), hR=(2, -3), hL=(2, -2)), SMOOTH),
        (1600, pose(hips=(0, 0), torso=0, head=(0, 0), face=(6, 0), hR=(0, 0), hL=(0, 0)), SMOOTH),
        (2000, pose(face=(6, 0), earR=-9), OUT),
        (2150, pose(face=(5, 0), earR=3), SMOOTH),
        (2400, pose(hips=(0, -3), torso=-1.2, head=(-2, 1.5), face=(0, -1), hR=(-2, -2), hL=(-2, -3)), SMOOTH),
        (3200, R0, SMOOTH)]
# Right, after Duolingo's Junior (his correct-answer jump, timed off the GIF): a big squash (the head sinking into the body),
# a stretched launch tilting, a long hang in the air that keeps moving (the hands out of step, the body rocking), a fast fall,
# a hard tilted squash on landing, a rebound and still. The ears and hands trail the body by a few frames.
# (the body: the owner, 5 Nov 2026: "body works")
BODY = [(0, REST_ALL, SMOOTH),
        (60, dict(hy=0, tsy=1, tsx=1, head=0), OUT),
        (230, dict(hy=34, tsx=1.13, tsy=0.84, head=22, hsx=1.05, hsy=0.94, fy=6), SMOOTH),
        (280, dict(earL=10, earR=-10), OUT),
        (330, dict(hy=-170, tsx=0.9, tsy=1.12, head=-14, hsx=0.97, hsy=1.04, tilt=6, fy=-8), OUT),
        (380, dict(earL=-14, earR=10), OUT),
        (440, dict(hy=-290, tsx=0.98, tsy=1.03, head=-8, hsx=1, hsy=1, hrot=-3), SMOOTH),
        (480, dict(earL=-6, earR=16), SMOOTH),
        (680, dict(tilt=-5, hrot=4, earL=-14, earR=6), SMOOTH),
        (800, dict(hy=-275), SMOOTH),
        (860, dict(tilt=5, hrot=-3, earL=-4, earR=14), SMOOTH),
        (1000, dict(hy=-255, tilt=3, tsx=1, tsy=1, head=-6, fy=-8), IN),
        (1140, dict(hy=0, tsx=0.95, tsy=1.07, head=-12, tilt=0), OUT),
        (1200, dict(hy=40, tsx=1.12, tsy=0.86, head=20, hsx=1.04, hsy=0.95, tilt=-4, hrot=4, fy=4), OUT),
        (1240, dict(earL=14, earR=-12), OUT),
        (1320, dict(hy=-6, tsx=0.98, tsy=1.03, head=-4, hsx=1, hsy=1, tilt=1, hrot=-1, fy=0), SMOOTH),
        (1400, dict(earL=-5, earR=4), SMOOTH),
        (1460, REST_ALL, SMOOTH),
        (1560, dict(earL=0, earR=0), SMOOTH),
        (1700, REST_ALL, SMOOTH)]
# (the arms and legs, after a teddy bear's jump on Tenor ("bear jump", a chunky bear much like him, read frame by frame, as
# v4's were "not at all" right): at take-off the arms straight down along the body and the legs straight together; rising,
# the arms swing out wide and on up into a V while the legs tuck right up into a frog-sit (feet up by the hips, knees out);
# held so in the air; falling, the legs reach down for the ground; landing in a wide squat, the arms out flat, then down)
ARMS = [(60, dict(hRx=0, hRy=0, hLx=0, hLy=0), SMOOTH),
        (230, dict(hRx=30, hRy=20, hLx=-30, hLy=20), OUT),
        (300, dict(hRx=-10, hRy=14, hLx=10, hLy=14), OUT),
        (340, dict(hRx=-15, hRy=30, hLx=15, hLy=30), OUT),
        (400, dict(hRx=170, hRy=-90, hLx=-170, hLy=-80), SMOOTH),
        (470, dict(hRx=110, hRy=-270, hLx=-100, hLy=-260), OUT),
        (620, dict(hRx=120, hRy=-250, hLx=-110, hLy=-280), SMOOTH),
        (800, dict(hRx=100, hRy=-280, hLx=-120, hLy=-250), SMOOTH),
        (960, dict(hRx=115, hRy=-265, hLx=-105, hLy=-270), SMOOTH),
        (1060, dict(hRx=100, hRy=-300, hLx=-100, hLy=-300), IN),
        (1140, dict(hRx=170, hRy=-140, hLx=-170, hLy=-130), OUT),
        (1200, dict(hRx=180, hRy=-110, hLx=-180, hLy=-100), OUT),
        (1320, dict(hRx=40, hRy=20, hLx=-36, hLy=24), SMOOTH),
        (1420, dict(hRx=0, hRy=-4, hLx=0, hLy=0), SMOOTH)]
LEGS = [(230, dict(fRx=0, fRy=0, fLx=0, fLy=0), SMOOTH),
        (300, dict(fRx=0, fRy=0, fLx=0, fLy=0), OUT),
        (340, dict(fRx=-8, fRy=-60, fLx=8, fLy=-60), OUT),
        (400, dict(fRx=40, fRy=-330, fLx=-40, fLy=-320), SMOOTH),
        (470, dict(fRx=70, fRy=-440, fLx=-70, fLy=-440), OUT),
        (700, dict(fRx=65, fRy=-430, fLx=-72, fLy=-445), SMOOTH),
        (900, dict(fRx=72, fRy=-440, fLx=-65, fLy=-430), SMOOTH),
        (1040, dict(fRx=30, fRy=-170, fLx=-30, fLy=-170), IN),
        (1140, dict(fRx=35, fRy=0, fLx=-35, fLy=0), OUT)]
RIGHT2 = sorted(BODY + ARMS + LEGS, key=lambda k: k[0])
# Right: a little crouch, a hop with both hands up and out, the head back, the ears flicking; landing with a squash, then rest
RIGHT = [(0, R0, SMOOTH),
         (140, pose(hips=(0, 14), head=(4, 0), hR=(6, 6), hL=(-6, 6)), OUT),
         (360, pose(hips=(0, -46), fR=(0, -32), fL=(0, -32), torso=0, head=(-4, -5), earL=-12, earR=12, face=(0, -8),
                    hR=(40, -300), hL=(-40, -300)), SMOOTH),
         (560, pose(hips=(0, 10), head=(3, -3), earL=6, earR=-6, face=(0, -6), hR=(45, -290), hL=(-45, -290)), OUT),
         (760, pose(hips=(0, -2), head=(0, -2), face=(0, -4), hR=(35, -260), hL=(-35, -260)), SMOOTH),
         (1300, R0, SMOOTH)]
# Wrong: the head drops and turns away a little, the body slumps, the ears droop, the hands come in, the face looks down; held, then
# back up
WRONG = [(0, R0, SMOOTH),
         (320, pose(hips=(0, 14), torso=-3, head=(24, 11), earL=20, earR=-20, face=(-12, 22), hR=(-70, 30), hL=(70, 30)), OUT),
         (1050, pose(hips=(0, 12), torso=-3, head=(22, 10), earL=18, earR=-18, face=(-10, 20), hR=(-65, 28), hL=(65, 28)), SMOOTH),
         (1500, R0, SMOOTH)]
# Cheer: a deeper crouch, a big jump, both arms straight up, the head back; a squash on landing, then rest
CHEER = [(0, R0, SMOOTH),
         (180, pose(hips=(0, 24), head=(6, 0), hR=(10, 10), hL=(-10, 10), earL=4, earR=-4), OUT),
         (430, pose(hips=(0, -60), fR=(0, -46), fL=(0, -46), head=(-6, 0), earL=-16, earR=16, face=(0, -10), hR=(20, -380), hL=(-20, -380)), SMOOTH),
         (620, pose(hips=(0, -45), fR=(0, -32), fL=(0, -32), head=(-4, 3), earL=-10, earR=10, face=(0, -10), hR=(30, -360), hL=(-30, -360)), SMOOTH),
         (820, pose(hips=(0, 18), head=(5, 0), earL=8, earR=-8, face=(0, -4), hR=(40, -230), hL=(-40, -230)), OUT),
         (1050, pose(hips=(0, -3), face=(0, -2), hR=(15, -70), hL=(-15, -70)), SMOOTH),
         (1600, R0, SMOOTH)]


def at(ks, t):
    """a channel's keys [(t, v, ease)] at t: each key's curve (a cubic bezier, as CSS's) to the next"""
    if t <= ks[0][0]:
        return ks[0][1]
    for (t0, v0, e), (t1, v1, _) in zip(ks, ks[1:]):
        if t <= t1:
            u, (x1, y1, x2, y2) = (t - t0) / (t1 - t0) if t1 > t0 else 1, e
            bz = lambda a, b, s_: 3 * a * s_ * (1 - s_) ** 2 + 3 * b * s_ * s_ * (1 - s_) + s_ ** 3
            lo, hi = 0.0, 1.0
            for _ in range(30):
                m = (lo + hi) / 2
                lo, hi = (m, hi) if bz(x1, x2, m) < u else (lo, m)
            return v0 + (v1 - v0) * bz(y1, y2, (lo + hi) / 2)
    return ks[-1][1]


def spring(xs, hz, damp, dt):
    """xs followed by a spring (hz, damping ratio): what a loose part does carried by xs (it lags, overshoots, settles)"""
    w, x, v, out = 2 * 3.14159 * hz, xs[0], 0.0, []
    for target in xs:
        for _ in range(4):
            a = w * w * (target - x) - 2 * damp * w * v
            v += a * dt / 4
            x += v * dt / 4
        out.append(x)
    return out


LINEAR = [0, 0, 1, 1]


def loosen(ch, duration, fps=30):
    """the follow-through (the owner, 5 Nov 2026: "feels stiff still"): what hangs off the body lags behind it and overshoots,
    as springs carried by the body's motion: the head (dropping into the body on take-off, bobbing on landing, turning after
    the body's tilt), each ear (flopping the other way to the head's motion), each hand (dragging behind, the two at different
    rates). Baked a key a frame on those channels."""
    dt, n = 1 / fps, int(duration * fps / 1000) + 1
    ts = [min(duration, i * 1000 / fps) for i in range(n)]
    get = lambda c: [at(ch[c], t) for t in ts]
    hy = get(("hips", "y"))
    head, hrot, tilt = get(("head", "y")), get(("head", "rotation")), get(("torso", "rotation"))
    lag = lambda xs, hz, damp: [s_ - x for s_, x in zip(spring(xs, hz, damp, dt), xs)]
    body = lag(hy, 3.2, 0.32)                          # (+: the body has gone up and the loose part is still below)
    head2 = [h + 0.3 * b for h, b in zip(head, body)]
    hrot2 = [r + 0.8 * l for r, l in zip(hrot, lag(tilt, 2.6, 0.3))]
    world = [y + h for y, h in zip(hy, head2)]
    # (the body's own wobble: its squash still going a moment after the jump's and the landing's)
    tsx, tsy = get(("torso", "sx")), get(("torso", "sy"))
    jig = lag(hy, 4.5, 0.28)
    out = {("head", "y"): head2, ("head", "rotation"): hrot2,
           ("torso", "sy"): [v - 0.0007 * j for v, j in zip(tsy, jig)], ("torso", "sx"): [v + 0.0005 * j for v, j in zip(tsx, jig)]}
    for ear, sign, hz in (("earL", 1, 4.2), ("earR", -1, 3.7)):
        e = get((ear, "rotation"))
        out[(ear, "rotation")] = [v + sign * 0.12 * l for v, l in zip(e, lag(world, hz, 0.22))]
    for s_, hz, k in (("R", 2.9, 0.45), ("L", 2.5, 0.5)):
        c = (HANDS[s_], "ty")
        out[c] = [v + k * l for v, l in zip(get(c), lag(hy, hz, 0.3))]
    for c, vs in out.items():
        ch[c] = [(t, v, LINEAR) for t, v in zip(ts, vs)]
    return ch


def made(name, duration, loop, timeline, sparse=False):
    """the document with this animation on its layers and bones (its own keys only on what it moves)"""
    d = copy.deepcopy(base)
    d["turn"]["keys"] = [{"t": 0, "v": [v["id"] for v in d["turn"]["views"]].index("front"), "ease": HOLD}]
    for l in d["layers"]:
        l["keys"] = {}
    for b in d["bones"]:
        b["keys"] = {}
        if b.get("ik"):
            b["ik"]["keys"] = {}
    L = {l["id"]: l for l in d["layers"]}
    B = {b["id"]: b for b in d["bones"]}
    for (who, prop), ks in (loosen(sparse_keys(timeline), duration) if sparse else keys_of(timeline)).items():
        k = [{"t": t, "v": round(v, 2), "ease": e} for t, v, e in ks]
        if who in L:
            L[who]["keys"][prop] = k
        else:
            B[who]["ik"]["keys"][prop] = k
    d["duration"], d["loop"] = duration, loop
    return d


def waved():
    """his own front wave, as Puppet Views has it (its keys, front only)"""
    d = copy.deepcopy(base)
    d["turn"]["keys"] = [{"t": 0, "v": [v["id"] for v in d["turn"]["views"]].index("front"), "ease": HOLD}]
    d["loop"] = False
    return d


anims = [("Idle", made("Idle", 3200, True, IDLE)), ("Right", made("Right", 1700, False, RIGHT2, sparse=True)), ("Wrong", made("Wrong", 1500, False, WRONG)),
         ("Wave", waved()), ("Cheer", made("Cheer", 1600, False, CHEER))]


def capture(d, id_, name):
    bones = {b["id"]: {"keys": b["keys"], "loop": b.get("loop", 0), "rotation": b.get("rotation", 0), "x": b.get("x", 0), "y": b.get("y", 0), "scale": b.get("scale", 1),
                       **({"ik": {"keys": b["ik"]["keys"], "tx": b["ik"]["tx"], "ty": b["ik"]["ty"], "mix": b["ik"]["mix"], "bend": b["ik"]["bend"]}} if b.get("ik") else {})}
             for b in d["bones"]}
    layers = {l["id"]: {"keys": l["keys"], "loop": l.get("loop", 0), "blink": l.get("blink", 0)} for l in d["layers"]}
    return {"id": id_, "name": name, "duration": d["duration"], "loop": d["loop"], "bones": bones, "layers": layers}


os.makedirs(out_dir, exist_ok=True)
for name, d in anims:
    one = copy.deepcopy(d)
    one["id"], one["name"] = f"bubu-lesson-{name.lower()}", f"Bùbù lesson: {name}"
    # (the preview's room to jump: the frame taller, the front moved down into it, its feet's controls with it)
    one["height"] += ROOM
    for l in one["layers"]:
        if l["id"] == "view-front":
            l["keys"]["y"] = [{"t": 0, "v": l["y"] + ROOM, "ease": HOLD}]   # (a key: moving its rest would carry nothing)
    for b in one["bones"]:
        if b["id"] in FEET.values():                     # (the feet's controls are the document's; the hands' the torso's)
            b["ik"]["ty"] += ROOM
            for k in b["ik"]["keys"].get("ty", []):
                k["v"] += ROOM
    json.dump(one, open(os.path.join(out_dir, one["id"] + ".json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
all_ = copy.deepcopy(anims[0][1])
all_["id"], all_["name"] = "bubu-lesson", "Bùbù lesson"
all_["anims"] = [capture(d, f"A{name.lower()}", name) for name, d in anims]
all_["anim"] = "Aidle"
json.dump(all_, open(os.path.join(out_dir, "bubu-lesson.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("made:", ", ".join(f"{n} ({d['duration']} ms{', loops' if d['loop'] else ''})" for n, d in anims))
