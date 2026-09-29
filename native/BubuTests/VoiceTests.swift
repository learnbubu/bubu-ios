import XCTest
@testable import Bubu

/// Recorded clips: the app finds them by the same names tools/voice.py gives them.
final class VoiceTests: XCTestCase {
    func testClipNamesMatchTheGenerator() {
        // from Python: hashlib.sha256(text.encode()).hexdigest()[:16]
        XCTAssertEqual(Speech.clipName("你好"), "k_670d9743542cae3e")
        XCTAssertEqual(Speech.clipName("你"), "k_a0c7716669b5ded0")
        XCTAssertEqual(Speech.clipName(" 你好" + String(UnicodeScalar(10))), "k_670d9743542cae3e", "spaces around it don't matter")
        XCTAssertEqual(Speech.clipName("你好", male: true), "c_670d9743542cae3e")
    }

    func testEveryChapterOneWordHasAClip() {
        let course = Course.shared
        let words = course.chapters[0].lessons.flatMap { course.cards(in: $0) }.map(\.word.hanzi)
        XCTAssertFalse(words.isEmpty)
        for w in words { XCTAssertNotNil(Speech.clipURL(w), "no clip for \(w)") }
    }

    func testAWordWithNoClipFallsBackToTheUsualVoice() {
        XCTAssertNil(Speech.clipURL("这句话没有录音，所以用手机的声音。"))
        // the other speaker's clip is used when there is one, else the usual voice's
        XCTAssertNotNil(Speech.clipURL("你好", male: true))
    }
}
