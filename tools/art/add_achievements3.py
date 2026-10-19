"""Codex jobs, take three (the owner: no plaques to combine after - "we want their sort of look but our style", and
simpler: the first ones were "too complex and detailed"): each badge ONE finished picture, Bùbù doing the family's
thing in front of a simple badge shape (a four-lobed garden window) in the family's own colour, his head breaking out
of its top, sticker-simple. The app writes the tier's number over the plain foot of the shape, and the name and
"3 of 5" under it. Replaces the jobs of add_achievements.py (round medals) and add_achievements2.py (plaques)."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
jobs = [j for j in jobs if j.get('group') not in ('achievements2',)]   # (take two, never finished: gone)
have = {j['file'] for j in jobs}
# the simplest of the app's art first (its lantern icon), then Bùbù as he is
REFS = ['out/raw/lantern-icon-lit.png', 'refs/panda-celebrate.png', 'refs/panda-waving.png']

PROMPT = """An ACHIEVEMENT BADGE for the app, shown small (80 to 100 pixels), so it must read at a glance: Bùbù {what}

He stands in front of a simple BADGE SHAPE: a four-lobed traditional Chinese garden window (a begonia window: four soft rounded lobes), flat {colour}, with a slightly lighter flat inner area. The badge shape fills about 80% of the canvas width; Bùbù is drawn over it, a little bigger than it, his head and his prop breaking out above its top edge. Leave the bottom fifth of the badge shape plain and empty: the app writes a number there.

STICKER SIMPLE: big bold flat shapes, very few details, one or two flat tones a colour, no texture, no grain, no fine lines, no small patterns, no outlines, no glossy highlights. As simple and chunky as the first attached image (the app's lantern icon). Only one prop.

Bùbù, simplified to that level but still clearly him (the other attached images): a chubby baby panda, a big round cream-white head about as wide as his body, charcoal round ears, charcoal eye patches with happy arched eyes, a small black nose, rosy blush cheeks, a little white tuft of fur on top, charcoal arms and stubby legs, a cream belly, and his small coral-red backpack.

Palette: muted and warm, as the app: jade and teal greens, warm cream, terracotta red, soft orange, soft gold, warm greys, charcoal for the darkest.

Background: one flat, solid pure magenta (#FF00FF) filling the whole canvas around the badge, with no gradient, vignette, texture, glow or shadow on it, so it can be cut out cleanly. Do not use any magenta or hot pink inside the artwork itself. Crisp clean edges against the magenta, no soft halo. No text, no letters, no numbers, no watermark, no border, no frame."""

badges = [
    ("lantern-keeper", "holding a glowing round red lantern up high in both paws, beaming.", "soft coral red"),
    ("step-by-step", "mid-hop onto a flat round grey stepping stone, one foot up, arms out for balance.", "teal"),
    ("word-garden", "watering a little bamboo shoot in a small pot with a tiny watering can.", "sage green"),
    ("brush-and-ink", "holding a big calligraphy brush upright like a proud artist, a dab of ink on his cheek.",
     "warm grey"),
    ("copybook", "with a square sheet of practice paper with a red grid, drawing one thick black stroke on it, "
                 "tongue poking out (one stroke, not a character).", "warm sand"),
    ("mountain-climber", "planting a little red flag, one fist raised, a small rounded green peak under his feet.",
     "jade green"),
    ("storyteller", "reading aloud from a half-unrolled scroll, the other paw raised dramatically (plain scroll, "
                    "no writing).", "soft orange"),
    ("seal-collector", "pressing down a big green seal stamp, a red square mark beside it (a plain red square, no "
                       "character).", "terracotta"),
    ("lucky-pockets", "hugging an armful of red envelopes, delighted.", "soft gold"),
    ("pathfinder", "in a little explorer's straw hat, holding out a round bronze compass and peering at it.",
     "warm bronze brown"),
    ("rekindled", "kneeling and gently blowing on a small dim red lantern, one tiny golden spark at its bottom.",
     "soft amber"),
    ("flawless", "holding a round pale-green jade disc with a hole in the middle up above his head, eyes shut "
                 "with pride.", "pale jade"),
    ("night-owl", "in a floppy nightcap, reading a small book by a little lantern, a crescent moon by his ear.",
     "deep muted blue"),
    ("early-bird", "doing a tai chi stretch on one leg, arms out, a round golden sun behind his head.",
     "warm sunrise orange"),
    ("lightning-fast", "sprinting flat out, a red headband streaming behind him.", "muted sky blue"),
    ("kung-fu-master", "in a confident kung fu stance, one paw forward, a red sash round his middle.", "deep red"),
    ("dressed-up", "wearing a green dragon-costume hood with two little yellow horns, paws up like claws, "
                   "roaring cheekily.", "dragon green"),
]

new = [{"file": f"out/raw/achv3-{n}.png", "group": "achievements3", "size": "1024x1024", "refs": REFS,
        "prompt": PROMPT.format(what=what, colour=colour)} for n, what, colour in badges]
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', len(added))
