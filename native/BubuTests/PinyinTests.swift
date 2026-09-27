import XCTest
@testable import Bubu

final class PinyinTests: XCTestCase {
    func testSyllablesSplitLikeTheWeb() {
        XCTAssertEqual(Pinyin.syllables("nǐ hǎo"), ["nǐ", "hǎo"])
        XCTAssertEqual(Pinyin.syllables("láizì"), ["lái", "zì"])
        XCTAssertEqual(Pinyin.syllables("xièxie"), ["xiè", "xie"])
        XCTAssertEqual(Pinyin.syllables("Dàwèi, nǐ hǎo!"), ["Dàwèi", "nǐ", "hǎo"])   // names stay whole
    }

    func testTonePairsSkipTheTricky() {
        let card = { (h: String, p: String) in Card(id: "x", lessonId: "x", word: Word(hanzi: h, pinyin: p, pos: nil, en: "")) }
        XCTAssertEqual(TonesPage.pair(card("谢谢", "xièxie")), [4, 5])
        XCTAssertEqual(TonesPage.pair(card("中国", "Zhōngguó")), nil)          // a capitalised run stays whole: one syllable
        XCTAssertEqual(TonesPage.pair(card("你好", "nǐ hǎo")), nil)            // 3 + 3 changes when spoken
        XCTAssertEqual(TonesPage.pair(card("不是", "bú shì")), nil)            // 不 changes too
        XCTAssertEqual(TonesPage.pair(card("喝茶", "hē chá")), [1, 2])
        XCTAssertGreaterThan(Course.shared.cards.filter { TonesPage.pair($0) != nil }.count, 50)
    }

    func testKeyPhrasesUseOnlyWhatWasTaught() {
        let phrases = Course.shared.keyPhrases(chapter: 1)
        XCTAssertFalse(phrases.isEmpty)
        let known = Course.shared.charsThrough(chapter: 1)
        for t in phrases { XCTAssertTrue(t.hanzi.filter(Course.isHan).allSatisfy(known.contains), t.hanzi) }
    }

    func testEnglishHintsPointAtTheRightWords() {
        let words = [SentenceWord(hanzi: "我", pinyin: "wǒ"), SentenceWord(hanzi: "喝", pinyin: "hē"), SentenceWord(hanzi: "咖啡", pinyin: "kāfēi")]
        let t = Hints.english("I drink coffee.", words)
        XCTAssertEqual(t.map { $0.word?.hanzi }, ["我", "喝", "咖啡"])
        let the = Hints.english("the coffee", words)
        XCTAssertTrue(the[0].none)
        XCTAssertEqual(Hints.stem("drinking"), "drink")
        XCTAssertEqual(Hints.stem("don't"), "not")
    }
}
