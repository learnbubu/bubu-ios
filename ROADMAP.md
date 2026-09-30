# 步步 Bùbù roadmap

What's left to build across the website (`chineseLearning/app`) and the iPhone app (`bubu-ios/native`), and the risks we spotted comparing Bùbù with Duolingo. Tick things off as they land.

_Started 28 Sep 2026, after the buns, coins and red pockets release (web v288, app build #35)._

## Next up

- [x] **Soften buns for beginners.** _App: the first try at a word just met is free._ 5 buns can run out in a single ~11-exercise lesson, and Chinese beginners miss a lot. Options: first try at a brand-new word is free / one free mistake per lesson / buns only count from the second lesson of the day.
- [x] **Hide Plus in App Store builds** _App: `ProgressStore.plusForSale` (false; `-plusShop` turns it on in debug)._ until it can actually be bought. Apple rejects "coming soon" placeholders (guideline 2.1).
- [x] **Reminder notifications** ("Bùbù's hungry, keep your 12-day streak"). Neither the website nor the app has any.
- [x] **Sign-in and cloud sync in the app** (the website already syncs through Supabase). Settings → Account: the same account, table (`progress`), payload and merge as the website, so both show the same progress. Pulls on sign-in, launch and coming to the front; pushes 4 s after changes; retries quietly when offline.
- [x] **Full account deletion (done 28 Sep 2026: `delete_user()` added in Supabase; the app deletes the progress row, then the sign-in)**. Was: (server piece missing; Apple requires it, guideline 5.1.1(v)).** The app's "Delete account…" can only erase the `progress` row (the table's row-level-security policy allows a user to delete their own row) and sign out. Deleting the sign-in itself (the row in `auth.users`) needs the service_role key, which must never be in a client. Needed on the Supabase project, one of:
  - a Postgres function callable as `POST /rest/v1/rpc/delete_user` (`create function public.delete_user() returns void language sql security definer set search_path = '' as $$ delete from auth.users where id = auth.uid(); $$;` then `revoke all on function public.delete_user() from public, anon; grant execute on function public.delete_user() to authenticated;`; `progress` goes with it through `on delete cascade`), or
  - an Edge Function that checks the caller's JWT and calls `auth.admin.deleteUser(uid)` with the service_role key held server-side.

  Then call it from `Cloud.deleteCloudData()` (native) and add the same button to the website's Account box.
- [ ] **Password reset.** Neither the website nor the app has "Forgot password?". Supabase's `POST /auth/v1/recover` sends the email, but its link lands on the website, which has no screen for choosing a new password yet. Build that page on the website first (and add the app's URL to the project's redirect allow-list if the app should handle it).

- [x] **Learn tab lag on switching tabs** (reported from TestFlight). _App: the path's layout and pebble trail are worked out once (`PathModel`) instead of on every render; only the stretch near the screen is drawn instead of all ~365 stones; the path no longer re-renders for XP, quests or coins; it scrolls to the current stone the first time and when it moves on, not on every visit; Home's scenery parallax no longer re-renders all of Home each scroll frame._ Check on a real iPhone.
- [x] **No "Back up your progress" banner** on the path, and no "Coming from the website? Restore a backup" on the welcome screen. _App: sign-in and sync live in Settings; Export/Restore backup stay in Settings._

## Lesson flow (from testing on a real iPhone, 28 Sep 2026)

- [x] **Sentences too hard.** A sentence exercise only uses a sentence whose words have all been met (a record, or met earlier this session), apart from the card's own word and little particles (了 吗 呢 吧 啊 哇 …); ≤ 8 words preferred; otherwise another exercise. _App: `Course.sentences(for:met:)`; web: `usableSentences`._
- [x] **Lessons come in steps.** A lesson's batches of new words are its steps: "1/2" on the current stone, "Step 2 of 2" on the lesson sheet, "Step 1 of 2 done" and **Next step** after a step, "Lesson complete!" after the last. _App: `StudySession.lessonSteps`; web: `lessonSteps`._
- [x] **The last step always finishes the lesson.** It now brings back every word of the lesson not yet got right (a session left half-way), not just four reviews. The owner's "next stone didn't open" was the batch confusion; this was a rarer real gap.
- [x] **One session = one stone, words before phrases.** Stone 2 taught 这个用中文怎么说 and 我不懂 as single words on day one, and stones held 7–16 new words (two sessions each). The course exporter (`bubu-course/sequence.py`, see its `docs/sequencing.md`) now cuts stones to at most five new items, opens with short words (你 好 你好 谢谢 我), and teaches a phrase only after each of its words (brought forward if the course teaches it later). 365 lessons became 783 stones. Card ids don't change; old lesson ids finish their stones through `oldlessons.json` (_App: `Backup.migrateDone`, on load, restore and sync; web: `restoneDone` in `migrateOldDone`, v294)._
- [x] **Chapter 1 teaches less at once** (29 Sep 2026, web v295). Testing showed the sequenced chapter 1 (49 items) was still too much, with too much shown per word. Chapter 1 is now shaped by hand in `bubu-course/sequence.py` (`CH1`): 你 好 你好 · 我 是 · 谢谢 再见 · **practice** · 叫 什么 名字 · 很 高兴 认识 · 吗 也 呢 · **chapter review**. Its other items moved on: the survival phrases open chapter 2 (languages), the rest of unit 1 opens chapter 3. Card ids unchanged; v294's stones in chapters 1–3 are retired and map to the new ones (`oldstones.json`, `Backup.migrateDone`).
  - **Practice stones** (`kind: "practice"`): no new words, ~15 exercises (was ~10) on the chapter so far (the review: the whole chapter), weaker words first; not on buns, right answers earn buns back; a ↻ mark and 练/复 on the stone; their own lesson sheet. _App: `StudySession.practiceQueue`, `Course.practiceScope`; web: `practiceCards`._
  - **One new word at a time**: a card with big characters, pinyin, a short meaning and its sound played once, then straight into an easy exercise on it (`meetGroup = 1`). How it's built is behind a tap.
  - **Short meanings** (`short`, `Word.gloss`) for the old chapter 1's ~50 items, used on the meet card, in options and feedback; the full meaning stays on the character sheet. Wrong options for a tiny stone come from nearby stones, not the whole course.
  - **Less clutter**: a stone's notes show once as a tip before it starts (folded on the lesson sheet afterwards); "What are tones?" only for the first three sessions or until tapped; the "how it's built" feedback hint only early on; no "mixed skills · spaced repetition" or lock line on the sheet.
- [x] **Lessons are Duolingo-length** (29 Sep 2026, app only; branch `lessonlength`). A stone's session was ~8 exercises; it's now ~15 (`StudySession.stoneLen`). Each new word comes up 3–5 times (`newRepsMin/newReps/newRepsMax`), never twice in a row, climbing its own ladder (`newWordLadder`: recognise → listen/pinyin → recall/sentence → the harder kinds again), with the kinds of exercise alternating; earlier words fill the rest as review, due ones first, then the weakest (`reviewsWanted`). The first stone (你 · 好 · 你好) has no earlier words, so its words come up 5 times each; stones 2–3 bring their few earlier words round twice. Only a word's first two right answers in a session schedule it (`scheduledPerSession`), so the extra practice doesn't push its first review out. Practice stones are ~15 too. Reviews, mistakes and the other modes are unchanged. _Tests: `LessonLengthTests` (stone 1's exact sequence is in there). Check on the phone._
- [x] **No tone questions before the tones** (29 Sep 2026, app only). "Which pinyin is correct?" is never asked before chapter 1's first practice stone (stone 4, `StudySession.tonesStone`), where the four tones are introduced once on a card before the first exercise (the tones primer, with its sounds; remembered as `tonesSeen`). Stones 1–3 use recognise, listen and recall (and a sentence once one is usable).
- [x] **Beginner helps** (29 Sep 2026, app only; branch `beginner2`).
  - **Tap the pairs** (`MatchView`, `StudySession.Item.match`): 4–5 words already met in two columns, characters (pinyin under a word still new) beside short meanings; a right pair turns green and fades, a wrong one shakes and flashes red and costs nothing (no bun, no XP, no mistake saved). Once about two-thirds of the way through every stone with 4+ words known or just met (after its last new word), never in stone 1 (three words); twice in a practice stone (half-way, and at the end, where it pairs sounds with characters once every word is past its first rung and listening is on), in place of two of its exercises. A right pair counts as a right answer for XP and the quest counters; only a word's first two right answers in a session reschedule it (`scheduledPerSession`). The whole match is one step of the progress bar, which creeps through it a pair at a time. _Tests: `BeginnerTests`._
  - **"You learned"** on the done screen's first stage (`WordRecap`), in place of "This week" (the fire stage shows it next): the stone's new words with pinyin, short meaning and a speaker; a practice stone shows "You practised" with up to six words.
  - **A memory hook on the meet card** (`MemoryHook`): one line under the meaning, e.g. "好 = 女 woman + 子 child → good", written by hand for chapter 1's 16 words (none for 什么 and 也), otherwise built from `CharData`'s parts or from a phrase's words; the full breakdown stays behind "How it's built". Check on the phone.
- [x] **Help for total beginners** (29 Sep 2026, app only; branch `beginner1`). _App: `Model/Beginner.swift`._
  - **Pinyin training wheels**: pinyin over the Chinese in exercises (prompt, recall options, sentence words and tiles, feedback) while a word is new; once it's strong (right 3 times, or reviews 3+ days apart: `TrainingWheels.strongReps/strongDays`) it's hidden and a tap shows it. Never on "Which pinyin?" or before a listening answer. Settings → Pinyin: Auto / Always / Hide when known (only until it's been got right once); the old "Show pinyin" off becomes Hide when known.
  - **Hear it**: an exercise's Chinese plays once as it appears unless that gives the answer away (recall, building the Chinese and "Which pinyin?" wait for the answer); the feedback plays the right Chinese; a 🐢 beside every exercise speaker plays at 0.6× the chosen speed (the old slow rate was fixed, so no slower for someone who'd turned the speed down). Settings → Play audio automatically. _Note: audio still uses the `.playback` session, which plays through the silent switch._
  - **Gentler corrections**: "Close! 好 is hǎo — 3rd tone (you chose hào — 4th)", "你 means 'you'. (他 is 'he')", look-alikes as before ("So close: those two look alike!"). _Tests: `BeginnerTests`._ Check on the phone.
- [x] **Four of Duolingo's habits** (29 Sep 2026, app only; branch `batch`; gaps 3, 2, 4 and 6 of `docs/duolingo-teardown.md`). Not compiled or run yet: written on Windows, to be built and tested on the Mac.
  - **Pick, then Check**: in multiple choice (the quiz and the skip test too) a tap selects an option, another tap moves the selection, and the bottom button reads Check until it's pressed; only the option checked counts, so a slip of the thumb costs nothing (`ChoicePick` in `Model/Beginner.swift`; `select`/`checkChoice` in `StudyView`). The button's slot is the one Continue already had.
  - **"Can't listen now"** under a listening exercise: skipped with no bun, mistake or XP, no more listening for the session (`StudySession.listeningOff`, `skip()`), and the word comes back as another kind. A session of only listening ends there; if nothing had been answered it just closes and earns nothing.
  - **Tap to hear**: a Chinese option (recall) or sentence tile is said as it's selected; never in a listening exercise before it's answered. One switch, `TapToHear.enabled`; it also follows Settings (Sound effects and Play audio automatically both on). _Rests on a single source in the teardown: check it against Duolingo on a phone._
  - **Missed words come back at the end**: a wrong answer waits in `StudySession.retries` until the planned exercises are done, then comes back labelled "Previous mistake", never straight after the miss while anything else is left (`nextRetry`). It still comes back as a freshly picked kind of exercise, not the kind it was missed in.
  - _Tests: `CheckBatchTests`._ Check on the phone: the selected option's look, the "Can't listen now" row under four options on a small screen, and the label.
- [ ] **Generalise chapter 1's shape to every chapter**: stones of 2–3 new items, a practice stone every 3 stones and a chapter review, short meanings for every word (write them in `bubu-course/glosses.py`, or generate and review), notes on the stone that needs them everywhere.
- [x] **Writing as smooth as the website's** (reported from a real iPhone: "badly done, not as smooth as the web"). _App: the pen is a UIKit surface (`InkCanvas`) drawing every coalesced and predicted touch as smooth curves through the samples' midpoints (`InkGeometry`), with no SwiftUI re-render per sample, and 120 Hz allowed (`CADisableMinimumFrameDurationOnPhone`); a right stroke's ink fades as the real stroke draws in along its centre line (HanziWriter's reveal), a wrong one flashes red and goes, the hint traces the next stroke (again at each further miss), and the finished character lights up once before the tick. Stroke checking is unchanged: already HanziWriter's own thresholds at the web's leniency 1.4._ Feel-check on a real iPhone, including drawing inside the scrolling lesson and the writing sheet.
- [x] **Writing for someone who has never written hanzi, with a brush-like pen** (29 Sep 2026, app only; branch `writing2`; owner on an iPhone 15 Pro: lines "need to be smoother", and the first times should "show everything"). _App: the help goes by how many times each character has been written (`ProgressStore.timesWritten`, kept in the activity record so it syncs and backs up; `WriteGuidance`). 1st time: the strokes play in order (now started from a `task`, so they really play on first appearance), the pale outline stays, and the next stroke is lit up (a soft glow, a dot where it starts, an arrow its way). 2nd: the pale outline; a stroke's highlight after one miss on it. 3rd on: a blank grid; the highlight and trace after two misses. "Show me" replays the strokes any time; the writing sheet's trace row uses the same highlight. The pen is a brush (`InkGeometry.brushPath`): a filled outline around a Catmull-Rom centre line, 5–11 pt from the speed (low-pass filtered), tapered at touch-down and to 35% over the last 12 pt at the lift, round ends. The scroll view around the box no longer holds a stroke's first touch back ~150 ms (`delaysContentTouches` off while a box takes strokes, and its pan paused while a stroke is down)._ Feel-check on the phone: the brush's widths and tapers, the highlight, and scrolling past the box.
- [x] **Done screen without the empty space** (app): content from the top, a smaller panda, this week's streak strip on the first stage, the buttons pinned at the foot.
- [x] **Speaking like Duolingo's, and only words you've met** (29 Sep 2026, app only; branch `speak`; owner on an iPhone: "we're saying things that we haven't learnt yet", 你姓林吗？ before 姓 and 林). _App: a speak exercise asks for the card's own word, or now and then a sentence of at most 6 words whose every word has been met, the card's own included (`Course.speakSentences`, `Exercise.speak`). Never in a word's first session (`StudySession.maySpeak`); "Can't speak now" or no microphone ends speaking for the session; a speaking-only session takes the words already met. `SpeakView`: a wide "Tap to speak" button (face and base drawn together, fixing the misaligned red "Listening…" pill) that shows a live 7-bar waveform from the microphone's level while listening (tap again to stop), then the phrase with each character green if heard or red if missed (`SpeechScore.marks`, homophones counting, since tones aren't judged), "Nice!" or "Not quite — try again" with up to 2 retries; no permission or no recogniser says so and skips without penalty._ _Tests: `SpeakTests`._ Check on the phone.

## Before the App Store

- [x] Apple Developer membership active (28 Sep 2026)
- [x] TestFlight: app record in App Store Connect, API key into Codemagic, builds upload automatically _(first upload 28 Sep 2026; run `python tools/cm.py run testflight main`)_
- [ ] Buying Plus in the app with StoreKit (subscription), then turn the Plus rows back on
- [ ] Privacy policy (a URL is required) and the App Store privacy labels
- [ ] Wardrobe items to spend coins on (art needed)

## Economy and balance

- [ ] **Coins are scarce.** _App: streak milestones now pay 20–500 coins; daily-quest coins still to do._ About 30 a day free against a 350-coin batch is roughly 2 weeks of lessons per refill. Also give coins for streak milestones and daily quests.
- [x] **Free players can't buy embers.** _App: anyone can buy one below their cap (1 free, 3 Plus)._ Losing a long streak with no way to save it is a common reason people quit. Consider letting free players buy one ember at a time.
- [x] **Free-lesson loophole.** _App: any session that introduces new words is played on buns._ Home's general "Study" teaches new words without costing buns.
- [ ] Double XP is free for 15 min after every lesson and also sold for 200 coins. Is the shop one worth it?

## Missing features

- [x] App: drag sentence tiles to reorder them (currently tap in and out only)
- [ ] Home-screen widget showing the streak
- [ ] Leagues / weekly leaderboard (needs a server)
- [ ] Friends: friend streaks, friend quests, following
- [ ] Recorded native-speaker audio (we use the phone's text-to-speech; quality varies by voice, and tones matter)

## Voices (started 29 Sep 2026)

Recorded voices from Google Cloud Text-to-Speech (Chirp 3 HD), made once and kept in the app; the phone's own voice where there's no clip. Tools in `tools/`: `tts.py`, `voice.py`, `takes.py`, `citation.py`, `board.py`, `casting.py`.

- [x] Chapter 1 in Kore's voice (0.1.7), played untouched at its own speed (0.1.8)
- [x] The cast chosen by ear: `tools/cast.json` (Mark is Umbriel, Xiaoyu Sulafat, Chen Ming Puck, Bùbù the teacher Kore)
- [x] The four reference tones chosen by ear: `tools/refs/` (妈 麻 马 骂 in Kore's voice)
- [ ] Chapter 1's single characters re-read as a teacher says them (carrier sentence), matched to the reference tones, confirmed by ear
- [x] **Bùbù in a native speaker's voice** (30 Sep 2026, 0.1.10): the owner's partner recorded two short samples; CosyVoice 3 (free, Apache 2.0, on the owner's PC: `tools/clone/`) copies her voice from the cleaned teaching take. Chapter 1's 32 Bùbù clips remade in it and approved by ear: sentences said one at a time with a steady 0.45 s pause, single characters cut from carrier sentences, every clip cleaned (clicks, rumble and hiss out, faded ends, even loudness, 96k). The other speaker in a dialogue is still Google's Charon.
- [ ] Her own recordings of the 546 single-character syllables (`tools/record/`: script, brief, splitter), replacing the copied single characters; lines 1–10 first as a sound test
- [ ] A sentence script for her (the course's own lines, 10–30 minutes) to train a closer copy of her voice (GPT-SoVITS or CosyVoice fine-tuning)
- [ ] Each dialogue line in its speaker's voice: the speaker's name carried from the course source into `course.json`, clips made per speaker, the app playing a line in its speaker's voice
- [ ] Machine listening (Speech-to-Text) as a check on every clip: needs the API switched on and added to the key
- [ ] The whole course generated, every clip measured, the doubtful ones on sound boards
- [ ] A report button for audio in the app, before other people test it
- [ ] Slow audio: the same clip at 0.7 for now; separately made slow clips if that sounds poor

## Known limits

- [ ] **Path header over the art** (visual check, 29 Sep 2026): after stone 1 the pagoda runs up under the status bar icons and over the "GUIDE" tag beside "起步 1 · CHAPTER 1". Needs fixing by someone who can see the screen (the Mac's Simulator): banners drawn after the front scenery, and/or a short top fade over the status bar.
- [ ] **Visual check unfinished** (29 Sep 2026): stopped to save usage. Stones 1–2 of chapter 1 were looked at; stones 3–8 weren't. Screenshots on the Mac in `build/visual/A/`.
- [ ] Website: a very long sentence's word tiles spill over the Check button
- [x] Permanent bundle ID: `com.bubu` (registered 28 Sep 2026)
- [ ] Speaking practice checks the words, not the tones (Apple's recogniser), so a wrong tone can pass
- [ ] Website coin merging across devices is approximate when both are used on the same day
- [x] Opened pocket leaves a very faint glow where the pocket was (app)

## Decisions made (for reference)

- Buns: max 5, lost only for mistakes in sessions that introduce new words (not on a word's first try); one back every 4h, +1 per right answer in reviews/mistakes/trouble; fresh batch 350 coins; unlimited with Plus.
- Coins: start at 100. Red pocket (福) 20–35 for the first lesson each day (every lesson with Plus), 100 for finishing a chapter. Jade pocket (吉) +50 XP for all 3 daily quests.
- Shop: fresh batch 350, ember 250 (anyone below their cap), double XP 200 for 15 min, wardrobe coming soon.
- Embers: hold 1 free, 3 with Plus; existing extras kept.
- Streak milestones pay coins once per streak: 3→20, 7→50, 14→75, 30→150, 50→200, 100→300, 200→400, 365→500.
- One lesson a day keeps the streak; no daily XP target.
- Backups before this release: tags `backup-v286-before-rewards` (website) and `backup-before-rewards` (app).
