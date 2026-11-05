import XCTest
@testable import Bubu

/// The turnaround Bùbù (Studio's app export, version 2: puppet-pinned limbs baked a frame at a time, five views), as
/// tools/art/avatar_replay.py plays the same files. The numbers here are read from those files on the PC.
final class TurnaroundTests: XCTestCase {
    func testItLoadsWithEveryFrameOfItsPoints() throws {
        let rig = try XCTUnwrap(AvatarRig.load("bubu-turn"), "bubu-turn.json, its pictures and bubu-turn-anim0.bin are in the app")
        XCTAssertEqual(rig.version, 2)
        XCTAssertEqual(rig.parts.count, 61)
        XCTAssertTrue(rig.parts.allSatisfy(\.isMesh))
        let a = try XCTUnwrap(rig.anims["Animation"])
        XCTAssertEqual(a.frames, 180)
        XCTAssertEqual(rig.meshPer, 11052)
        XCTAssertEqual(rig.baked[a.points ?? ""]?.count, 180 * 11052)
    }

    func testAMeshPartIsWhereItWasBaked() throws {
        let rig = try XCTUnwrap(AvatarRig.load("bubu-turn")), a = try XCTUnwrap(rig.anims["Animation"])
        let arm = try XCTUnwrap(rig.parts.firstIndex { $0.name == "armR" })
        var p: [Float] = []
        // (the front's waving arm, its first point: at frame 0 and frame 90 (3 s), and half way between frames 0 and 1)
        rig.meshPoints(arm, a, at: 0, into: &p)
        XCTAssertEqual(p[0], 991.3, accuracy: 0.05); XCTAssertEqual(p[1], 859.9, accuracy: 0.05)
        rig.meshPoints(arm, a, at: 3000, into: &p)
        XCTAssertEqual(p[0], 970.8, accuracy: 0.05); XCTAssertEqual(p[1], 380.3, accuracy: 0.05)
        XCTAssertEqual(p.count, 395 * 2)
    }

    func testOneViewShowsAtATime() throws {
        let rig = try XCTUnwrap(AvatarRig.load("bubu-turn")), a = try XCTUnwrap(rig.anims["Animation"])
        // (side left at the start, the front at 3 s: the other views' parts hidden)
        XCTAssertEqual(rig.sample(a, at: 0).opacity.filter { $0 > 0.01 }.count, 17)
        XCTAssertEqual(rig.sample(a, at: 3000).opacity.filter { $0 > 0.01 }.count, 21)
        let box = rig.fitAll()
        XCTAssertGreaterThan(box.w, 100); XCTAssertLessThan(box.w, 1254)
    }

    func testTheOutfitsStillLoad() {
        // (version 1 rigs, bones only, unchanged)
        for o in Outfit.all { XCTAssertNotNil(AvatarRig.load(o.id), o.id) }
    }
}
