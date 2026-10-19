# Achievements

What Duolingo does, and what we do instead. Art brief for Codex: `tools/art/ACHIEVEMENTS.md`.

## What Duolingo does

- **Tiered families, not one-off badges.** Most achievements are one badge that levels up (Wildfire for the
  streak, Sage / XP Olympian for XP, Quest Explorer for quests, up to 10 levels each), so there's always a next
  step in sight.
- **A few one-offs** for habits and moments (Weekend Warrior, Night Owl, Early Bird, Champion for leagues).
- **Profile shows a short row**, newest first, with "View all" for the rest; each badge shows its level and how far
  it is to the next.
- In 2023 they redesigned achievements to be easier to find and to celebrate (earning one is a full-screen moment,
  and it can be shared).

## What we keep, and what's ours

We keep the shape that works: families that level up, a short row on Profile, a moment when one's earned. The
rest is Bùbù's own:

- **Bùbù is on every badge**, doing that family's thing, in front of a simple four-lobed garden-window shape in
  the family's own colour, his head breaking out of its top. One finished picture a family, sticker-simple.
- **Tiers are numbers**, as Duolingo's: the badge stays the same and the app writes the tier's threshold on the plain
  foot of the shape ("30", "100"). Five tiers a family (fewer for a few).
- **Everything is about learning Chinese**, not just using the app: characters known, characters written by hand,
  stories read, chapters sealed with a red seal.
- **Names in both languages**, short, so they fit under a medal: 守灯 Lantern Keeper.
- **No leagues and no friends' badges** until there's something behind them.

## The families

Thresholds are set for this course: 1,190 lessons, 61 chapters, 76 stories, about 3,800 words, 1,655 characters.

| | Family | Counts | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 | Bùbù |
|---|---|---|---|---|---|---|---|---|
| 1 | 守灯 Lantern Keeper | longest streak (days) | 7 | 30 | 100 | 200 | 365 | a glowing red lantern |
| 2 | 步步 Step by Step | lessons done | 10 | 50 | 150 | 400 | 1,000 | stepping stones across a pond |
| 3 | 词园 Word Garden | words learned | 50 | 250 | 750 | 1,500 | 3,000 | a bamboo shoot in a pot |
| 4 | 笔墨 Brush and Ink | characters known | 25 | 100 | 300 | 700 | 1,500 | a brush resting on an inkstone |
| 5 | 字帖 Copybook | characters written to the end | 10 | 100 | 300 | 1,000 | 3,000 | a practice sheet with one stroke drawn |
| 6 | 登山 Mountain Climber | total XP | 1,000 | 5,000 | 15,000 | 40,000 | 100,000 | a misty peak with a small red flag |
| 7 | 说书 Storyteller | stories read | 1 | 5 | 15 | 40 | 76 (all) | an unrolled scroll |
| 8 | 印章 Seal Collector | chapters complete | 1 | 5 | 15 | 30 | 61 (all) | a red seal stamp |
| 9 | 红包 Lucky Pockets | red pockets opened | 5 | 25 | 75 | 150 | 365 | a red envelope with a gold coin |
| 10 | 司南 Pathfinder | quests done | 10 | 50 | 150 | 400 | 1,000 | the ancient spoon compass on its plate |
| 11 | 重燃 Rekindled | days relit with a spare lantern | 1 | 3 | 10 | – | – | a lantern catching a spark |

### Moments (a count of each lesson-end moment)

These already show at the end of a lesson; now they count. Each has three tiers: Bronze at 1, Silver at 10,
Gold at 50.

| | Moment | When | Bùbù |
|---|---|---|---|
| 12 | 满分 Flawless | every answer right | a polished jade disc (bi) |
| 13 | 夜猫子 Night Owl | a lesson late at night | an owl on a branch under a crescent moon |
| 14 | 早起鸟 Early Bird | a lesson early in the morning | a small bird before a rising sun |
| 15 | 嗖 Lightning Fast | a very quick lesson | a swallow mid-swoop |
| 16 | 功夫 Kung Fu Master | the kung fu moment | a red-tasselled practice staff and a fan |

### One-off

| | Badge | When | Bùbù |
|---|---|---|---|
| 17 | 新衣 Dressed Up | first time you change outfit | a coat hanger with a tiny green dragon hood on it |

## What the app needs that it doesn't track yet

Everything else is already in `Activity` / `ProgressStore`.

- **Moments:** a count per moment key (`moments: [String: Int]`), added to when a lesson ends with one.
- **Quests done in total:** `questMonths` summed (already there).
- **Characters written:** the sum of `written` (already there).
- **Relit days:** `relit` days (already there).
- **Dressed up:** set when an outfit other than Everyday is first saved.

Earned tiers keep their date in `achv` (`"lantern-keeper-3": "2026-10-19"`), so the order on Profile is the
newest first, as now.

## On screen

- **A badge:** the family's picture, the tier's number on the foot of its shape, "NEW" on one just earned. Under it,
  its name and "3 of 5". Not yet earned: all of it greyed.
- **Profile:** a row of badges, the newest earned first, then the nearest to earning. "See all" opens every family.
- **See all:** a grid of badges, three a row, each with its name and tier, as Duolingo's.
- **Earning one:** a moment at the end of the lesson that earned it (the badge pops in and its number counts
  up), as the lesson-end moments do.
