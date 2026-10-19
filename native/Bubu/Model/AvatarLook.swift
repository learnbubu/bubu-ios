import Foundation

/// What the learner's avatar wears: an outfit (its own rig, made in Studio), a swatch for each of its colours (by the
/// colour's name, as Studio calls it: Skin and Hair colour are in every outfit, so they carry from one to the next),
/// and the colour of the disc it stands on. Kept on the phone.
struct AvatarLook: Codable, Equatable {
    var outfit: String = Outfit.all[0].id
    var colours: [String: Int] = [:]
    var backdrop: String = AvatarBackdrop.colours[0].hex

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let o = (try? c.decode(String.self, forKey: .outfit)) ?? Outfit.all[0].id
        outfit = Outfit.all.contains { $0.id == o } ? o : Outfit.all[0].id
        colours = (try? c.decode([String: Int].self, forKey: .colours)) ?? [:]
        backdrop = (try? c.decode(String.self, forKey: .backdrop)) ?? AvatarBackdrop.colours[0].hex
    }

    static let key = "avatarLook"
    static func load() -> AvatarLook {
        var l = UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(AvatarLook.self, from: $0) } ?? AvatarLook()
        if let o = Launch.outfit, Outfit.all.contains(where: { $0.id == o }) { l.outfit = o }   // (the Mac's checks)
        return l
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
}

/// An outfit: a rig in the bundle (Studio's App avatar export of a scene on the same skeleton), and what it's called.
struct Outfit: Identifiable, Equatable {
    let id: String
    let name: String

    static let all = [
        Outfit(id: "relaxed", name: "Everyday"),
        Outfit(id: "jade-dragon-costume", name: "Jade Dragon"),
    ]
    static func named(_ id: String) -> Outfit { all.first { $0.id == id } ?? all[0] }
}
