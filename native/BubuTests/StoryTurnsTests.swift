import XCTest
@testable import Bubu

/// A story's English, split into its speakers' turns as the Chinese is (one line each).
final class StoryTurnsTests: XCTestCase {
    func testTheEnglishSplitsAtEachSpeaker() {
        let t = StoryPage.englishTurns("Xiǎo Yǔ: Mark, this is my cousin, Chen Ming. Chen Ming: Hi! Nice to meet you. Mark: Hi!")
        XCTAssertEqual(t.map(\.speaker), ["Xiǎo Yǔ", "Chen Ming", "Mark"])
        XCTAssertEqual(t[0].words, "Mark, this is my cousin, Chen Ming.")
        XCTAssertEqual(t[2].words, "Hi!")
    }

    func testANameInsideALineIsNotASpeaker() {
        // "Mark," mid-sentence, and the longer names before the shorter
        let t = StoryPage.englishTurns("Chen Ming's mum: Ask Mark: is he hungry? Mark: Yes!")
        XCTAssertEqual(t.map(\.speaker), ["Chen Ming's mum", "Mark"])
    }

    func testNarrationStaysOneParagraph() {
        let t = StoryPage.englishTurns("It was a cold morning in Oxford.")
        XCTAssertEqual(t.count, 1)
        XCTAssertNil(t[0].speaker)
    }

    func testEveryStorySplitsTheSameInEnglishAsInChinese() {
        let cast = Set(Speech.speakerCodes.keys)
        var same = 0
        for r in Course.shared.data.readings {
            let toks = r.sentences.flatMap { $0 }.map { $0.components(separatedBy: "|")[0] }
            var zh = 0
            for i in 0..<max(0, toks.count - 1) where toks[i + 1] == "：" && cast.contains(toks[i])
                && (i == 0 || ["。", "！", "？", "…", "”"].contains(toks[i - 1])) { zh += 1 }
            if StoryPage.englishTurns(r.translation).filter({ $0.speaker != nil }).count == zh { same += 1 }
        }
        // (one story has a line its English runs into the one before)
        XCTAssertGreaterThanOrEqual(same, Course.shared.data.readings.count - 1)
    }
}
