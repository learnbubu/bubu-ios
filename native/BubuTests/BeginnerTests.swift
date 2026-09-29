import XCTest
@testable import Bubu

/// Help for total beginners: pinyin training wheels, what's played aloud, gentler corrections.
final class BeginnerTests: XCTestCase {
    private func card(_ h: String, _ p: String, _ en: String, id: String = "t") -> Card {
        Card(id: id, lessonId: "x", word: Word(hanzi: h, pinyin: p, pos: nil, en: en))
    }

    // MARK: pinyin training wheels

    func testANewWordShowsItsPinyinAndAStrongOneHidesIt() {
        XCTAssertEqual(TrainingWheels.strongReps, 3)
        XCTAssertEqual(TrainingWheels.strongDays, 3)
        XCTAssertTrue(TrainingWheels.shows(nil, mode: .auto))                                   // never seen
        XCTAssertTrue(TrainingWheels.shows(SRSRecord(interval: 1, reps: 2), mode: .auto))      // still learning
        XCTAssertFalse(TrainingWheels.shows(SRSRecord(interval: 1, reps: 3), mode: .auto))     // right 3 times
        XCTAssertFalse(TrainingWheels.shows(SRSRecord(interval: 3, reps: 1), mode: .auto))     // spaced 3 days
    }

    func testTheSettingModes() {
        let learning = SRSRecord(interval: 1, reps: 1)
        let strong = SRSRecord(interval: 10, reps: 5)
        // Always: every word
        XCTAssertTrue(TrainingWheels.shows(strong, mode: .always))
        // Auto: until strong
        XCTAssertTrue(TrainingWheels.shows(learning, mode: .auto))
        XCTAssertFalse(TrainingWheels.shows(strong, mode: .auto))
        // Hide when known: only until it's been got right once
        XCTAssertTrue(TrainingWheels.shows(nil, mode: .known))
        XCTAssertFalse(TrainingWheels.shows(learning, mode: .known))
    }

    func testNoPinyinWhereItIsTested() {
        XCTAssertTrue(TrainingWheels.testsPinyin(dir: "pinyin", answered: false))
        XCTAssertTrue(TrainingWheels.testsPinyin(dir: "listen", answered: false))
        XCTAssertFalse(TrainingWheels.testsPinyin(dir: "listen", answered: true))
        XCTAssertFalse(TrainingWheels.testsPinyin(dir: "recognize", answered: false))
        XCTAssertFalse(TrainingWheels.testsPinyin(dir: "recall", answered: false))
        for mode in PinyinMode.allCases {
            XCTAssertFalse(TrainingWheels.shows(nil, mode: mode, testing: true), mode.rawValue)
        }
        let w = Wheels(srs: [:], mode: .always)
        XCTAssertFalse(w.shows(card: card("好", "hǎo", "good"), testing: TrainingWheels.testsPinyin(dir: "pinyin", answered: false)))
    }

    func testWheelsFindAWordsRecord() {
        let c = Course.shared.cards[0]
        let strong = Wheels(srs: [c.id: SRSRecord(interval: 10, reps: 5)], mode: .auto)
        XCTAssertFalse(strong.shows(card: c))
        XCTAssertFalse(strong.shows(hanzi: c.word.hanzi))
        XCTAssertTrue(Wheels().shows(card: c))
        XCTAssertTrue(Wheels().shows(hanzi: c.word.hanzi))
        XCTAssertTrue(strong.shows(hanzi: "鑫鑫鑫"))                                              // not in the course: new
    }

    func testPinyinSettingDefaultsToAutoAndOldBackupsDecode() throws {
        XCTAssertEqual(Prefs().pinyin, .auto)
        XCTAssertTrue(Prefs().playsAutomatically)
        let old = try JSONDecoder().decode(Prefs.self, from: Data(#"{"showPinyin":false,"rate":0.7}"#.utf8))
        XCTAssertNil(old.pinyinMode)
        XCTAssertNil(old.autoplay)
        XCTAssertTrue(old.playsAutomatically)
        XCTAssertEqual(old.pinyin, .known)                                                     // pinyin was off: the strictest
        let blank = try JSONDecoder().decode(Prefs.self, from: Data("{}".utf8))
        XCTAssertEqual(blank.pinyin, .auto)
        var p = Prefs()
        p.pinyin = .known
        XCTAssertEqual(p.pinyinMode, "known")
        XCTAssertFalse(p.showPinyin)                                                           // what the website reads
        p.pinyin = .always
        p.autoplay = false
        XCTAssertTrue(p.showPinyin)
        let back = try JSONDecoder().decode(Prefs.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(back.pinyin, .always)
        XCTAssertFalse(back.playsAutomatically)
    }

    // MARK: corrections

    func testToneNames() {
        XCTAssertEqual((1...5).map(Correction.ordinal), ["1st", "2nd", "3rd", "4th", "neutral"])
    }

    func testToneDiffLine() {
        XCTAssertEqual(Correction.toneLine(hanzi: "好", right: "hǎo", chosen: "hào"),
                       "Close! 好 is hǎo — 3rd tone (you chose hào — 4th)")
        // one syllable of a word: that character
        XCTAssertEqual(Correction.toneLine(hanzi: "你好", right: "nǐ hǎo", chosen: "nǐ hāo"),
                       "Close! 好 is hǎo — 3rd tone (you chose hāo — 1st)")
        XCTAssertEqual(Correction.toneLine(hanzi: "谢谢", right: "xièxie", chosen: "xiéxie"),
                       "Close! 谢 is xiè — 4th tone (you chose xié — 2nd)")
        // more than one: the whole word
        XCTAssertEqual(Correction.toneLine(hanzi: "你好", right: "nǐ hǎo", chosen: "ní hào"),
                       "Close! 你好 is nǐ hǎo — 3rd + 3rd tones (you chose ní hào — 2nd + 4th)")
        // the neutral tone
        XCTAssertEqual(Correction.toneLine(hanzi: "子", right: "zi", chosen: "zǐ"),
                       "Close! 子 is zi — neutral tone (you chose zǐ — 3rd)")
        // not a tone mistake
        XCTAssertNil(Correction.toneLine(hanzi: "好", right: "hǎo", chosen: "hěn"))
        XCTAssertNil(Correction.toneLine(hanzi: "好", right: "hǎo", chosen: "hǎo"))
        XCTAssertNil(Correction.toneLine(hanzi: "你好", right: "nǐ hǎo", chosen: "nǐ"))
    }

    func testCorrectionLines() {
        let you = card("你", "nǐ", "you", id: "a"), he = card("他", "tā", "he", id: "b")
        let cards = [you, he]
        let meaning = "你 means 'you'. (他 is 'he')"
        XCTAssertEqual(Correction.meaningLine(you.word, he.word), meaning)
        let recall = Exercise(kind: .choice, dir: "recall", card: you, options: ["你", "他"], answer: "你")
        XCTAssertEqual(Correction.line(recall, chosen: "他", cards: cards), meaning)
        XCTAssertNil(Correction.line(recall, chosen: "你", cards: cards))                       // right
        XCTAssertNil(Correction.line(recall, chosen: nil, cards: cards))
        let recognize = Exercise(kind: .choice, dir: "recognize", card: you, options: ["you", "he"], answer: "you")
        XCTAssertEqual(Correction.line(recognize, chosen: "he", cards: cards), meaning)
        XCTAssertNil(Correction.line(recognize, chosen: "a word not in the course", cards: cards))
        let good = card("好", "hǎo", "good")
        let pinyin = Exercise(kind: .choice, dir: "pinyin", card: good, options: ["hǎo", "hào"], answer: "hǎo")
        XCTAssertEqual(Correction.line(pinyin, chosen: "hào", cards: []), "Close! 好 is hǎo — 3rd tone (you chose hào — 4th)")
    }

    // MARK: hearing it

    func testAutoplayNeverGivesTheAnswerAway() {
        let c = card("你好", "nǐ hǎo", "hello")
        func choice(_ dir: String) -> Exercise { Exercise(kind: .choice, dir: dir, card: c, options: [], answer: "") }
        // as it appears
        XCTAssertEqual(Autoplay.onShow(choice("recognize"), autoplay: true), "你好")
        XCTAssertNil(Autoplay.onShow(choice("recognize"), autoplay: false))
        XCTAssertNil(Autoplay.onShow(choice("recall"), autoplay: true))                        // the sound is the answer
        XCTAssertNil(Autoplay.onShow(choice("pinyin"), autoplay: true))                        // the tones are
        XCTAssertEqual(Autoplay.onShow(choice("listen"), autoplay: true), "你好")               // the sound is the question
        XCTAssertEqual(Autoplay.onShow(choice("listen"), autoplay: false), "你好")
        // once answered: the right Chinese, only if it wasn't already said as it appeared
        for d in ["recall", "pinyin"] {
            XCTAssertEqual(Autoplay.onAnswer(choice(d), autoplay: true), "你好", d)
            XCTAssertNil(Autoplay.onAnswer(choice(d), autoplay: false), d)
        }
        for d in ["recognize", "listen"] {
            XCTAssertNil(Autoplay.onAnswer(choice(d), autoplay: true), "\(d): heard once already")
        }
        let s = Sentence(hanzi: "你好，我是大卫。", pinyin: "nǐ hǎo, wǒ shì Dàwèi.", en: "Hello, I'm David.",
                         words: [.init(hanzi: "你好", pinyin: "nǐ hǎo"), .init(hanzi: "我", pinyin: "wǒ"),
                                 .init(hanzi: "是", pinyin: "shì"), .init(hanzi: "大卫", pinyin: "Dàwèi")])
        let build = Exercise(kind: .sentence, dir: "sentence", card: c, sentence: s, toChinese: true)
        XCTAssertNil(Autoplay.onShow(build, autoplay: true))                                   // building the Chinese
        XCTAssertEqual(Autoplay.onAnswer(build, autoplay: true), s.hanzi)
        let translate = Exercise(kind: .sentence, dir: "sentence", card: c, sentence: s, toChinese: false)
        XCTAssertEqual(Autoplay.onShow(translate, autoplay: true), s.hanzi)
        XCTAssertNil(Autoplay.onShow(translate, autoplay: false))
        XCTAssertNil(Autoplay.onAnswer(translate, autoplay: true))                            // heard once already
        let speak = Exercise(kind: .speak, dir: "speak", card: c)
        XCTAssertNil(Autoplay.onShow(speak, autoplay: true))
        XCTAssertNil(Autoplay.onAnswer(speak, autoplay: true))
    }

    func testSlowIsAlwaysSlower() {
        for normal: Float in [0.2, 0.34, 0.425, 0.5] {
            XCTAssertLessThan(Speech.slowRate(normal), normal)
            XCTAssertEqual(Speech.slowRate(normal), normal * Speech.slowFactor, accuracy: 0.0001)
        }
    }
}
