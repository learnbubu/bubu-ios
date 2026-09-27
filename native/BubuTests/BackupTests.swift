import XCTest
@testable import Bubu

final class BackupTests: XCTestCase {
    private func store() -> ProgressStore {
        ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }

    /// Exported here, restored here: everything comes back.
    func testRoundTrip() throws {
        let a = store()
        let first = Course.shared.lessons[0].id
        a.markDone(first)
        a.review(Course.shared.cards[0].id, .good)
        a.earnXP(12)
        a.lightFire()
        a.name = "Dom"
        a.prefs.dailyGoal = 30
        a.setHook("好", "my own story")
        let file = Backup.export(a)
        let s = try XCTUnwrap(Backup.summary(file))
        XCTAssertEqual(s.lessons, 1)
        XCTAssertEqual(s.words, 1)

        let b = store()
        XCTAssertTrue(Backup.restore(file, into: b))
        XCTAssertTrue(b.isDone(first))
        XCTAssertEqual(b.wordsLearned, 1)
        XCTAssertEqual(b.xpToday, 12)
        XCTAssertEqual(b.streak, 1)
        XCTAssertEqual(b.name, "Dom")
        XCTAssertEqual(b.prefs.dailyGoal, 30)
        XCTAssertEqual(b.hooks["好"], "my own story")
    }

    /// A backup made by the website restores here.
    func testWebsiteBackupRestores() throws {
        let web = """
        {"app":"zhBeginnerA","version":1,"exported":"2026-09-20T10:00:00.000Z","data":{
          "zhBeginnerA.srs.v1":"{\\"L1:0\\":{\\"ease\\":2.4,\\"interval\\":3,\\"due\\":1790000000000,\\"reps\\":1,\\"S\\":3.17,\\"D\\":5.3,\\"last\\":1789740800000,\\"known\\":true},\\"L1:1\\":{\\"reps\\":\\"2\\",\\"weird\\":null}}",
          "zhBeginnerA.done.v1":"[\\"L1\\",\\"L2\\"]",
          "zhBeginnerA.prefs.v1":"{\\"name\\":\\"Sam\\",\\"rate\\":0.7,\\"dailyGoal\\":50,\\"showPinyin\\":false,\\"lessons\\":[\\"L1\\"],\\"focuses\\":[\\"recognize\\"]}",
          "zhBeginnerA.activity.v1":"{\\"days\\":{\\"2026-09-20\\":14},\\"xpDays\\":{\\"2026-09-20\\":40},\\"lit\\":{\\"2026-09-20\\":true},\\"relit\\":{\\"2026-09-19\\":true},\\"embers\\":2}"
        }}
        """
        let p = store()
        XCTAssertTrue(Backup.restore(Data(web.utf8), into: p))
        XCTAssertEqual(p.srs.count, 2)
        XCTAssertEqual(p.srs["L1:1"]?.reps, 2)
        XCTAssertEqual(p.srs["L1:0"]?.known, true)
        XCTAssertTrue(p.done.isEmpty)                         // made-up lesson ids are dropped, as the web does
        XCTAssertEqual(p.name, "Sam")
        XCTAssertEqual(p.prefs.dailyGoal, 50)
        XCTAssertFalse(p.prefs.showPinyin)
        XCTAssertTrue(p.litOn("2026-09-20"))
        XCTAssertTrue(p.litOn("2026-09-19"))
        XCTAssertEqual(p.xp(on: "2026-09-20"), 40)
    }

    func testNotABackup() {
        XCTAssertNil(Backup.summary(Data("{\"hello\":1}".utf8)))
        XCTAssertFalse(Backup.restore(Data("nonsense".utf8), into: store()))
    }

    /// A backup from the old edition: its words move onto the new course's cards by what they are.
    func testOldEditionBackupMigrates() throws {
        let old = """
        {"app":"zhBeginnerA","version":1,"exported":"2026-08-01T10:00:00.000Z","data":{
          "zhBeginnerA.srs.v1":"{\\"useful:2\\":{\\"reps\\":3,\\"interval\\":9,\\"last\\":1785000000000,\\"due\\":1786000000000}}",
          "zhBeginnerA.done.v1":"[\\"old-lesson-1\\"]",
          "zhBeginnerA.prefs.v1":"{\\"lessons\\":[\\"old-lesson-1\\"]}",
          "zhBeginnerA.activity.v1":"{\\"xpDays\\":{\\"2026-07-30\\":900}}"
        }}
        """
        let p = store()
        XCTAssertTrue(Backup.restore(Data(old.utf8), into: p))
        let target = try XCTUnwrap(Course.shared.cards.first { $0.word.hanzi == "对不起" })
        XCTAssertEqual(p.srs[target.id]?.reps, 3)
        XCTAssertNil(p.srs["useful:2"])
        XCTAssertFalse(p.done.contains("old-lesson-1"))
        XCTAssertNil(p.prefs.lessons)
        XCTAssertGreaterThan(p.activity.levelSeen, 1)          // no level-up for old XP
    }
}
