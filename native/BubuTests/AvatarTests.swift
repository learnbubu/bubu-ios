import XCTest
@testable import Bubu

final class AvatarTests: XCTestCase {
    let w = Wardrobe.shared

    func testTheDefaultLookDrawsInLayers() {
        let d = w.defaults
        XCTAssertTrue(w.supported(d))
        XCTAssertGreaterThanOrEqual(w.layers(d).count, 6)
        for l in w.layers(d) { XCTAssertNotNil(UIImage(named: l), l) }
    }

    func testChangingHairKeepsAColourItHas() throws {
        let n = try XCTUnwrap(w.change(w.defaults, "hair", "curls"))
        XCTAssertTrue(w.choices(n, "hairColour").contains(n.hairColour))
    }

    func testOldSavedLooksMigrate() throws {
        let old = try JSONDecoder().decode(AvatarConfig.self, from: Data(#"{"version":2,"outfit":"jacket","tone":"tan"}"#.utf8))
        let m = w.migrate(old)
        XCTAssertEqual(m.top, "yellow-jacket")
        XCTAssertEqual(m.tone, "tan")
        XCTAssertTrue(w.supported(m))
        XCTAssertEqual(w.migrate(nil), w.defaults)
    }

    func testEveryAchievementCanBeChecked() {
        let p = ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
        XCTAssertEqual(Achievement.all.filter { $0.test(p) }.count, 0)
        XCTAssertEqual(Achievement.all.count, 9 + Course.shared.chapters.count)
    }
}
