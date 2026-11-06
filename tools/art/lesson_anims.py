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

# (Wrong's "oops" brings his whole arms in front of his face, by Studio's draw-order keys (5 Nov 2026): the owner, of a first
# try with only the paws cut out and shown over the face, "that works terribly", the arms gone behind the head; animators key
# the draw order instead (Spine, Harmony), which Studio and the app's export now do)


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
# (the body: the owner, 5 Nov 2026: "body works"; then "feels more he just floats in the air": v7 hung by the top for 0.6 s
# on gentle eases. Now a real arc: slowing to the top, the barest pause, falling faster and faster; half the time in the air)
BODY = [(0, REST_ALL, SMOOTH),
        (60, dict(hy=0, tsy=1, tsx=1, head=0), OUT),
        (230, dict(hy=34, tsx=1.13, tsy=0.84, head=22, hsx=1.05, hsy=0.94, fy=6), SMOOTH),
        (280, dict(earL=10, earR=-10), OUT),
        (320, dict(hy=-150, tsx=0.9, tsy=1.12, head=-14, hsx=0.97, hsy=1.04, tilt=-6, fy=-8), OUT),
        (380, dict(earL=-14, earR=12), OUT),
        (470, dict(hy=-290, tsx=0.98, tsy=1.03, head=-8, hsx=1, hsy=1, hrot=-3, tilt=-9), SMOOTH),
                (540, dict(hy=-282, tsx=1, tsy=1, head=-6, hrot=-2, tilt=-8, earL=-9, earR=9), IN),
        (740, dict(hy=0, tsx=0.95, tsy=1.07, head=-12, tilt=-2), OUT),
        (800, dict(hy=40, tsx=1.12, tsy=0.86, head=20, hsx=1.04, hsy=0.95, tilt=4, hrot=-3, fy=4), OUT),
        (840, dict(earL=14, earR=-12), OUT),
        (920, dict(hy=-6, tsx=0.98, tsy=1.03, head=-4, hsx=1, hsy=1, tilt=1, hrot=-1, fy=0), SMOOTH),
                (1060, REST_ALL, SMOOTH),
                (1300, REST_ALL, SMOOTH)]
# (where a hand goes for its arm at an angle: the hand controls are measured from where the hand rests, out at his side, so
# "up 310" had been up and out from there, and v6's V came out nearly flat. Aimed from the shoulder instead: degrees above
# the level, outward, at a share of the arm's full reach (under 1 keeps a soft elbow))
SHOULDER = {"R": (B0["bUpperArmR"]["hx"], B0["bUpperArmR"]["hy"]), "L": (B0["bUpperArmL"]["hx"], B0["bUpperArmL"]["hy"])}
ARM_LEN, UPPER, FORE = 282, 141, 141


def aim(s_, deg, reach=0.95):
    import math
    out = 1 if s_ == "R" else -1
    x = SHOULDER[s_][0] + out * ARM_LEN * reach * math.cos(math.radians(deg))
    y = SHOULDER[s_][1] - ARM_LEN * reach * math.sin(math.radians(deg))
    return {"h" + s_ + "x": round(x - HAND0[s_][0], 1), "h" + s_ + "y": round(y - HAND0[s_][1], 1)}


def bent(s_, upper, fore):
    """an arm bent at the elbow: the upper arm at `upper` degrees above the level (outward), the forearm at `fore` (90: straight
    up), the hand where they end (the owner: "arm could be more 90 degrees ish", then "too 90 degree": a fist pump's elbow
    at about 125 degrees. His head is far wider than
    his shoulders, so a forearm straight up from a level upper arm is behind it: the L is tipped out instead, the upper arm
    down and out, the forearm up and out, the hand by his cheek)"""
    import math
    out = 1 if s_ == "R" else -1
    ex = SHOULDER[s_][0] + out * UPPER * math.cos(math.radians(upper))
    ey = SHOULDER[s_][1] - UPPER * math.sin(math.radians(upper))
    x, y = ex + out * FORE * math.cos(math.radians(fore)), ey - FORE * math.sin(math.radians(fore))
    return {"h" + s_ + "x": round(x - HAND0[s_][0], 1), "h" + s_ + "y": round(y - HAND0[s_][1], 1)}


def arms(r, l=None, rr=0.95, lr=None):
    return {**aim("R", r, rr), **aim("L", r if l is None else l, rr if lr is None else lr)}


# (after Pengu's jump on Tenor ("excited", the owner's pick): one-sided, never mirrored: in the air the left arm (on screen)
# pumps up bent at the elbow while the right sticks out to the side; the left foot kicks up bent while the right dangles; the
# body leans toward the raised arm)
ARMS = [(60, dict(hRx=0, hRy=0, hLx=0, hLy=0), SMOOTH),
        (230, arms(-62, rr=0.93), OUT),
        (320, arms(-72, rr=0.98), OUT),
        (380, {**aim("R", -6, 0.97), **bent("L", -45, 10)}, SMOOTH),
        (440, {**aim("R", 4, 0.97), **bent("L", -14, 44)}, OUT),
        (560, {**aim("R", 0, 0.96), **bent("L", -18, 38)}, SMOOTH),
        (690, {**aim("R", 6, 0.96), **bent("L", -14, 42)}, IN),
        (790, arms(6, 10, 0.97, 0.97), OUT),
        (910, arms(-55), SMOOTH),
        (1030, dict(hRx=0, hRy=-4, hLx=0, hLy=0), SMOOTH)]
# (the legs: "a bit stiff" in v8, held in one shape the whole time in the air; v9's two quick kicks were "weird", a shake.
# Now one kick: the left leg kicks up and eases down slowly through the fall, the right swings once out, and both reach
# for the ground before landing)
LEGS = [(230, dict(fRx=0, fRy=0, fLx=0, fLy=0), SMOOTH),
        (290, dict(fRx=0, fRy=0, fLx=0, fLy=0), OUT),
        (330, dict(fRx=-8, fRy=-60, fLx=8, fLy=-60), OUT),
        (480, dict(fRx=8, fRy=-235, fLx=-88, fLy=-375), OUT),
        (600, dict(fRx=26, fRy=-225, fLx=-75, fLy=-320), SMOOTH),
        (690, dict(fRx=30, fRy=-90, fLx=-45, fLy=-120), IN),
        (740, dict(fRx=35, fRy=0, fLx=-35, fLy=0), OUT)]
RIGHT2 = sorted(BODY + ARMS + LEGS, key=lambda k: k[0])
# Right: a little crouch, a hop with both hands up and out, the head back, the ears flicking; landing with a squash, then rest
RIGHT = [(0, R0, SMOOTH),
         (140, pose(hips=(0, 14), head=(4, 0), hR=(6, 6), hL=(-6, 6)), OUT),
         (360, pose(hips=(0, -46), fR=(0, -32), fL=(0, -32), torso=0, head=(-4, -5), earL=-12, earR=12, face=(0, -8),
                    hR=(40, -300), hL=(-40, -300)), SMOOTH),
         (560, pose(hips=(0, 10), head=(3, -3), earL=6, earR=-6, face=(0, -6), hR=(45, -290), hL=(-45, -290)), OUT),
         (760, pose(hips=(0, -2), head=(0, -2), face=(0, -4), hR=(35, -260), hL=(-35, -260)), SMOOTH),
         (1300, R0, SMOOTH)]
# Wrong, "oops", after Pengu covering its eyes on Tenor (the owner's pick, 5 Nov 2026): a flinch, the ears up; the hands fly
# up to his eyes (the arms drawn in front of the head from as they cross its edge) landing with a little overshoot; hunched
# behind them, the ears drooping, a small lean; the hands down (the arms back under the head as they leave it), and
# settled. Every part once, no double wiggles
EYE = {"R": (L0["patchR"]["x"], L0["patchR"]["y"]), "L": (L0["patchL"]["x"], L0["patchL"]["y"])}


def hand_at(s_, x, y):
    return {"h" + s_ + "x": round(x - HAND0[s_][0], 1), "h" + s_ + "y": round(y - HAND0[s_][1], 1)}


# (held a little below the eyes: right over them, the dark paws read as his dark eye patches, not as paws in front)
# (the parts in front of the arms come forward with them, keeping their order over the arms, the owner: "part needs to stay
# behind the straps still", "and the straps still under the belly part": the belly, then the straps, then the arms, all just
# over the face. Each is put just over the mouth in the list's order, so each lands under the ones before it)
UP = [(200, "mouth"), (940, "")]
WRONG2_ABOVE = {"belly": UP, "strapR": UP, "strapL": UP, "armR": UP, "armL": UP}
def hands_at(dx, dy, out=0):
    """both hands on his eyes, moved by (dx, dy), `out` further apart"""
    return {**hand_at("R", EYE["R"][0] + out + dx, EYE["R"][1] + dy), **hand_at("L", EYE["L"][0] - out + dx, EYE["L"][1] + dy)}


WRONG2 = [(0, REST_ALL, SMOOTH),
          (90, dict(hy=10, tsx=1.05, tsy=0.94, head=8, hrot=-3, earL=-12, earR=12), OUT),
          (100, arms(-30, rr=0.95), SMOOTH),
          (180, hands_at(0, 170, out=90), SMOOTH),
          (260, hands_at(0, 30, out=8), OUT),
          (340, {**hands_at(0, 48, out=10), **dict(hy=14, tsx=1.03, tsy=0.96, head=10, hsx=1, hsy=1, tilt=0, hrot=0)}, SMOOTH),
          (420, dict(earL=10, earR=-10), SMOOTH),
          (760, {**hands_at(3, 52, out=10), **dict(hy=16, tilt=3, hrot=3, earL=20, earR=-20)}, SMOOTH),
          (930, hands_at(0, 170, out=90), IN),
          (1040, {**arms(-62), **dict(hy=-4, tilt=0, hrot=0, head=-3, tsx=0.99, tsy=1.02, earL=-6, earR=6)}, OUT),
          (1180, REST_ALL, SMOOTH),
          (1400, REST_ALL, SMOOTH)]
# (the first pass's Wrong, kept for comparing) Wrong: the head drops and turns away a little, the body slumps, the ears droop, the hands come in, the face looks down; held, then
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
    # (damped so each overshoots once and settles: looser, they bounced two and three times, "double wiggles of stuff")
    dt, n = 1 / fps, int(duration * fps / 1000) + 1
    ts = [min(duration, i * 1000 / fps) for i in range(n)]
    get = lambda c: [at(ch[c], t) for t in ts]
    hy = get(("hips", "y"))
    head, hrot, tilt = get(("head", "y")), get(("head", "rotation")), get(("torso", "rotation"))
    lag = lambda xs, hz, damp: [s_ - x for s_, x in zip(spring(xs, hz, damp, dt), xs)]
    body = lag(hy, 3.2, 0.6)                          # (+: the body has gone up and the loose part is still below)
    head2 = [h + 0.3 * b for h, b in zip(head, body)]
    hrot2 = [r + 0.8 * l for r, l in zip(hrot, lag(tilt, 2.6, 0.6))]
    world = [y + h for y, h in zip(hy, head2)]
    # (the body's own wobble: its squash still going a moment after the jump's and the landing's)
    tsx, tsy = get(("torso", "sx")), get(("torso", "sy"))
    jig = lag(hy, 4.5, 0.6)
    out = {("head", "y"): head2, ("head", "rotation"): hrot2,
           ("torso", "sy"): [v - 0.0007 * j for v, j in zip(tsy, jig)], ("torso", "sx"): [v + 0.0005 * j for v, j in zip(tsx, jig)]}
    for ear, sign, hz in (("earL", 1, 4.2), ("earR", -1, 3.7)):
        e = get((ear, "rotation"))
        out[(ear, "rotation")] = [v + sign * 0.12 * l for v, l in zip(e, lag(world, hz, 0.5))]
    for s_, hz, k in (("R", 2.9, 0.45), ("L", 2.5, 0.5)):
        c = (HANDS[s_], "ty")
        out[c] = [v + k * l for v, l in zip(get(c), lag(hy, hz, 0.6))]
    for c, vs in out.items():
        ch[c] = [(t, v, LINEAR) for t, v in zip(ts, vs)]
    return ch


def made(name, duration, loop, timeline, sparse=False, above=None):
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
    for lid, ks in (above or {}).items():
        L[lid]["above"] = [{"t": t, "id": i} for t, i in ks]
    d["duration"], d["loop"] = duration, loop
    return d


def waved():
    """his own front wave, as Puppet Views has it (its keys, front only)"""
    d = copy.deepcopy(base)
    d["turn"]["keys"] = [{"t": 0, "v": [v["id"] for v in d["turn"]["views"]].index("front"), "ease": HOLD}]
    d["loop"] = False
    return d


anims = [("Idle", made("Idle", 3200, True, IDLE)), ("Right", made("Right", 1300, False, RIGHT2, sparse=True)), ("Wrong", made("Wrong", 1400, False, WRONG2, sparse=True, above=WRONG2_ABOVE)),
         ("Wave", waved()), ("Cheer", made("Cheer", 1600, False, CHEER))]


def capture(d, id_, name):
    bones = {b["id"]: {"keys": b["keys"], "loop": b.get("loop", 0), "rotation": b.get("rotation", 0), "x": b.get("x", 0), "y": b.get("y", 0), "scale": b.get("scale", 1),
                       **({"ik": {"keys": b["ik"]["keys"], "tx": b["ik"]["tx"], "ty": b["ik"]["ty"], "mix": b["ik"]["mix"], "bend": b["ik"]["bend"]}} if b.get("ik") else {})}
             for b in d["bones"]}
    layers = {l["id"]: {"keys": l["keys"], "loop": l.get("loop", 0), "blink": l.get("blink", 0), **({"above": l["above"]} if l.get("above") else {})}
              for l in d["layers"]}
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
# (a test, the owner, 5 Nov 2026: "see what a spin looks like with what we have": Right with a spin in the air through the
# five views there are: the front, three-quarter right, side right, then side left (the back, not drawn, skipped), three-quarter
# left and the front again, each for about a frame and a half. The other views aren't keyed, so they spin in their rest pose,
# carried up and down with the jump)
spin = json.load(open(os.path.join(out_dir, "bubu-lesson-right.json"), encoding="utf-8"))
spin["id"], spin["name"] = "bubu-lesson-spin", "Bùbù lesson: spin test"
order = [v["id"] for v in spin["turn"]["views"]]
spin["turn"]["keys"] = [{"t": t, "v": order.index(v), "ease": HOLD} for t, v in
                        [(0, "front"), (380, "quarter-r"), (430, "side-r"), (480, "side-l"), (530, "quarter-l"), (580, "front")]]
hips_y = [(k["t"], k["v"], k["ease"]) for k in next(l for l in spin["layers"] if l["id"] == "hips")["keys"]["y"]]
for l in spin["layers"]:
    if l["id"] in ("view-side", "view-quarter"):
        l["keys"]["y"] = [{"t": t, "v": round(l["y"] + ROOM + at(hips_y, t) - REST["hips"][1], 2), "ease": LINEAR}
                          for t in range(0, spin["duration"] + 1, 33)]
# (the arms on the turned views, the owner: "match arm pose as if they were lagging behind rather than at the sides": flung
# out and trailing the turn. He turns one way all through, so on screen they trail to the left throughout: behind him in the
# right-facing views, and in the mirrored left-facing ones keyed the other way in the rig, which the mirror brings back left.
# Each held (HOLD) for the frames its view shows; an arm aimed from its shoulder at degrees from the rig's +x, upward)
import math
SB = {b["id"]: b for b in spin["bones"]}


def flung(hand, deg, reach):
    ik, r = SB[hand]["ik"], SB[SB[hand]["ik"]["root"]]
    return (round(r["hx"] + reach * math.cos(math.radians(deg)), 1), round(r["hy"] - reach * math.sin(math.radians(deg)), 1))


SPIN_ARMS = {  # hand: [(t, (deg, reach) or None for rest)]
    # (the three-quarters likewise: the arm to the back trailing, the one to the front forward and out; the mirror again
    # serves the left-facing one)
    "qarmL4": [(0, None), (370, (165, 224)), (590, None)],
    "qarmR4": [(0, None), (370, (20, 224)), (590, None)],
    # (the side views, as the owner put it: the near arm trailing back, the far one, behind him, forward. The mirror turns
    # the left-facing view round whole, so the same keys serve it. The far arm is too short to clear his belly, so forward
    # it's hidden: there for if the belly or the arm changes)
    "sarmL4": [(0, None), (420, (155, 200)), (540, None)],
    "sarmR4": [(0, None), (420, (40, 212)), (540, None)]}
for hand, ks in SPIN_ARMS.items():
    ik = SB[hand]["ik"]
    pts = [(t, (ik["tx"], ik["ty"]) if a_ is None else flung(hand, *a_)) for t, a_ in ks]
    ik["keys"]["tx"] = [{"t": t, "v": xy[0], "ease": HOLD} for t, xy in pts]
    ik["keys"]["ty"] = [{"t": t, "v": xy[1], "ease": HOLD} for t, xy in pts]
json.dump(spin, open(os.path.join(out_dir, "bubu-lesson-spin.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
# (a test for Wrong, the owner's idea, 6 Nov 2026, the oops being "kinda static": "a desk slides in from the right and he
# slams his arms on it, he can turn 45 degrees". The desk slides in, he notices, turns to the three-quarter right, winds up
# leaning back with his arms back, slams both hands down on it (the body squashed, the head dropping, the desk jolting),
# slumps over it a moment, then lets go, turns back and the desk slides away. He stands behind it: from the three-quarter
# his near arm (the back one) is too short to reach a desk out to his side)
SLAM_FRONT = [(0, REST_ALL, SMOOTH),
              (110, dict(hy=8, tsx=1.04, tsy=0.95, earL=-14, earR=14, fx=14, fy=-4), OUT),
              (220, dict(hy=0, tsx=1, tsy=1), SMOOTH),
              (1365, dict(hy=10, tsx=1.04, tsy=0.96, head=8, earL=16, earR=-16, fx=6, fy=10), SMOOTH),
              (1515, dict(earL=12, earR=-12), SMOOTH),
              (1665, REST_ALL, SMOOTH),
              (1915, REST_ALL, SMOOTH)]
slam = made("Slam", 1915, False, SLAM_FRONT, sparse=True)
slam["id"], slam["name"] = "bubu-lesson-slam", "Bùbù lesson: desk slam test"
order = [v["id"] for v in slam["turn"]["views"]]
slam["turn"]["keys"] = [{"t": t, "v": order.index(v), "ease": HOLD} for t, v in [(0, "front"), (230, "quarter-r"), (1340, "front")]]
SL = {l["id"]: l for l in slam["layers"]}
SLB = {b["id"]: b for b in slam["bones"]}


def lk(lid, prop, ks):
    """keys on a layer: [(t, offset from rest, ease)]"""
    l = SL[lid]
    if prop in ("sx", "sy", "scale"):   # (scales: as given, times its own)
        r = l.get(prop, 1)
        l["keys"][prop] = [{"t": t, "v": round(r * v, 3), "ease": e} for t, v, e in ks]
        return
    r = l.get(prop, 0)
    l["keys"][prop] = [{"t": t, "v": round(r + v, 3), "ease": e} for t, v, e in ks]


# the three-quarter body: (t, hips dy, torso turn, torso sx, sy, head dy, head turn, ease)
# (the build-up, the owner, 6 Nov 2026: "think we need a little build up", then of a slow rise and a held top, "a bit slow
# and ... the overshoot at the top where the arms reach its peak is where we want the exaggeration": a quick gather, the
# arms shooting up past the top, stretched and leaning far back, settling back a touch, and the slam from there)
Q = [(230, 0, 0, 1, 1, 0, 0, SMOOTH),
     (340, 10, -2, 1.04, 0.96, 6, -2, OUT),            # (gathering: a little crouch, the elbows back; then shot up)
     (520, -36, -11, 0.91, 1.13, -18, -9, SMOOTH),     # (the peak, overshot: as high and far back as he goes)
     (600, -22, -7, 0.95, 1.07, -10, -6, SMOOTH),      # (settled back from it a touch)
     (660, 24, 6, 1.09, 0.89, 26, 9, OUT),             # (the slam, arrived at fast)
     (735, 12, 4, 1.03, 0.97, 18, 6, SMOOTH),          # (the rebound)
     (885, 18, 5, 1.05, 0.95, 30, 11, SMOOTH),         # (slumped, the head hanging)
     (1185, 20, 5, 1.04, 0.96, 34, 12, SMOOTH),
     (1285, -6, -2, 0.98, 1.03, -4, -2, OUT),          # (letting go, up)
     (1340, 0, 0, 1, 1, 0, 0, SMOOTH)]
IN_FAST = [0.6, 0, 1, 0.6]
ease_into = {455: IN_FAST}
lk("qHips", "y", [(t, hy, e) for t, hy, *_, e in Q])
lk("qTorso", "rotation", [(t, r, e) for t, _, r, *_r, e in Q])
lk("qTorso", "sx", [(t, x, e) for t, _, _, x, *_r, e in Q])
lk("qTorso", "sy", [(t, y, e) for t, _, _, _, y, *_r, e in Q])
lk("qHead", "y", [(t, v, e) for t, *_a, v, _r, e in Q])
lk("qHead", "rotation", [(t, v, e) for t, *_a, v, e in Q])
# (the ears left to the head: keyed, flung up by the slam and drooping, the owner, 6 Nov 2026: "not a fan of the ear animtion")
# the eases: the slam itself accelerating in
for lid in ("qHips", "qTorso", "qHead"):
    for ks in SL[lid]["keys"].values():
        for k in ks:
            if k["t"] == 600:
                k["ease"] = IN_FAST

# the hands, where they go in the document (then put in the torso's space as it is then)
TQ = (SL["qTorso"]["pivot"]["x"], SL["qTorso"]["pivot"]["y"]) if SL["qTorso"].get("pivot") else (SL["qTorso"]["x"], SL["qTorso"]["y"])
# (the desk moved left to the middle, the owner: "table needs to be more in the middle": along its top's edge, which rises to
# the right, the top where his hands land comes up by the slope)
DESK_SHIFT = -190
DESK_TOP = round(792 + DESK_SHIFT * 0.187)


def torso_space(t, x, y):
    qs = {c: at([(k["t"], k["v"], k["ease"]) for k in SL[lid]["keys"][prop]], t) for c, (lid, prop) in
          {"hy": ("qHips", "y"), "r": ("qTorso", "rotation"), "sx": ("qTorso", "sx"), "sy": ("qTorso", "sy")}.items()}
    dy = qs["hy"] - SL["qHips"]["y"]
    a = math.radians(qs["r"])
    px, py = x - TQ[0], y - TQ[1] - dy
    rx, ry = px * math.cos(a) + py * math.sin(a), -px * math.sin(a) + py * math.cos(a)
    return round(TQ[0] + rx / qs["sx"], 1), round(TQ[1] + ry / qs["sy"], 1)


# (the build-up as the owner drew it, 6 Nov 2026, "arms should build up like this": first the elbows back, the hands low by
# his belly, then both hands up in front of his face, the elbows down, then the slam)
HANDS_Q = {  # hand: [(t, doc place or None for rest, ease)]
    # (the far arm folded at the top, the upper arm forward, the elbow low, the forearm up, as the owner drew it: "elbow
    # still wrong... be like this"; reaching out straight, turned that far from hanging its mesh had bent like a banana)
    "qarmL4": [(230, None, SMOOTH), (340, (415, 830), OUT), (520, (625, 418), SMOOTH), (600, (650, 468), IN_FAST), (660, (585, DESK_TOP), OUT), (1245, (585, DESK_TOP), SMOOTH), (1325, None, SMOOTH)],
    "qarmR4": [(230, None, SMOOTH), (340, (760, 800), OUT), (520, (845, 470), SMOOTH), (600, (860, 500), IN_FAST), (660, (945, DESK_TOP - 8), OUT), (1245, (945, DESK_TOP - 8), SMOOTH), (1325, None, SMOOTH)]}
for hand, ks in HANDS_Q.items():
    ik = SLB[hand]["ik"]
    pts = []
    for t, xy, e in ks:
        pts.append((t, (ik["tx"], ik["ty"]) if xy is None else torso_space(t, *xy), e))
        if xy is not None and t == 660:   # (held on the desk while the body squashes and slumps: a key a frame)
            for t2 in range(675, 1246, 33):
                pts.append((t2, torso_space(t2, *xy), LINEAR))
    pts.sort(key=lambda p: p[0])
    ik["keys"]["tx"] = [{"t": t, "v": xy[0], "ease": e} for t, xy, e in pts]
    ik["keys"]["ty"] = [{"t": t, "v": xy[1], "ease": e} for t, xy, e in pts]

# the desk: drawn in front of all of him
DESK = {"x0": 316 + DESK_SHIFT, "x1": 316 + DESK_SHIFT + 1075.2, "top": 591, "floor": 591 + 716.8}   # (Codex's desk, 1536x1024 at 0.7: its top where his hands land)   # (drawn at 45 degrees as he is, the owner: "table comes in at 45 degrees too")
desk = copy.deepcopy(SL["qBelly"])
for k_ in ("shade", "skin", "mask", "masks", "clip", "cut", "above", "warp", "deform", "paintMask"):
    desk.pop(k_, None)
desk.update({"id": "desk", "name": "desk (slam test)", "art": "desk.png", "parent": None,
             "x": (DESK["x0"] + DESK["x1"]) / 2, "y": (DESK["top"] + DESK["floor"]) / 2,
             "w": DESK["x1"] - DESK["x0"], "h": DESK["floor"] - DESK["top"], "keys": {}, "loop": 0, "blink": 0, "group": "Props"})
desk["pivot"] = {"x": desk["x"], "y": desk["y"]}
# (over all of him but his head: the arms on it go under the head, the owner: "make sure the arm is under the head")
slam["layers"].insert([l["id"] for l in slam["layers"]].index("qHead") + 1, desk)
SL["desk"] = desk
# (sliding in along its own length, its top's front edge, from the back right, the owner: "desk feels like its still sliding
# in from the side rather than a 45 degrees", then of a steeper desk, "desk before was better" with an arrow along that edge;
# and out the same way)
ALONG = (-0.982, 0.187)   # (its top's front edge, from the left, the owner: "table may be better coming in from the left side")
lk("desk", "x", [(0, 1300 * ALONG[0], HOLD), (40, 1300 * ALONG[0], OUT), (270, -22 * ALONG[0], SMOOTH), (360, 0, SMOOTH),
                 (1305, 0, IN), (1585, 1300 * ALONG[0], HOLD)])
lk("desk", "y", [(0, 1300 * ALONG[1], HOLD), (40, 1300 * ALONG[1], OUT), (270, -22 * ALONG[1], SMOOTH), (360, 0, SMOOTH),
                 (660, 0, OUT), (685, 16, SMOOTH), (745, -5, SMOOTH), (825, 0, SMOOTH), (1305, 0, IN), (1585, 1300 * ALONG[1], HOLD)])
lk("desk", "rotation", [(0, 0, SMOOTH), (660, 0, OUT), (685, 1.2, SMOOTH), (765, -0.4, SMOOTH), (845, 0, SMOOTH)])
# (his near arm comes over the strap's strand down his shoulder while it moves: drawn for the arm hanging at his side, it
# covered the arm swung forward, the owner: "not sure why arm is behind the strap? we didnt set it up like that")
# (up in front of his face for the wind-up, over everything of the three-quarter)
SL["qArmL"]["above"] = [{"t": 290, "id": "qStrapLOver"}, {"t": 640, "id": "desk"}, {"t": 1315, "id": ""}]
# (the desk in front of all of him, the owner, 6 Nov 2026: "also table in front of everything", but his near arm once it's
# on it (behind it, the hand was gone); his far arm (screen right) over the desk but behind his body, the owner: "SR arm,
# behind the body, but over the table". In layers that's a loop (arm under body, body under desk, desk under arm), so the arm
# goes over the desk and is cut out where his body draws; its hand out past his body on the desk)
SL["qArmR"]["above"] = [{"t": 640, "id": "desk"}, {"t": 1285, "id": ""}]
SL["qArmR"]["cut"] = ["qTorso", "qBelly", "qStrapR", "qPack"]
SL["qArmR"]["shade"]["cast"] = False   # (its shadow on his chest showed through the cut)

# the preview's room above him, as the others
slam["height"] += ROOM
for l in slam["layers"]:
    if l["id"] in ("view-front", "view-quarter"):
        l["keys"]["y"] = [{"t": 0, "v": l["y"] + ROOM, "ease": HOLD}]
for k in desk["keys"]["y"]:
    k["v"] += ROOM
desk["y"] += ROOM
desk["pivot"]["y"] += ROOM
for b in slam["bones"]:
    if b["id"] in FEET.values():   # (the front's feet are the document's; the three-quarter's move with its view)
        b["ik"]["ty"] += ROOM
        for k in b["ik"]["keys"].get("ty", []):
            k["v"] += ROOM
json.dump(slam, open(os.path.join(out_dir, "bubu-lesson-slam.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
all_ = copy.deepcopy(anims[0][1])
all_["id"], all_["name"] = "bubu-lesson", "Bùbù lesson"
all_["anims"] = [capture(d, f"A{name.lower()}", name) for name, d in anims]
all_["anim"] = "Aidle"
json.dump(all_, open(os.path.join(out_dir, "bubu-lesson.json"), "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print("made:", ", ".join(f"{n} ({d['duration']} ms{', loops' if d['loop'] else ''})" for n, d in anims))
