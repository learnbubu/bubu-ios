import XCTest
@testable import Bubu

final class NameMeaningTests: XCTestCase {
    func testEveryNameHasItsEnglish() {
        for n in Course.shared.nameList where Course.wordEn[n] == nil { XCTAssertNotNil(Hints.nameEn[n], n) }
    }

    func testAWordWithNoCardSaysWhatItMeans() {
        XCTAssertEqual(Hints.meaning("一天"), "one day")
        XCTAssertEqual(Hints.meaning("去过"), "have been to")
        XCTAssertEqual(Hints.meaning("在家"), "at home")
        XCTAssertFalse(Hints.builtEn.isEmpty)
    }

    func testANameIsNotSpelledOutCharacterByCharacter() {
        XCTAssertEqual(Hints.meaning("大英博物馆"), "the British Museum")
    }
}
