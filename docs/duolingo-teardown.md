# Duolingo exercise teardown: gaps in 步步 Bùbù

_29 Sep 2026. A short pass: how Duolingo's exercises behave, against the app as it is on branch `converse`. Research only; no code changed._

**How to read it.** "Unverified" means no source I read confirmed it (it's from memory of the app, or a single weak source): check it on a phone running Duolingo before building. File references are under `native/Bubu/`.

## Gaps, most valuable first

| # | What Duolingo does | What Bùbù does now | Suggested change | Size |
|---|---|---|---|---|
| 1 | **Listening is answered in the language itself**: "Tap what you hear", type or pick the missing word, match sounds to characters. No English involved. ([Duolingo: listening skills](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-listening-skills/)) | "What did you hear?" plays the word and offers four **English meanings** (`Exercise.choice`, `field()` in `Model/StudySession.swift`), so it tests meaning as much as hearing. Sound-to-character only exists in a practice stone's last match. | Add a listening kind whose options are characters (and later, tiles for a short sentence). | M |
| 2 | **"Can't listen now"**: listening exercises can be skipped when it's noisy, and switched off in settings. ([Duolingo 101](https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo), [settings toggle](https://www.hardreset.info/devices/apps/apps-duolingo/disable-listening-exercises/)). How long the skip lasts is unverified. | Only speaking has it ("Can't speak now", `Views/SpeakView.swift:69`, `StudySession.skip()`). A listening exercise has no way out but guessing, which can cost a bun. | Add "Can't listen now" under a listening exercise: no penalty, no more listening or automatic audio for the session. | S |
| 3 | **Pick, then Check.** An option is selected, can be changed, and only counts on Check. ([Usability Geek case study](https://usabilitygeek.com/ux-case-study-duolingo/)) | A tap on an option is the answer at once (`choose()` in `Views/StudyView.swift:301`; `ChoiceView.option`). A slip of the thumb is a mistake and a bun. Only sentences have Check. | Select on tap, answer on Check, for multiple choice. | S |
| 4 | **Tapping a word in the language says it**: options and word-bank tiles speak as they're tapped. (One teardown found in search: "as users select each option, a voice providing the pronunciation plays"; lightly verified.) | Character options and sentence tiles are silent when tapped: no speech call in the option or tile code of `Views/StudyView.swift`. Only the match's left column speaks (`Views/MatchView.swift:123`) and the new-word hint chip (`Views/Hints.swift:104`). | Say a Chinese option or tile when tapped, except where the sound is the answer (listening). Needs gap 3 first for options. | S |
| 5 | Audio is tied to the exercise, not the clock: a listening exercise always plays. | "Don't say it twice" is a 12-second rule on the text (`Speech.autoSpeak`, `repeatGap`, `Model/Audio.swift:71`). Two side effects, **read from the code, not seen on a phone**: (a) a listening exercise on a word said within the last 12 s (its answer just played, or the speaker was tapped) appears **silent**; (b) stay on the new-word card over 12 s and its first exercise says the word again. | Make the rule about events: skip the automatic prompt only for the exercise straight after the new-word card, and never for listening. | S |
| 6 | **A missed exercise comes back at the end of the lesson** ([Quora](https://www.quora.com/How-do-I-get-passed-wrong-answers-in-Duolingo-as-its-so-hard), weak source), as the same exercise, labelled "Previous mistake" (label and "same exercise" unverified). | The word goes to the end of the queue (`answer()`, `queue.append`), but comes back as a **freshly picked kind** of exercise (`next()` calls `pickDirection` again), with no label. A word missed last comes straight back. | Bring it back as the same kind it was missed in, with a small "Previous mistake" tag; if it was the last item, put one other word between. | S |
| 7 | **Fill the gap**: a sentence with one word missing, picked or typed; also "listen for the missing word". ([listening skills](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-listening-skills/), [exercise list](https://duolingo.fandom.com/wiki/Exercise) via search summary) | Seven kinds (`StudySession.allDirs`): recognise, recall, pinyin, listen, write, sentence, speak, plus the match. Nothing between "pick one word" and "build the whole sentence". | Add a gap-fill on sentences whose words are all met: an easier step before building the sentence. | M |
| 8 | **Encouragement inside the lesson**: a short character moment after several right in a row; on the newer energy system, 5 in a row also gives energy back. ([Tear Them Down](https://tearthemdown.medium.com/product-teardown-duolingo-gamification-for-retention-3a2a2dea1fd2), [duoplanet](https://duoplanet.com/duolingo-energy-system/)) | A small flame chip from 3 in a row and a sound at 5, with more XP (`topBar` in `Views/StudyView.swift:187`, `comboAt`). No moment on screen, nothing given back. | At 5 in a row in a lesson, a one-second Bùbù cheer; consider a bun back at 10. | S |
| 9 | **Speaking starts in the first lesson**, repeating words just taught. ([Duolingo: speaking skills](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-speaking-skills)) | Never in a word's first session (`StudySession.maySpeak`, `inFirstSession`), so the first stones have no speaking at all. Chosen after "we're saying things we haven't learnt yet". | Owner's call: allow speaking as a new word's last rung (its 4th or 5th time up), word only, never a sentence. | S |
| 10 | **Word bank or keyboard**: the learner can switch to typing for a harder go; units move from recognising to typing. ([Duolingo 101](https://blog.duolingo.com/duolingo-101-how-to-learn-a-language-on-duolingo)) | Tiles only (`Exercise.sentence`); no typed answers anywhere. | Later: typed pinyin for a single word as the top rung for strong words. | M–L |
| 11 | **Say the answer instead**: a microphone on translation exercises for extra speaking. ([speaking skills](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-speaking-skills)) | Speaking is its own exercise only (`Views/SpeakView.swift`). | Low priority; skip unless speaking becomes a focus. | M |
| 12 | After a wrong answer the button reads "Got it"; after a right one, "Continue". ([Medium user flow](https://medium.com/@raghadware/navigating-duolingo-a-step-by-step-user-flow-for-choosing-and-completing-a-lesson-14de76946aaf), lightly verified) | "Continue" both times, red or green (`bottomSlot`, `Views/StudyView.swift:286`). | "Got it" on a wrong answer. | S |

## Already matches

- **Speaking says the phrase first**, with a speaker and slow button, a waveform, per-character green/red, retries, "Can't speak now" (`Views/SpeakView.swift`). Duolingo's autoplay here is from the owner's phone, not a source I found.
- **A new word isn't said twice** in the normal case: the card says it, the first exercise doesn't (`Speech.autoSpeak`). See gap 5 for the edges.
- **No replay after answering** when the prompt was already said (`Autoplay.onAnswer`, `Model/Beginner.swift`).
- **Slow audio**: a turtle beside every exercise speaker, replay as often as wanted.
- **Nothing unlearned is asked**: sentences and spoken phrases use met words only; no tone questions before the tones.
- **Tap the pairs**, including a sounds-to-characters version, capped per lesson (Duolingo capped them too: [2020 post](https://blog.duolingo.com/improving-how-duolingo-teaches-chinese-and-other-languages/)).
- **Pinyin in hints and in the feedback**, new word highlighted with a tap hint (`HintChip`, `NewBadge`).
- **Feedback banner** shows the right answer and says what was different (`Correction`); right/wrong sounds and haptics.
- **Lesson length** ~15 exercises; easy kinds first, harder later (`newWordLadder`).
- **Progress bar** only moves on a right answer; a match is one step.
- **Done screen**: XP, time, accuracy, perfect bonus, streak, next lesson.
- **Practice earns lives back**: reviews and practice stones earn buns, as Duolingo's practice earned hearts.

## Different on purpose

- **Buns are lost only for mistakes.** Duolingo's phones are moving to energy, where every exercise costs one whether right or wrong ([duoplanet](https://duoplanet.com/duolingo-energy-system/)). Ours is kinder; keep it.
- **A separate new-word card.** Whether Duolingo has one, or only highlights the word inside its first exercise, is unverified. Ours was chosen for beginners in Chinese.
- **Writing.** Stroke-by-stroke writing with fading help (`Views/WriteView.swift`). Duolingo's character practice for Chinese (a characters tab, tracing) is unverified; its blog only describes tracing for Japanese.

## Not checked

- Duolingo's sound effects in detail, and whether it respects the silent switch (ours plays through it; already noted in `ROADMAP.md`).
- What a wrong pair costs in Duolingo's match.
- `Views/WriteView.swift`, `Views/MatchView.swift` and `Views/DoneView.swift` were only searched, not read in full.
- The Duolingo wiki's exercise page wouldn't load; its content here comes from a search summary.
