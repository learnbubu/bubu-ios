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

    func testEveryOutfitLoadsWithTheColoursThatCarry() throws {
        for o in Outfit.all {
            let rig = try XCTUnwrap(AvatarRig.load(o.id), o.id)
            XCTAssertNotNil(rig.anims["Idle"], o.id)
            let names = Set((rig.channels ?? []).map(\.name))
            XCTAssertTrue(names.isSuperset(of: ["Skin", "Hair colour"]), "\(o.id): \(names)")
            for c in rig.channels ?? [] { for t in c.tex.flatMap({ $0 }) { XCTAssertNotNil(Bundle.main.url(forResource: t, withExtension: nil), t) } }
            for p in rig.parts { XCTAssertNotNil(Bundle.main.url(forResource: p.tex, withExtension: nil), p.tex) }
        }
    }

    func testALookSavedBeforeOutfitsWearsEveryday() throws {
        let old = try JSONDecoder().decode(AvatarLook.self, from: Data(#"{"colours":{"Skin":2},"backdrop":"#D9EEE6"}"#.utf8))
        XCTAssertEqual(old.outfit, Outfit.all[0].id)
        XCTAssertEqual(old.colours["Skin"], 2)
        let gone = try JSONDecoder().decode(AvatarLook.self, from: Data(#"{"outfit":"no-such-outfit"}"#.utf8))
        XCTAssertEqual(gone.outfit, Outfit.all[0].id)
    }
}
