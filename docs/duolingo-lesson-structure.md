# How a Duolingo lesson is built (Chinese course)

Research done on 1 Oct 2026, for the lesson shape in 0.1.20. Duolingo publishes no lesson template. The exercise types and the Chinese word lists are well sourced. Counts, proportions and order inside a lesson come mostly from secondary write-ups, or are inference; those are marked **unverified**.

## The findings

- **Length.** A lesson has about 15–17 exercises, and wrong answers add more [D1][W2]. Ours: about 15 (`StudySession.stoneLen`).
- **New words.**
  - Duolingo gives a new word no teaching card. It first appears inside an exercise, purple, tap for a hint. It then comes back in roughly the next three exercises [M1].
  - New words sit in sentences made only of known words [B1].
  - Ours: a meet card first (kept on purpose, chapter 1 testing), then the same rule for sentences (`Course.sentences(for:met:)`, `drills.py`).
- **Chinese specifically.**
  - Early lessons lean on sound↔pinyin and pinyin↔character matching [A1][R1].
  - In 2020 Duolingo capped repeats of one exercise type per lesson, because "Tap the pairs" kept coming back [B2].
- **First unit (Food).**
  - 3–4 new words a lesson: 茶 和 咖啡 水 / 米饭 汤 热 / 这是 豆腐 粥 [W3].
  - Sentences start as two-word phrases joined with 和 (水和茶), then grow into 这是 + noun.
  - The older first skill was 你 好 你好 · 再 见 再见 [W4].
- **Listening.** Early in a unit the audio comes with text; later it is audio only [B3].
- **Speaking.** From the very first lesson [B4]; its place in a lesson is unverified.
- **End of a lesson.** Mistakes are replayed at the end. A learner doing well gets the last 1–2 exercises swapped for harder ones [B1][D1].
- **Across a unit.**
  - A unit has 8–10 levels: lessons, personalised practice, stories and a review [D1][D2].
  - Levels once stressed different skills: introduction, then recognition, then speaking [S1].
- **Typing.** From level 2 the word bank can be swapped for the keyboard. Duolingo's own guidance goes single words → word bank → free typing [B2][B9].

## Exercise types, and whether Bùbù has them

| Duolingo | Bùbù |
|---|---|
| Write this in English/Chinese (tiles) | yes (`sentence`) |
| Tap what you hear (tiles, turtle replay) | yes, from 0.1.20 (`hear`) |
| Select the missing word | yes, from 0.1.20 (`gap`) |
| Tap the pairs (meaning, or sound) | yes (`MatchView`) |
| Which one is X? / select the meaning (a word) | yes (`recognize`, `recall`) |
| What do you hear? (pick the transcription) | words only (`listen`); a sentence version isn't built |
| Speak this sentence | yes, a little in lessons from 0.1.20 (`speak`) |
| Mark the correct meaning (choose a sentence) | no, by the owner's rule: whole sentences are never multiple choice |
| Typed translation / complete the translation | no |
| Character: what sound, build from parts, missing stroke | writing (`write`); the others no |
| Harder last exercises when doing well | no |

## A reconstructed early lesson (3 new words A, B, C)

The order is a reconstruction. Steps 1–3 and 15, the exercise types, and the 15–17 length are sourced. The split is about half word exercises, half sentence exercises.

1. Hear A, pick its pinyin or character.
2. Tap the pairs: A, B, C to their sounds.
3. Select the meaning of A, marked new.
4. Select the meaning of B, marked new.
5. What sound does this character make?
6. Write in English from tiles: a phrase with A (热水, 茶和水).
7. Select the meaning of C, marked new.
8. Write in Chinese from tiles: A 和 C.
9. Tap the pairs: characters to meanings.
10. What do you hear? A short phrase.
11. Fill in the missing word: 这是__.
12. Speak the phrase.
13. Tap what you hear.
14. Write in English: a reversed phrase.
15. A harder build, or the mistakes again.

## Sources

- [W1] https://duolingo.fandom.com/wiki/Exercise
- [W2] https://duolingo.fandom.com/wiki/Lesson
- [W3] https://duolingo.fandom.com/wiki/Chinese_Skill:Food
- [W4] https://duolingo.fandom.com/wiki/Chinese_Skill:Greetings_1
- [B1] https://blog.duolingo.com/keeping-you-at-the-frontier-of-learning-with-adaptive-lessons/
- [B2] https://blog.duolingo.com/improving-how-duolingo-teaches-chinese-and-other-languages/
- [B3] https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-listening-skills/
- [B4] https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-speaking-skills/
- [B9] https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-writing-skills/
- [D1] https://duoplanet.com/duolingo-learning-path/
- [D2] https://duoplanet.com/duolingo-levels/
- [S1] https://duoplanet.com/duolingo-legendary-levels-get-to-know-the-purple-crowns/
- [A1] https://allenwarren.me/2025/04/22/duolingo-chinese-course-review/
- [R1] https://www.alllanguageresources.com/duolingo-chinese-review/
- [M1] https://medium.com/language-learners-toolkit/duolingo-unleashed-decoding-the-secrets-behind-its-language-learning-magic-23255fb3f870

## In-lesson look and feel (research, 3 Oct 2026)

Sources: Duolingo's 2023 Method whitepaper, its blog, duoplanet, and design teardowns.

| Duolingo | Bùbù |
|---|---|
| Check → a banner slides up: pale green/red, correct answer with pinyin, one big button | yes |
| Progress bar eases forward on every answer | yes |
| Every missed item re-asked at the end; the lesson ends when all are right | yes (`retries`) |
| NEW WORD label in purple; new words recur from recognition to production | yes (and a meet card first, by choice) |
| Types capped per lesson; easy → hard; a no-word-bank "hard" translation near the end | caps and order yes; **no typed "hard" exercise yet** |
| "5 IN A ROW" badge with a bounce at combo milestones | yes, from 3 Oct 2026 (`FeedbackBanner.inARow`) |
| Ding/boing sounds and haptics | yes |
| Characters react; a big celebration for a perfect lesson | panda moods yes; perfect-lesson celebration to check |
| Closing mid-lesson asks first ("keep learning" / "end session"), with a sad Duo | yes, from 3 Oct 2026 (`QuitAsk`) |
| Speaker + turtle on listening; tiles speak and move to the answer line | yes |
| End sequence: Lesson complete (XP, accuracy, time) → streak → quests | yes (`DoneView`'s three stages) |
| Picture cards for nouns ("Which one is tea?") | **no** (needs art) |
| Keyboard instead of word bank from level 2 | **no** (typing is next) |
| Practice Hub: mistakes, words, listen, speak, stories | partly (the lesson sheet's practice and Home tiles) |
