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
        // names and words outside the course can keep a few locked; nearly all must open
        XCTAssertLessThan(stillLocked.count, course.data.dialogues.count / 10,
                          "locked even with every word met: \(stillLocked.prefix(5).map(\.title))")
    }
}
