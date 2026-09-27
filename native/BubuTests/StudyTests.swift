import XCTest
@testable import Bubu

final class StudyTests: XCTestCase {
    func testCharacterDataLoads() {
        // a single null in the part names once emptied the whole table
        XCTAssertGreaterThan(CharData.shared.chars.count, 1000)
        XCTAssertGreaterThan(CharData.shared.partNames.count, 100)
        XCTAssertEqual(CharData.shared.charSim("买", "卖"), 4)
    }

    func testSentencesSplit() {
        XCTAssertGreaterThan(Course.shared.sentences.count, 100)
        let w = Sentence.segment(hanzi: "你叫什么名字？", pinyin: "nǐ jiào shénme míngzi?")
        XCTAssertEqual(w?.map(\.hanzi), ["你", "叫", "什么", "名字"])
        let er = Sentence.segment(hanzi: "你去哪儿？", pinyin: "nǐ qù nǎr?")
        XCTAssertEqual(er?.map(\.hanzi), ["你", "去", "哪儿"])
    }

    func testTimeWordSwapIsAccepted() {
        let s = Sentence(hanzi: "我明天去。", pinyin: "wǒ míngtiān qù.", en: "I'll go tomorrow.",
                         words: [.init(hanzi: "我", pinyin: "wǒ"), .init(hanzi: "明天", pinyin: "míngtiān"), .init(hanzi: "去", pinyin: "qù")])
        XCTAssertEqual(s.acceptedOrders, [["我", "明天", "去"], ["明天", "我", "去"]])
    }

    func testToneVariantsKeepTheLetters() {
        for v in Pinyin.variants("nǐ hǎo", 3) {
            XCTAssertNotEqual(v, "nǐ hǎo")
            XCTAssertEqual(Pinyin.toneless(v), "ni hao")
        }
    }

    func testAFirstSessionMeetsWordsThenPractisesEachTwice() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        let p = ProgressStore(course: Course.shared, url: url)
        let lesson = Course.shared.lessons[0].id
        let s = StudySession(lessonId: lesson, progress: p)
        guard case .meet(let first, _, _) = s.current else { return XCTFail("starts by meeting new words") }
        XCTAssertLessThanOrEqual(first.count, 3)
        // answer everything right until the end
        var guardN = 0
        while s.result == nil && guardN < 200 {
            guardN += 1
            if s.card != nil {
                XCTAssertNotNil(s.exercise)
                if let ex = s.exercise, ex.kind == .choice {
                    XCTAssertEqual(Set(ex.options).count, ex.options.count, "options are distinct")
                    XCTAssertTrue(ex.options.contains(ex.answer))
                }
                s.answer(true)
            }
            s.next()
        }
        let r = try! XCTUnwrap(s.result)
        XCTAssertEqual(r.accuracy, 100)
        XCTAssertGreaterThan(r.xp, 0)
        XCTAssertTrue(p.litOn(p.today))
        XCTAssertEqual(p.streak, 1)
    }
}
