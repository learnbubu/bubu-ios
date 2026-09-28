import XCTest
@testable import Bubu

final class RewardsTests: XCTestCase {
    private let noon = 1_791_201_600_000.0            // 2026-10-05 12:00 UTC
    private let dayMs = 86_400_000.0
    private let hour = 3_600_000.0

    private func make(at t: Double) -> (ProgressStore, (Double) -> Void) {
        var now = t
        let p = ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        p.now = { now }
        return (p, { now = $0 })
    }

    func testLevelsFollowTheWebCurve() {
        let (p, _) = make(at: noon)
        XCTAssertEqual(p.level.level, 1)
        p.earnXP(99)
        XCTAssertEqual(p.level.level, 1)
        p.earnXP(1)                                // 100 reaches level 2
        XCTAssertEqual(p.level.level, 2)
        XCTAssertEqual(p.level.next, 300 - p.xpTotal)
    }

    /// No daily XP target: XP is just XP, and finishing a session is what does the day.
    func testNoDailyXPTarget() {
        let (p, _) = make(at: noon)
        XCTAssertFalse(p.earnXP(19).goalReached)
        XCTAssertFalse(p.earnXP(40).goalReached)
        XCTAssertEqual(p.xpToday, 59)
        XCTAssertFalse(p.litOn(p.today))
        p.lightFire()
        XCTAssertTrue(p.litOn(p.today))
    }

    func testThreeDayStreakEarnsAnEmberWithPlus() {
        let (p, setNow) = make(at: noon)
        p.setPlus(true)
        XCTAssertEqual(p.embers, 1)
        for d in 0..<3 {
            setNow(noon + Double(d) * dayMs)
            let f = p.lightFire()
            XCTAssertNotNil(f)
            if d == 2 { XCTAssertEqual(f?.streak, 3); XCTAssertTrue(f?.ember ?? false); XCTAssertTrue(f?.milestone ?? false) }
        }
        XCTAssertEqual(p.embers, 2)
        XCTAssertNil(p.lightFire())               // already lit today
    }

    func testAMissedDayCanBeRelit() {
        let (p, setNow) = make(at: noon)
        setNow(noon); p.lightFire()
        setNow(noon + dayMs); p.lightFire()
        // skip a day, come back the day after
        setNow(noon + 3 * dayMs)
        let out = try? XCTUnwrap(p.outSince)
        XCTAssertEqual(out?.lost, 2)
        XCTAssertEqual(p.streak, 0)
        XCTAssertTrue(p.relight())
        XCTAssertEqual(p.embers, 0)
        XCTAssertEqual(p.streak, 3)               // the relit day joins the run
        XCTAssertNil(p.outSince)
        XCTAssertFalse(p.relight())
    }

    func testAllThreeQuestsOpenTheChest() {
        let (p, _) = make(at: noon)
        let before = p.xpTotal
        // meet every quest target there is
        for _ in 0..<12 { p.questEvent("listen", correct: true) }
        for k in ["write", "speak", "sentence"] { for _ in 0..<5 { p.questEvent(k, correct: true) } }
        for _ in 0..<3 { p.questEvent("session", correct: true, lesson: true, perfect: true) }
        for _ in 0..<30 { p.recordReview() }
        p.earnXP(60)
        XCTAssertTrue(p.chestOpened)
        XCTAssertTrue(p.todayQuests.allSatisfy(p.questDone))
        XCTAssertEqual(p.activity.chests, 1)
        XCTAssertGreaterThanOrEqual(p.xpTotal - before, 60 + ProgressStore.chestXP)
        XCTAssertEqual(ProgressStore.chestXP, 50)
    }

    func testTheWholeActivityRecordSurvivesABackup() throws {
        let (a, setNow) = make(at: noon)
        for d in 0..<3 { setNow(noon + Double(d) * dayMs); a.lightFire() }
        a.earnXP(40)
        XCTAssertTrue(a.markRead("story-1"))
        let (b, _) = make(at: noon)
        XCTAssertTrue(Backup.restore(Backup.export(a), into: b))
        XCTAssertEqual(b.activity, a.activity)
        XCTAssertTrue(b.readDone("story-1"))
    }

    /// One ember held at a time, three with Plus; more than that already held are kept.
    func testTheEmberCap() {
        let (free, setFree) = make(at: noon)
        XCTAssertEqual(free.emberCap, 1)
        for d in 0..<7 { setFree(noon + Double(d) * dayMs); free.lightFire() }
        XCTAssertEqual(free.embers, 1)             // the milestones pass; the one held stays one
        let (plus, setPlus) = make(at: noon)
        plus.setPlus(true)
        XCTAssertEqual(plus.emberCap, 3)
        for d in 0..<14 { setPlus(noon + Double(d) * dayMs); plus.lightFire() }
        XCTAssertEqual(plus.embers, 3)             // 1, then days 3 and 7; day 14 finds it full
        // a record holding three from before the cap keeps them
        let (old, setOld) = make(at: noon)
        var a = Activity(); a.embers = 3
        old.replaceAll(srs: [:], done: [], activity: a, name: "", hooks: [:], prefs: Prefs())
        for d in 0..<3 { setOld(noon + Double(d) * dayMs); old.lightFire() }
        XCTAssertEqual(old.embers, 3)
    }

    // MARK: coins, buns and pockets

    func testBunsGrowBackEveryFourHours() {
        let (p, setNow) = make(at: noon)
        XCTAssertNil(p.activity.buns)
        XCTAssertEqual(p.buns, 5)                  // no record: a full five
        p.setBuns(2)
        XCTAssertEqual(p.buns, 2)
        setNow(noon + 4 * hour - 1000); XCTAssertEqual(p.buns, 2)
        setNow(noon + 4 * hour); XCTAssertEqual(p.buns, 3)
        setNow(noon + 8 * hour); XCTAssertEqual(p.buns, 4)
        XCTAssertEqual(p.bunState.next, 4 * hour, accuracy: 1)
        setNow(noon + 9 * hour); XCTAssertEqual(p.bunState.next, 3 * hour, accuracy: 1)
        setNow(noon + 40 * hour)
        XCTAssertEqual(p.buns, 5)                  // never more than five
        XCTAssertEqual(p.bunState.next, 0)
        XCTAssertEqual(ProgressStore.waitText(3 * hour + 5 * 60_000), "3h 5m")
        XCTAssertEqual(ProgressStore.waitText(40 * 60_000 - 1), "40m")
    }

    /// Setting buns keeps the time already grown toward the next one (web: setBuns).
    func testSettingBunsKeepsTheTimeAlreadyGrown() {
        let (p, setNow) = make(at: noon)
        p.setBuns(3)
        setNow(noon + 3 * hour)                    // three hours toward the fourth
        p.eatBun()
        XCTAssertEqual(p.buns, 2)
        XCTAssertEqual(p.bunState.next, hour, accuracy: 1)
        setNow(noon + 4 * hour); XCTAssertEqual(p.buns, 3)
        // from full, the clock starts now
        let (q, setQ) = make(at: noon)
        q.eatBun()
        XCTAssertEqual(q.buns, 4)
        XCTAssertEqual(q.bunState.next, 4 * hour, accuracy: 1)
        XCTAssertEqual(q.activity.buns?.t, noon)
        setQ(noon + 4 * hour); XCTAssertEqual(q.buns, 5)
    }

    func testEatingAndEarningStopAtTheEnds() {
        let (p, _) = make(at: noon)
        XCTAssertFalse(p.earnBun())                // already full
        for _ in 0..<7 { p.eatBun() }
        XCTAssertEqual(p.buns, 0)
        XCTAssertTrue(p.earnBun())
        XCTAssertEqual(p.buns, 1)
        for _ in 0..<7 { p.earnBun() }
        XCTAssertEqual(p.buns, 5)
        p.setBuns(9); XCTAssertEqual(p.buns, 5)
        p.setBuns(-2); XCTAssertEqual(p.buns, 0)
        // Plus: no limit, nothing eaten or earned
        p.setPlus(true)
        XCTAssertEqual(p.buns, Int.max)
        p.eatBun()
        XCTAssertFalse(p.earnBun())
        p.setPlus(false)
        XCTAssertEqual(p.buns, 0)
    }

    func testCoinsAreEarnedLessSpentNeverBelowZero() {
        let (p, setNow) = make(at: noon)
        XCTAssertEqual(p.coins, 100)
        p.addCoins(30)
        setNow(noon + dayMs); p.addCoins(20)
        XCTAssertEqual(p.coins, 150)
        XCTAssertEqual(p.activity.coinsIn.count, 2)
        XCTAssertFalse(p.spendCoins(151))
        XCTAssertEqual(p.coins, 150)
        XCTAssertTrue(p.spendCoins(150))
        XCTAssertEqual(p.coins, 0)
        // a merge can leave more spent than earned: still never below zero
        var a = p.activity
        a.coinsOut["2026-01-01"] = 500
        p.replaceAll(srs: [:], done: [], activity: a, name: "", hooks: [:], prefs: Prefs())
        XCTAssertEqual(p.coins, 0)
    }

    func testTheShop() {
        let (p, _) = make(at: noon)
        XCTAssertFalse(p.buy(.buns))               // 100 coins to start, a batch is 350
        XCTAssertEqual(p.coins, 100)
        p.addCoins(900)
        p.setBuns(1)
        XCTAssertTrue(p.buy(.buns))
        XCTAssertEqual(p.buns, 5)
        XCTAssertEqual(p.coins, 650)
        XCTAssertTrue(p.buy(.boost))
        XCTAssertTrue(p.boostActive)
        p.setPlus(true)                            // room for a second ember
        XCTAssertTrue(p.buy(.ember))
        XCTAssertEqual(p.embers, 2)
        XCTAssertEqual(p.coins, 650 - 200 - 250)
    }

    func testRedPockets() {
        let (p, setNow) = make(at: noon)
        let first = p.lessonPocket(chapterEnd: false)
        XCTAssertTrue((20...35).contains(first))
        XCTAssertEqual(first % 5, 0)
        XCTAssertEqual(p.activity.pocketDay, p.today)
        XCTAssertEqual(p.lessonPocket(chapterEnd: false), 0)       // the first lesson each day
        XCTAssertEqual(p.lessonPocket(chapterEnd: true), 100)      // a chapter, always
        setNow(noon + dayMs)
        XCTAssertGreaterThan(p.lessonPocket(chapterEnd: false), 0) // a new day
        XCTAssertEqual(p.lessonPocket(chapterEnd: false), 0)
        p.setPlus(true)
        for _ in 0..<40 {                                          // every lesson with Plus
            let n = p.lessonPocket(chapterEnd: false)
            XCTAssertTrue((20...35).contains(n) && n % 5 == 0)
        }
    }

    /// A session of new words is played on buns: a mistake eats one, except on a
    /// word's first try, and with none left it can't start.
    func testANewLessonIsPlayedOnBuns() throws {
        let (p, _) = make(at: noon)
        let lesson = Course.shared.lessons[0].id
        let s = try XCTUnwrap(StudySession.lesson(lesson, p))
        XCTAssertTrue(s.onBuns)
        XCTAssertFalse(s.earnsBuns)
        // every word's first try is wrong: nothing eaten
        var tried = Set<String>(), steps = 0
        while steps < 200 && s.result == nil {
            steps += 1
            if let c = s.card {
                if tried.contains(c.id) { break }          // a word coming round again
                tried.insert(c.id); s.answer(false)
            }
            s.next()
        }
        XCTAssertFalse(tried.isEmpty)
        XCTAssertEqual(s.bunsEaten, 0)
        XCTAssertEqual(p.buns, 5)
        // after the first try, mistakes cost buns
        var wrong = 0
        while wrong < 2 && steps < 400 {
            steps += 1
            if let c = s.card, tried.contains(c.id) { s.answer(false); wrong += 1 }
            else if let c = s.card { tried.insert(c.id); s.answer(true) }
            s.next()
        }
        XCTAssertEqual(s.bunsEaten, 2)
        XCTAssertEqual(p.buns, 3)
        // right answers in a lesson don't earn them back
        var right = 0
        while right < 2 && steps < 500 {
            steps += 1
            if s.card != nil { s.answer(true); right += 1 }
            s.next()
        }
        XCTAssertEqual(p.buns, 3)
        p.setBuns(0)
        XCTAssertNil(StudySession.lesson(Course.shared.lessons[1].id, p))
        // practice again of words already met isn't played on buns
        XCTAssertFalse(s.again().onBuns)
    }

    /// Only the first try at a word just met is free: one missed twice costs one bun.
    func testOnlyTheFirstTryIsFree() throws {
        let (p, _) = make(at: noon)
        let s = try XCTUnwrap(StudySession.lesson(Course.shared.lessons[0].id, p))
        var steps = 0
        while s.card == nil && steps < 10 { steps += 1; s.next() }   // past the meet screen
        let c = try XCTUnwrap(s.card)
        XCTAssertNil(p.srs[c.id])
        s.answer(false)
        XCTAssertEqual(s.bunsEaten, 0)
        s.next()
        // the same word, missed again when it comes back
        while s.card?.id != c.id && s.result == nil && steps < 300 {
            steps += 1
            if s.card != nil { s.answer(true) }
            s.next()
        }
        XCTAssertEqual(s.card?.id, c.id)
        s.answer(false)
        XCTAssertEqual(s.bunsEaten, 1)
        XCTAssertEqual(p.buns, 4)
    }

    /// Any session that introduces new words is on buns, not only a lesson from the
    /// path; practice of known words, reviews, quizzes and the skip test are free.
    func testEverySessionOfNewWordsIsOnBuns() throws {
        let (p, _) = make(at: noon)
        let lesson = Course.shared.lessons[0].id
        let cards = Course.shared.cards(in: lesson)
        // a lesson already marked done (e.g. skipped) that still has new words
        p.markDone(lesson)
        XCTAssertTrue(try XCTUnwrap(StudySession.lesson(lesson, p)).onBuns)
        // listening with nothing studied yet teaches its words
        XCTAssertTrue(try XCTUnwrap(StudySession.listening(p)).onBuns)
        XCTAssertFalse(try XCTUnwrap(StudySession.quiz(p, cards: cards)).onBuns)
        XCTAssertFalse(try XCTUnwrap(StudySession.placement(p, to: Course.shared.lessons[1].id)).onBuns)
        // with none left, a session of new words can't start
        p.setBuns(0)
        XCTAssertNil(StudySession.lesson(lesson, p))
        XCTAssertNil(StudySession.listening(p))
        // once the words are known, the same practice is free and starts with no buns
        for c in cards { p.seedKnown(c.id) }
        let again = try XCTUnwrap(StudySession.lesson(lesson, p))
        XCTAssertFalse(again.onBuns)
        XCTAssertFalse(try XCTUnwrap(StudySession.listening(p)).onBuns)
        let review = StudySession(lessonId: "", progress: p, cards: cards, mode: .review, title: "Review")
        XCTAssertFalse(review.onBuns)
        XCTAssertTrue(review.earnsBuns)
    }

    /// Free players can buy an ember while below their cap; nothing is spent at it.
    func testFreePlayersCanBuyAnEmber() {
        let (p, _) = make(at: noon)
        p.addCoins(1000)
        XCTAssertEqual(p.embers, 1)
        XCTAssertFalse(p.canBuy(.ember))           // one held, the free cap
        XCTAssertFalse(p.buy(.ember))
        XCTAssertEqual(p.coins, 1100)
        var a = p.activity; a.embers = 0
        p.replaceAll(srs: [:], done: [], activity: a, name: "", hooks: [:], prefs: Prefs())
        XCTAssertTrue(p.canBuy(.ember))
        XCTAssertTrue(p.buy(.ember))
        XCTAssertEqual(p.embers, 1)
        XCTAssertEqual(p.coins, 1100 - 250)
        XCTAssertFalse(p.buy(.ember))
        // Plus holds three
        p.setPlus(true)
        XCTAssertTrue(p.buy(.ember)); XCTAssertTrue(p.buy(.ember))
        XCTAssertEqual(p.embers, 3)
        XCTAssertFalse(p.buy(.ember))
        XCTAssertEqual(p.coins, 1100 - 750)
    }

    /// Streak milestones pay coins, once per streak.
    func testStreakMilestonesPayCoins() {
        let (p, setNow) = make(at: noon)
        var got: [Int: Int] = [:]
        for d in 0..<14 {
            setNow(noon + Double(d) * dayMs)
            if let f = p.lightFire(), f.coins > 0 { got[f.streak] = f.coins }
        }
        XCTAssertEqual(got, [3: 20, 7: 50, 14: 75])
        XCTAssertEqual(p.coins, 100 + 145)
        XCTAssertEqual(ProgressStore.milestoneCoins[365], 500)
        XCTAssertEqual(Set(ProgressStore.milestoneCoins.keys), Set(ProgressStore.milestones))
        // the same day lit again (e.g. after a merge) pays nothing more
        var a = p.activity; a.lit[p.today] = nil
        p.replaceAll(srs: [:], done: [], activity: a, name: "", hooks: [:], prefs: Prefs())
        XCTAssertEqual(p.lightFire()?.coins, 0)
        XCTAssertEqual(p.coins, 245)
        // a new streak earns them again
        setNow(noon + 20 * dayMs)
        for d in 0..<3 { setNow(noon + Double(20 + d) * dayMs); p.lightFire() }
        XCTAssertEqual(p.coins, 265)
        XCTAssertEqual(p.activity.coinsFor["3"], p.today)
    }

    /// Plus isn't for sale in release builds, nor in debug unless asked for.
    func testPlusIsNotOffered() {
        let (p, _) = make(at: noon)
        XCTAssertFalse(ProgressStore.plusForSale)
        XCTAssertFalse(p.offersPlus)
        p.setPlus(true)
        XCTAssertFalse(p.offersPlus)
        XCTAssertEqual(p.buns, Int.max)            // the Plus logic itself still works
    }

    func testRightAnswersInAReviewEarnBunsBack() {
        let (p, _) = make(at: noon)
        p.setBuns(2)
        let cards = Course.shared.cards(in: Course.shared.lessons[0].id)
        let s = StudySession(lessonId: "", progress: p, cards: cards, mode: .review, title: "Review")
        XCTAssertTrue(s.earnsBuns)
        var steps = 0
        while s.result == nil && steps < 300 {
            steps += 1
            if s.card != nil { s.answer(true) }
            s.next()
        }
        XCTAssertEqual(p.buns, 5)                  // up to five, no more
        XCTAssertEqual(s.bunsEarned, 3)
        XCTAssertEqual(s.bunsEaten, 0)
    }

    /// Finishing a lesson opens a red pocket of coins, credited straight away.
    func testFinishingALessonCreditsARedPocket() {
        let (p, _) = make(at: noon)
        let lesson = Course.shared.lessons[0].id
        var sessions = 0
        while !p.isDone(lesson) && sessions < 8 {
            sessions += 1
            let s = StudySession(lessonId: lesson, progress: p)
            var steps = 0
            while s.result == nil && steps < 300 {
                steps += 1
                if s.card != nil { s.answer(true) }
                s.next()
            }
        }
        XCTAssertTrue(p.isDone(lesson))
        XCTAssertGreaterThanOrEqual(p.coins, 120)
        XCTAssertEqual(p.activity.pocketDay, p.today)
        XCTAssertEqual(p.buns, 5)                  // no mistakes, no buns eaten
    }

    func testRewardsSurviveABackup() throws {
        let (a, _) = make(at: noon)
        a.addCoins(40)
        a.spendCoins(10)
        a.setBuns(2)
        _ = a.lessonPocket(chapterEnd: false)
        a.setPlus(true)
        let file = Backup.export(a)
        let (b, _) = make(at: noon)
        XCTAssertTrue(Backup.restore(file, into: b))
        XCTAssertEqual(b.activity, a.activity)
        XCTAssertEqual(b.coins, 130)
        XCTAssertEqual(b.bunState.n, 2)
        XCTAssertEqual(b.activity.pocketDay, a.today)
        XCTAssertTrue(b.isPlus)
        // in the web's names and shapes
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: file) as? [String: Any])
        let text = try XCTUnwrap((payload["data"] as? [String: String])?[Backup.activityKey])
        let o = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(o["coinsIn"] as? [String: Int], [a.today: 40])
        XCTAssertEqual(o["coinsOut"] as? [String: Int], [a.today: 10])
        let buns = try XCTUnwrap(o["buns"] as? [String: Any])
        XCTAssertEqual(buns["n"] as? Int, 2)
        XCTAssertEqual(buns["at"] as? Double, noon)
        XCTAssertEqual(buns["t"] as? Double, noon)
        XCTAssertEqual(o["pocketDay"] as? String, a.today)
        XCTAssertEqual(o["plus"] as? Bool, true)
    }

    /// A record from before rewards, and one the website wrote with them.
    func testRecordsWithAndWithoutRewardsDecode() throws {
        let old = #"{"days":{"2026-09-01":4},"xpDays":{"2026-09-01":20},"embers":2,"best":3}"#
        let a = try JSONDecoder().decode(Activity.self, from: Data(old.utf8))
        XCTAssertEqual(a.coinsIn, [:])
        XCTAssertEqual(a.coinsOut, [:])
        XCTAssertNil(a.buns)
        XCTAssertNil(a.pocketDay)
        XCTAssertFalse(a.plus)
        XCTAssertEqual(a.embers, 2)
        let (p, _) = make(at: noon)
        p.replaceAll(srs: [:], done: [], activity: a, name: "", hooks: [:], prefs: Prefs())
        XCTAssertEqual(p.coins, 100)
        XCTAssertEqual(p.buns, 5)

        let web = #"{"coinsIn":{"2026-10-05":35},"coinsOut":{"2026-10-05":350},"buns":{"n":1,"at":1791201600000,"t":1791201600000},"pocketDay":"2026-10-05","plus":false}"#
        let w = try JSONDecoder().decode(Activity.self, from: Data(web.utf8))
        XCTAssertEqual(w.buns, Activity.Buns(n: 1, at: noon, t: noon))
        XCTAssertEqual(w.pocketDay, "2026-10-05")
        p.replaceAll(srs: [:], done: [], activity: w, name: "", hooks: [:], prefs: Prefs())
        XCTAssertEqual(p.coins, 0)                 // 100 + 35 - 350, floored
        XCTAssertEqual(p.buns, 1)
        // a malformed buns record reads as a full five rather than sinking the record
        let odd = #"{"buns":"five","xpDays":{"2026-10-05":7}}"#
        let x = try JSONDecoder().decode(Activity.self, from: Data(odd.utf8))
        XCTAssertNil(x.buns)
        XCTAssertEqual(x.xpDays["2026-10-05"], 7)
    }

    /// Loading must never save part-way: once it wrote an empty activity record over
    /// the streak whenever your settings differed from the defaults.
    func testReopeningKeepsEverything() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let a = ProgressStore(course: Course.shared, url: url)
        a.prefs.dailyGoal = 30
        a.lightFire()
        a.earnXP(12)
        a.save()
        for _ in 0..<2 {
            let b = ProgressStore(course: Course.shared, url: url)
            XCTAssertEqual(b.prefs.dailyGoal, 30)
            XCTAssertEqual(b.xpToday, 12)
            XCTAssertEqual(b.streak, 1)
        }
    }
}
