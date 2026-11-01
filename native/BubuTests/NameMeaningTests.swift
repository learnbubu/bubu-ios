import XCTest
@testable import Bubu

final class NameMeaningTests: XCTestCase {
    func testEveryNameHasItsEnglish() {
        for n in Course.shared.nameList where Course.wordEn[n] == nil { XCTAssertNotNil(Hints.nameEn[n], n) }
    }

    func testANameIsNotSpelledOutCharacterByCharacter() {
        XCTAssertEqual(Hints.meaning("大英博物馆"), "the British Museum")
    }
}
