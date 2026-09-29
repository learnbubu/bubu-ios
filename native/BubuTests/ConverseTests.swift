import XCTest
@testable import Bubu

/// Converse: a dialogue is yours to say once you've met the words of your lines.
final class ConverseTests: XCTestCase {
    private let course = Course.shared

    func testNothingIsUnlockedBeforeAnyWordIsMet() {
        let locked = course.data.dialogues.filter { !course.dialogueUnlocked($0) { _ in false } }
        XCTAssertFalse(locked.isEmpty)
        for d in locked { XCTAssertFalse(course.unmetWords(in: d) { _ in false }.isEmpty) }
    }

    func testEveryDialogueIsUnlockedOnceEveryWordIsMet() {
        let stillLocked = course.data.dialogues.filter { !course.dialogueUnlocked($0) { _ in true } }
        // names are never taught, so they mustn't keep a dialogue locked for ever
        XCTAssertTrue(stillLocked.isEmpty, "locked even with every word met: "
            + stillLocked.map { "\($0.title): \(course.unmetWords(in: $0) { _ in true })" }.joined(separator: "; "))
    }

    func testNamesNeverLockADialogue() {
        XCTAssertTrue(course.nameOnlyChars.contains("陈"))
        XCTAssertTrue(course.isNameOrMet("陈") { _ in false }, "a name needs no learning")
        XCTAssertFalse(course.isNameOrMet("老师") { _ in false }, "a word does")
        XCTAssertFalse(course.isNameOrMet("陈老师") { _ in false }, "a name with an unmet word is still unmet")
        XCTAssertTrue(course.isNameOrMet("陈老师") { _ in true })
    }
}
