"""Image prompts for Bùbù's art, for ChatGPT image generation, in the house style:
scenery corners and hanging pieces, landmark vignettes, panda poses, and the picture-card
sheets (4×4 grids, from picture_sheets.json). Writes prompts.json for the prompt page."""
import json
import os

HERE = os.path.dirname(os.path.abspath(__file__))
data = json.load(open(os.path.join(HERE, "picture_sheets.json"), encoding="utf-8"))

STYLE = ("Style: Bùbù house style. Flat, soft storybook vector illustration with gentle rounded shapes and a faint paper-grain texture. "
         "No outlines; shapes are defined by colour with 2–3 tones of soft shading. Muted, warm palette: jade and teal greens (#2E7A6B, #3E9A82, sage #8DB596), "
         "warm cream (#F6F1E4), terracotta/coral red (#D9654B), soft orange (#E8955A), warm greys for stone (#A9A9A2), charcoal (#2B3036) for the darkest tones, "
         "pale blush cheeks. Calm, friendly and slightly whimsical, like a picture book set in a Chinese garden.")
# scenery is SIMPLE (the owner's references, 5 Oct 2026: 'too detailed'): few elements, big shapes
SIMPLE = ("Keep it SIMPLE, like the attached references: only a few elements (one tree or feature, two or three rocks, a few leaf clusters and "
          "three to five small cream flowers), each a big simple shape with a flat fill and at most one soft lighter tone. No fine texture, no small "
          "detailed leaves, no dense undergrowth, no tiny repeated details. Soft, slightly muted greens. Generous empty space between elements.")
KEY = ("Background: one flat, solid pure magenta (#FF00FF) filling the whole canvas, with no gradient, vignette, texture, glow or shadow on it, "
       "so it can be cut out cleanly. Do not use any magenta or hot pink inside the artwork itself. Crisp clean edges against the magenta, no soft halo. "
       "No text, no letters, no numbers, no watermark, no border, no frame.")
PANDA = ("Character: Bùbù, a chubby baby panda. Cream-white face and belly; charcoal ears, eye patches, arms and legs; a little white tuft of fur on top of the head; "
         "a small black nose; rosy blush cheeks; simple happy arched eyes unless the pose says otherwise; and always a small coral-red backpack with straps. "
         "Keep the same proportions: a big round head about as wide as the body, short stubby legs, no outlines.")

CORNERS = [
    ("Pine on rocks", "a Chinese pine with three or four flat cloud-shaped foliage pads leaning out over two smooth grey rocks"),
    ("Lotus pond edge", "the edge of a lotus pond: three big round lily pads, one cream lotus flower and a bud, a smooth stone"),
    ("Stone lantern", "a weathered Chinese stone lantern with a little warm glow inside, moss, ferns and small round shrubs around its base"),
    ("Weeping willow", "a weeping willow with long drooping green fronds hanging over a strip of water and a few stepping stones"),
    ("Ginkgo in autumn", "a ginkgo tree with golden fan-shaped leaves, a few leaves falling, rocks and low shrubs at its base"),
    ("Tea terraces", "a corner of terraced tea bushes in neat rounded rows on a hillside, with a small path and a stone"),
    ("Karst rocks", "tall misty limestone karst rocks like Guilin, a small pine growing from one ledge, soft pale-green mist"),
    ("Peonies", "a lush peony bush with big cream and coral peony flowers and dark green leaves beside a rock"),
    ("Moon gate wall", "a section of whitewashed garden wall with a grey tiled top and a round moon gate, bamboo peeking through, a stone step"),
    ("Koi pond", "a koi pond corner with two orange-and-white koi under the surface, rocks around the rim, a small fern"),
    ("Bonsai on plinth", "a small bonsai pine in a glazed teal pot on a stone plinth, with a few pebbles and moss"),
    ("Winter plum", "a plum branch in winter with coral-red blossoms and soft snow on the branches and on the rocks below"),
    ("Osmanthus", "an osmanthus tree with clusters of tiny golden-orange flowers, rounded shrubs and rocks at its base"),
    ("Bamboo grove (fuller)", "three tall bamboo stalks with a few leaf sprays and one rock"),
]
HANGERS = [
    ("Hanging lanterns", "a string of three round red Chinese lanterns with gold tassels hanging from a branch that enters from the top-left corner"),
    ("Hanging wisteria", "pale lilac-and-cream wisteria flowers hanging down from a branch entering from the top-left corner (no pink or magenta tones)"),
    ("Hanging willow fronds", "long willow fronds hanging down from the top-left corner"),
]
SCENES = [
    ("Paifang archway", "a traditional Chinese paifang memorial archway with teal-tiled roofs and coral-red pillars, trees and a soft pale-green mountain behind, a cream path"),
    ("Stone bridge and willow", "a Suzhou-style stone arch bridge over a canal, a weeping willow, whitewashed houses with grey-tiled roofs"),
    ("Teahouse", "a small wooden teahouse with a teal roof, red lanterns at the eaves, a bench, and a teapot steaming on a table outside"),
    ("Great Wall", "a section of the Great Wall winding over green hills, with a watchtower and soft mist"),
    ("Round hall", "a round three-tiered hall with teal-blue tiled roofs on a white stone terrace (inspired by the Temple of Heaven, simplified)"),
    ("Courtyard gate", "a siheyuan courtyard gate with red double doors, brass knockers, grey brick walls and a tree peeking over"),
    ("Mountain pavilion", "a small pavilion perched on a green mountain ledge beside a thin waterfall, with pines"),
    ("Night-market stalls", "a cosy row of night-market stalls with glowing lanterns and steaming food, warm light, as a cut-out shape rather than a full sky"),
    ("River boat", "a small wooden boat with a curved canopy on calm water, a lantern hanging at the front, reeds"),
]
PANDAS = [
    ("Thumbs up", "giving a big thumbs up with a proud grin"),
    ("Trophy", "holding a small gold trophy up above its head, delighted"),
    ("Red envelope", "opening a red envelope (hongbao) with sparkles coming out, amazed"),
    ("Streak fire", "standing proudly next to a small friendly campfire flame, paws on hips"),
    ("Shivering with an ember", "wrapped in a coral scarf, shivering a little, holding a tiny glowing ember in its paws"),
    ("Speaking", "talking happily into a vintage microphone, with an empty speech bubble"),
    ("Tones conductor", "conducting with a little baton, four gentle wavy lines floating around it like music"),
    ("Flashcards", "holding a fan of flashcards, thinking, one paw on its chin"),
    ("Quiz", "sitting at a small desk with a pencil and a test paper, concentrating, tongue poking out a little"),
    ("Yawning at night", "yawning in a nightcap, holding a small lantern, with a crescent moon behind"),
    ("Tea break", "sitting and sipping from a small teacup, steam rising, content"),
    ("Running", "running eagerly with its backpack bouncing, little motion lines"),
    ("Surprised", "jumping back surprised and delighted, eyes wide open with sparkles"),
    ("Idea", "pointing up, with a glowing lightbulb above its head"),
    ("Traveller", "holding a folded map and pulling a tiny suitcase"),
    ("Waving goodbye", "waving goodbye over its shoulder while walking away"),
    ("Heart", "hugging a big soft coral heart"),
    ("Meditating", "sitting cross-legged, meditating peacefully, eyes closed, a small leaf floating by"),
    ("Kite", "flying a small kite shaped like a fish"),
    ("Blank sign", "holding up a blank cream sign with both paws (leave the sign completely empty)"),
    ("Fixing a mistake", "rubbing out a mistake on paper with a big eraser, determined"),
    ("Noodles", "eating noodles with chopsticks from a bowl, slurping happily"),
    ("Lantern festival", "holding a round red lantern on a stick, cheerful"),
    ("Peeking from the right", "peeking in from the right edge of the frame, only half its body visible"),
]

corner = [{"t": n, "p": f"{STYLE}\n\n{SIMPLE}\n\nCreate a decorative scenery corner: {d}. Anchor the artwork to the BOTTOM-LEFT corner so it fills only the left 55% of the canvas, rising to about 85% of the height at the far left and tapering down to the bottom towards the right, like the attached corner pieces. The right side and the top right stay empty magenta. Portrait canvas, 4:5.\n\n{KEY}"} for n, d in CORNERS]
hang = [{"t": n, "p": f"{STYLE}\n\n{SIMPLE}\n\nCreate a hanging decoration: {d}. Anchor it to the TOP-LEFT corner and keep it in the top-left area, so it can hang into a screen from above. Portrait canvas, 4:5.\n\n{KEY}"} for n, d in HANGERS]
scene = [{"t": n, "p": f"{STYLE}\n\n{SIMPLE}\n\nCreate a free-standing landmark vignette: {d}. Centre it on a small cream ground patch, with a soft rounded sticker-like silhouette (no full sky, no full-bleed background). Landscape canvas, 3:2.\n\n{KEY}"} for n, d in SCENES]
panda = [{"t": n, "p": f"{STYLE}\n\n{PANDA}\n\nPose: Bùbù {d}. Full body, centred, with generous margin all round. Square canvas.\n\n{KEY}"} for n, d in PANDAS]
sheets = []
for i, sh in enumerate(data["sheets"]):
    lines = "\n".join(f"{k + 1}. {it['d']}" for k, it in enumerate(sh))
    rows = (len(sh) + 3) // 4
    sheets.append({"t": f"Picture sheet {i + 1} of {len(data['sheets'])}", "words": " · ".join(it["w"] for it in sh), "p":
                   f"{STYLE}\n\nCreate a sticker sheet of {len(sh)} small picture icons for a language-learning app, in a neat grid of 4 columns × {rows} rows, read left to right and top to bottom, in exactly this order:\n{lines}\n\n"
                   "Each icon is one simple, instantly recognisable object or scene, centred in its own equal-sized cell with plenty of empty space around it, all at a similar size, never touching or overlapping a neighbour. "
                   "People are cute chibi characters in the same style (big heads, small bodies, simple happy faces, a mix of skin tones). Square canvas.\n\n" + KEY})
json.dump({"corners": corner, "hangers": hang, "scenes": scene, "pandas": panda, "sheets": sheets},
          open(os.path.join(HERE, "prompts.json"), "w", encoding="utf-8"), ensure_ascii=False)
print(len(corner), len(hang), len(scene), len(panda), len(sheets))
