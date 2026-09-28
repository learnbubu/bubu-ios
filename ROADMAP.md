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

## Before the App Store

- [x] Apple Developer membership active (28 Sep 2026)
- [ ] TestFlight: app record in App Store Connect, API key into Codemagic, builds upload automatically
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

## Known limits

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
