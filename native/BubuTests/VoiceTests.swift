import XCTest
@testable import Bubu

/// Recorded clips: the app finds them by the same names tools/voice.py gives them.
final class VoiceTests: XCTestCase {
    func testClipNamesMatchTheGenerator() {
        // from Python: hashlib.sha256(text.encode()).hexdigest()[:16]
        XCTAssertEqual(Speech.clipName("你好"), "k_670d9743542cae3e")
        XCTAssertEqual(Speech.clipName("你"), "k_a0c7716669b5ded0")
        XCTAssertEqual(Speech.clipName("  你好  "), "k_670d9743542cae3e", "spaces around it don't matter")
        XCTAssertEqual(Speech.clipName("你好", speaker: "朵朵"), "dd_670d9743542cae3e")
        XCTAssertEqual(Speech.clipName("你好", speaker: "林小雨"), Speech.clipName("你好", speaker: "小雨"), "one person, one voice")
        XCTAssertEqual(Speech.clipName("你好", speaker: "路人"), "k_670d9743542cae3e", "someone without a voice of their own gets Bùbù's")
    }

    func testEveryChapterOneWordHasAClip() {
        let course = Course.shared
        let words = course.chapters[0].lessons.flatMap { course.cards(in: $0) }.map(\.word.hanzi)
        XCTAssertFalse(words.isEmpty)
        for w in words { XCTAssertNotNil(Speech.clipURL(w), "no clip for \(w)") }
    }

    /// "Tap what you hear" is only as good as its sound: every practice sentence has a clip.
    func testEveryPracticeSentenceHasAClip() {
        let drills = Course.shared.data.drills ?? []
        XCTAssertFalse(drills.isEmpty)
        for d in drills { XCTAssertNotNil(Speech.clipURL(d.hanzi), "no clip for \(d.hanzi)") }
    }

    func testAWordWithNoClipFallsBackToTheUsualVoice() {
        XCTAssertNil(Speech.clipURL("这句话没有录音，所以用手机的声音。"))
        // no clip in the speaker's voice: Bùbù's
        XCTAssertEqual(Speech.clipURL("你好", speaker: "陈爸爸")?.lastPathComponent, "k_670d9743542cae3e.mp3")
    }

    func testChapterOneDialogueLinesAreSpokenByWhoeverSaysThem() {
        let lines = Course.shared.data.dialogues.filter { $0.lesson.hasPrefix("起步1 U1") }.flatMap { $0.turns }
        XCTAssertTrue(lines.allSatisfy { $0.name != nil }, "every line knows who says it")
        let duoduo = lines.first { $0.name == "朵朵" }
        XCTAssertNotNil(duoduo, "朵朵 speaks in chapter 1")
        // until 朵朵 has a voice of her own, her lines are in Bùbù's
        if let t = duoduo {
            XCTAssertNotNil(Speech.clipURL(t.hanzi, speaker: t.name), "no clip for \(t.hanzi)")
        }
    }
}
