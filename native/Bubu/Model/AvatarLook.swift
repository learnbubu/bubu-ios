import Foundation

/// What the learner's avatar wears: a swatch for each of its colours (by the colour's name, as Studio calls it), and
/// the colour of the disc it stands on. Kept on the phone.
struct AvatarLook: Codable, Equatable {
    var colours: [String: Int] = [:]
    var backdrop: String = AvatarBackdrop.colours[0].hex

    static let key = "avatarLook"
    static func load() -> AvatarLook {
        guard let d = UserDefaults.standard.data(forKey: key), let l = try? JSONDecoder().decode(AvatarLook.self, from: d) else { return AvatarLook() }
        return l
    }
    func save() {
        if let d = try? JSONEncoder().encode(self) { UserDefaults.standard.set(d, forKey: Self.key) }
    }
}
