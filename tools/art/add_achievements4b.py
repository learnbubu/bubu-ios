"""Codex jobs: four of the achievement Bùbùs again (the owner, 19 Oct 2026): Seal Collector was stamping nothing,
Rekindled's mouth looked odd, Dressed Up's hood wasn't our Jade Dragon, and Night Owl's lamp hung out past the coin
(below the coin's rim only what's inside the coin shows). Their old pictures move to out/raw/_superseded/ so Codex
makes them anew; the prompts are add_achievements4.py's, with these poses."""
import json, os, shutil

jobs = json.load(open('jobs.json', encoding='utf-8'))
POSES = {
    "seal-collector": ("pressing a big jade-green seal stamp down onto a sheet of cream paper that lies flat in front "
                       "of him, the paper clearly there under the stamp, and beside the stamp on the paper a bold red "
                       "square seal mark already printed (a plain red square with a simple abstract pattern, NOT a "
                       "character).", "the stamp and the paper"),
    "rekindled": ("kneeling, holding a long thin lighting stick with a tiny flame at its tip up to a small DIM, unlit "
                  "red paper lantern held in his other paw at shoulder height, just about to light it, smiling with "
                  "his usual happy open mouth (the same mouth as in the first two attached images).", "the stick"),
    "night-owl": ("in a floppy teal nightcap, holding a small book open in one paw and a little glowing hand lantern "
                  "held UP beside his head in the other, a pale crescent moon by his ear. Everything he holds is up "
                  "level with his head, near the middle: nothing hangs down at his sides.", "the book"),
    "dressed-up": ("wearing OUR Jade Dragon costume hood, exactly as in the LAST attached image (copy its design): a "
                   "rounded green hood with darker green scalloped edges, a cream face opening ringed with small white "
                   "fangs, a light-green snout on top with two nostrils, two big round dragon eyes with white brows "
                   "above it, two yellow curved horns, a small red crest between them, red fins at the sides and thin "
                   "yellow whiskers. Simplify it to his sticker style; the hood may be a little smaller than in the "
                   "picture, but every part must be there and match. His paws up like little claws, roaring "
                   "cheekily.", "the hood"),
}
HOOD = 'refs/ref-jade-dragon-hood.png'
moved = []
for j in jobs:
    if j.get('group') != 'achievements4': continue
    fam = j['file'][len('out/raw/achv4-'):-4]
    if fam not in POSES: continue
    p = j['prompt']
    a = p.index('read at a glance: Bùbù ') + len('read at a glance: Bùbù ')
    b = p.index('\n\nONLY Bùbù')
    j['prompt'] = p[:a] + POSES[fam][0] + p[b:]
    if fam == 'dressed-up' and HOOD not in j['refs']: j['refs'] = j['refs'] + [HOOD]
    if os.path.exists(j['file']):
        os.makedirs('out/raw/_superseded', exist_ok=True)
        shutil.move(j['file'], 'out/raw/_superseded/' + os.path.basename(j['file']))
        moved.append(fam)
json.dump(jobs, open('jobs.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('moved aside', moved)
