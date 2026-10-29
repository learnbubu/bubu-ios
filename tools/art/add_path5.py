"""Hook pieces, batch 5: real hanging decorations, from the owner's references.

The owner, 29 Oct 2026: people said some of the batch 4 hook pieces don't feel culturally appropriate. The cut ones
(straw hat, gong, abacus, teapot, steamer, birdhouse, fishing basket, cricket cage) were props strung up because they
read as "Chinese things"; nobody hangs them. The owner then sent references of things people really do hang (wind
bells under the eaves, palace lanterns, jade pendants, embroidered charms, seasonal blessing pendants, sachets):
"not as complex of course, but a good place to start". So every piece here is a decoration that is actually hung, drawn
simple, with the meaning it really carries. Wooden tags stay blank: no characters.

Same pipeline as batch 4 (add_path4.py): Codex draws one object on a cord, and hang.py hangs it from a master.
Replaces any path5 jobs made before; Codex makes only that group (PATH5.md).
"""
import json
import make_prompts as mp
from add_path3 import NOTE, slug
from add_path4 import SIMPLE, SHAPE, AVOID

KNOT = "a small Chinese knot tied in the cord just above it"
# (name, what it is, the master it hangs from)
OBJECTS = [
    # wind bells, the kind hung under temple and house eaves
    ("Twin wind bells", "two small dark bronze bells hanging one under the other on the cord, a slim dark tassel under "
     "the lower bell", "roof-eave"),
    ("Cone wind chime", "a little bronze canopy like a tiny roof with three cone-shaped bronze bells hanging under it, "
     "and one round bronze disc hanging below them in the middle", "iron-scroll"),
    # the hexagonal palace lantern (gongdeng)
    ("Palace lantern", "a hexagonal palace lantern: a dark wooden frame with curled corners at the top, white paper panels, "
     "and a long red tassel under it", "roof-eave"),
    # jade pendants (yupei)
    ("Jade disc", f"a round white jade disc with a hole in the middle (a bi), {KNOT}, a red tassel under it", "cloud-bracket"),
    ("Ruyi jade", f"a pale green jade pendant shaped like a ruyi cloud, {KNOT}, two round amber beads under it and a dark "
     "green tassel", "jade-bracket"),
    ("Jade rings", "three pale green jade rings threaded flat on the cord one above the other, a round red bead under them "
     "and a red tassel", "bamboo-pole"),
    # embroidered charms; the persimmon and the koi are wishes (shishi ruyi, niannian youyu)
    ("Persimmon charm", f"a plump round orange persimmon sewn in silk, with green leaves on top, {KNOT}, a green tassel "
     "under it", "dragon-head"),
    ("Koi charm", f"a red and cream koi fish sewn in silk, hanging head up, {KNOT}, a red tassel under it", "brass-rod"),
    ("Flower medallion", f"a round embroidered medallion with one big red and gold flower on it, {KNOT}, a cream bead "
     "and a brown tassel under it", "stone-corbel"),
    # the four seasons' blessing pendants, without their characters
    ("Lotus fan charm", "a fan-shaped pale green pendant with one pink lotus flower on it, a small blank wooden tag and a "
     "green tassel under it", "jade-bracket"),
    ("Moon rabbit charm", "a round cream pendant showing a little white rabbit under a pale gold moon with a sprig of "
     "orange osmanthus, a small blank wooden tag and an orange tassel under it", "cloud-bracket"),
    ("Plum lantern charm", "a pink pendant shaped like a round lantern with red plum blossoms on it, a small blank wooden "
     "tag and a pink tassel under it", "dragon-head"),
    # a sachet (xiangnang), green this time, beside the red one already kept
    ("Bamboo sachet", f"a soft green silk drawstring pouch with a few bamboo leaves sewn on it, {KNOT}, a green tassel "
     "under it", "bamboo-pole"),
]


def main():
    jobs = [j for j in json.load(open("jobs.json", encoding="utf-8")) if j["group"] != "path5"]
    add = []
    for t, d, mount in OBJECTS:
        s = slug(t)
        add.append({"file": f"out/raw/obj-{s}.png", "out": f"hang-{s}", "mount": mount, "group": "path5", "size": "1024x1536",
                    "refs": ["refs/ref-hang-hanging-lanterns.png", "refs/ref-hang-chinese-knot.png"],
                    "prompt": f"{NOTE}\n\n{mp.STYLE}\n\n{SIMPLE}\n\nCreate a hanging decoration: {d}. {SHAPE}\n\n{AVOID}\n\n{mp.KEY}"})
    json.dump(jobs + add, open("jobs.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
    print(len(add), "objects;", len(jobs) + len(add), "jobs in all")


if __name__ == "__main__":
    main()
