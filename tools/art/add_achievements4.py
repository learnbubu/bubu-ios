"""Codex jobs, take four (the owner chose the mockup of 19 Oct 2026: Duolingo's badge, put together as theirs is): Codex
draws ONLY Bùbù doing each family's thing, big and sticker-simple, nothing behind him. The app draws the rest the same
for every badge: the four-lobed window shape in the family's colour with a thick two-tone rim, Bùbù standing in it
(his legs inside it, the rest breaking out over its top), the tier's big outlined number over its foot, "NEW", the
name and "3 of 5". Replaces the jobs of takes one to three (add_achievements*.py)."""
import json

jobs = json.load(open('jobs.json', encoding='utf-8'))
jobs = [j for j in jobs if j.get('group') not in ('achievements2', 'achievements3')]   # (takes two and three: gone)
have = {j['file'] for j in jobs}
# the two Bùbùs of take three first (the look: just right - ignore the shape behind them), then Bùbù as he is
REFS = ['out/raw/achv3-lantern-keeper.png', 'out/raw/achv3-step-by-step.png', 'refs/panda-celebrate.png']

PROMPT = """Bùbù for an ACHIEVEMENT BADGE in the app, shown small (80 to 100 pixels), so it must read at a glance: Bùbù {what}

ONLY Bùbù and his one prop, NOTHING behind him: no badge shape, no circle, no ground, no scenery (the app puts him on the badge). Draw him BIG: he fills about 85% of the canvas height, centred, his head in the upper part. The app stands him inside a badge shape that hides the lower part of his legs, so keep the action - his face, his paws and his prop - in the top 60% of the canvas, and make it lively: a clear pose and a strong, happy expression. His prop may reach out towards the edges.

STICKER SIMPLE, EXACTLY like Bùbù in the first two attached images (ignore the shape behind him there): big bold flat shapes, very few details, one or two flat tones a colour, no texture, no grain, no fine lines, no small patterns, no outlines, no glossy highlights.

Bùbù, clearly him (the third attached image): a chubby baby panda, a big round cream-white head about as wide as his body, charcoal round ears, charcoal eye patches with happy arched eyes, a small black nose, rosy blush cheeks, a little white tuft of fur on top, charcoal arms and stubby legs, a cream belly, and his small coral-red backpack.

Palette: muted and warm, as the app: jade and teal greens, warm cream, terracotta red, soft orange, soft gold, warm greys, charcoal for the darkest. Nothing in the family's badge colour ({colour}) is needed: the badge behind him will be that colour, so keep his prop a different colour from it where you can.

Background: one flat, solid pure magenta (#FF00FF) filling the whole canvas, with no gradient, vignette, texture, glow or shadow on it, so it can be cut out cleanly. Do not use any magenta or hot pink inside the artwork itself. Crisp clean edges against the magenta, no soft halo. No text, no letters, no numbers, no watermark, no border, no frame."""

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

new = [{"file": f"out/raw/achv4-{n}.png", "group": "achievements4", "size": "1024x1024", "refs": REFS,
        "prompt": PROMPT.format(what=what, colour=colour)} for n, what, colour in badges]
added = [j for j in new if j['file'] not in have]
jobs += added
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('added', len(added))
