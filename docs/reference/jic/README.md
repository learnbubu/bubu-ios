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

## Lessons and exercises

Match the **look** of these: the card, the panda teacher with a speech bubble, the colours,
type sizes, spacing, the answer rows and the Continue button. The **flow** has changed on
purpose, so don't copy it: new words are met one at a time (not the list in 06), you pick and
then press Check, and mistakes come back at the end.

- `05-lesson-sheet.jpg`: tapping a stone the first time. A bottom sheet with the stone's
  character in a circle, the title, a progress bar and "Start studying". The panda peeks over it.
- `09-lesson-sheet-skills.jpg`: the same sheet later, with "Study" and "or practise one skill"
  chips (Write, Pinyin, Listen, Sentences, Quiz, Browse the words).
- `06-new-words.jpg`: new words in JIC (a list). Look at each word's styling: tone-coloured
  hanzi, pinyin, meaning, the parts line, and the speaker button.
- `07-meaning.jpg`: "What does this mean?". The panda teacher on the left, the word in a
  bubble on the right with a NEW WORD tag and a speaker, tone-coloured pinyin under it, four
  full-width answer rows, and Continue at the bottom.
- `08-meaning-wrong.jpg`: after a wrong pick. The wrong row is outlined red, the right one
  green, and the Continue bar turns coral.
- `10-listen.jpg`: "What did you hear?". The bubble holds a big headphones icon and a speaker.
- `15-pinyin.jpg`: "Which pinyin is correct?". The word and meaning in the bubble, a
  "What are tones?" pill, and four pinyin rows.
- `11-tones-explainer.jpg`: the "What are tones?" sheet.
- `17-recall.jpg`: "Which characters mean this?". English in the bubble, and answer rows with
  hanzi over tone-coloured pinyin.
- `12-sentence.jpg`: "Translate this sentence". The sentence in the bubble, with pinyin over
  each word and dotted underlines; two answer lines; word tiles; Check.
- `13-write.jpg`: "Trace, then write it". A small character box with pinyin and meaning,
  a large grid, Clear, and "Next character (1/2) →".
- `16-speak.jpg`: "Say it out loud". The word in the bubble, pinyin and meaning, a
  "Tap and say it" button, "Can't speak now", and Continue.
- `14-quiz.jpg`: the quiz. The same card, with "Quiz · 15 questions" at the top.
- `18-home-practice.jpg`: Home's Practice section. Three rows (Fix your mistakes, Review,
  Weak words) with count badges, then eight coloured tiles, then "What to study".
- `19-tone-pairs.jpg`: Tone pairs. A big speaker, ½×, and four answer cards with tone
  strokes drawn in their colours.
