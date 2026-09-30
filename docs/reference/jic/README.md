# The JIC edition: the look to match

Screenshots of the web app at `jic-edition-v276` (chineseLearning/app), at iPhone size
(375 x 812 points), taken on 30 Sep 2026. The owner calls this the best-looking version, and
the native app's layout should match it. The web app has drifted since then and is broken too,
so don't use it as the reference.

- `1-home.jpg`: Home. The pagoda scene is top right; the panda peeks out of the streak card;
  the "Continue learning" card has the lantern-house scene behind it.
- `2-path-top.jpg`: the top of the path. A slim header with two small pills and a settings
  button, then the chapter title and progress. The temple cluster sits **below the header, to
  the right of stones 1–2**, and never under the title or the status bar. The walking panda is
  beside stone 2, and bamboo, a lantern and flowers are on the left by stones 3–4.
- `3-path-chapter2.jpg`: a chapter header (right-aligned) in open space between stones. The
  sleeping panda is by a stone, and a pagoda roof starts at the bottom right.
- `4-path-unit-b.jpg`: the tall pagoda to the right of two stones, **above** the next unit's
  header (left-aligned), not over it.

To run it again: `git worktree add <dir> jic-edition-v276` in chineseLearning/app, serve the
folder (`python -m http.server`) and open it at 375 x 812.
