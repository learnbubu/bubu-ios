# 步步 Bùbù roadmap

What's left to build across the website (`chineseLearning/app`) and the iPhone app (`bubu-ios/native`), and the risks we spotted comparing Bùbù with Duolingo. Tick things off as they land.

_Started 28 Sep 2026, after the buns, coins and red pockets release (web v288, app build #35)._

## Next up

- [ ] **Soften buns for beginners.** 5 buns can run out in a single ~11-exercise lesson, and Chinese beginners miss a lot. Options: first try at a brand-new word is free / one free mistake per lesson / buns only count from the second lesson of the day.
- [ ] **Hide Plus in App Store builds** until it can actually be bought. Apple rejects "coming soon" placeholders (guideline 2.1).
- [x] **Reminder notifications** ("Bùbù's hungry, keep your 12-day streak"). Neither the website nor the app has any.
- [ ] **Sign-in and cloud sync in the app** (the website already syncs through Supabase). Until then, website and app keep separate progress, coins and buns, and a lost phone loses everything without a backup.

## Before the App Store

- [ ] Apple Developer membership active (enrolled 28 Sep 2026, waiting on processing)
- [ ] TestFlight: app record in App Store Connect, API key into Codemagic, builds upload automatically
- [ ] Buying Plus in the app with StoreKit (subscription), then turn the Plus rows back on
- [ ] Privacy policy (a URL is required) and the App Store privacy labels
- [ ] Wardrobe items to spend coins on (art needed)

## Economy and balance

- [ ] **Coins are scarce.** About 30 a day free against a 350-coin batch is roughly 2 weeks of lessons per refill. Also give coins for streak milestones and daily quests.
- [ ] **Free players can't buy embers.** Losing a long streak with no way to save it is a common reason people quit. Consider letting free players buy one ember at a time.
- [ ] **Free-lesson loophole.** Home's general "Study" teaches new words without costing buns.
- [ ] Double XP is free for 15 min after every lesson and also sold for 200 coins. Is the shop one worth it?

## Missing features

- [ ] App: drag sentence tiles to reorder them (currently tap in and out only)
- [ ] Home-screen widget showing the streak
- [ ] Leagues / weekly leaderboard (needs a server)
- [ ] Friends: friend streaks, friend quests, following
- [ ] Recorded native-speaker audio (we use the phone's text-to-speech; quality varies by voice, and tones matter)

## Known limits

- [ ] Speaking practice checks the words, not the tones (Apple's recogniser), so a wrong tone can pass
- [ ] Website coin merging across devices is approximate when both are used on the same day
- [ ] Opened pocket leaves a very faint glow where the pocket was (app)

## Decisions made (for reference)

- Buns: max 5, lost only for mistakes in new lessons from the path; one back every 4h, +1 per right answer in reviews/mistakes/trouble; fresh batch 350 coins; unlimited with Plus.
- Coins: start at 100. Red pocket (福) 20–35 for the first lesson each day (every lesson with Plus), 100 for finishing a chapter. Jade pocket (吉) +50 XP for all 3 daily quests.
- Shop: fresh batch 350, ember 250 (Plus only), double XP 200 for 15 min, wardrobe coming soon.
- Embers: hold 1 free, 3 with Plus; existing extras kept.
- One lesson a day keeps the streak; no daily XP target.
- Backups before this release: tags `backup-v286-before-rewards` (website) and `backup-before-rewards` (app).
