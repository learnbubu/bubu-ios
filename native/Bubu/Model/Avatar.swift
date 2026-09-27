import SwiftUI

/// Your avatar's look, as the web saves it in prefs.avatar.
struct AvatarConfig: Codable, Equatable {
    var body = "male", tone = "light", hair = "bob", hairColour = "darkbrown"
    var top = "cream-hoodie", bottom = "blue-trousers", shoes = "cream-trainers"
    var eyes = "open", brows = "none", mouth = "smile", accessory = "none"
    var version: Int? = 3
    var outfit: String?                       // the v2 catalogue's whole-look id

    subscript(key: String) -> String {
        get {
            switch key {
            case "body": return body; case "tone": return tone; case "hair": return hair; case "hairColour": return hairColour
            case "top": return top; case "bottom": return bottom; case "shoes": return shoes; case "eyes": return eyes
            case "brows": return brows; case "mouth": return mouth; case "accessory": return accessory
            default: return ""
            }
        }
        set {
            switch key {
            case "body": body = newValue; case "tone": tone = newValue; case "hair": hair = newValue; case "hairColour": hairColour = newValue
            case "top": top = newValue; case "bottom": bottom = newValue; case "shoes": shoes = newValue; case "eyes": eyes = newValue
            case "brows": brows = newValue; case "mouth": mouth = newValue; case "accessory": accessory = newValue
            default: break
            }
        }
    }

    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func s(_ k: CodingKeys) -> String? { try? c.decode(String.self, forKey: k) }
        let d = AvatarConfig.blank
        body = s(.body) ?? d.body; tone = s(.tone) ?? d.tone; hair = s(.hair) ?? d.hair; hairColour = s(.hairColour) ?? d.hairColour
        top = s(.top) ?? d.top; bottom = s(.bottom) ?? d.bottom; shoes = s(.shoes) ?? d.shoes
        eyes = s(.eyes) ?? d.eyes; brows = s(.brows) ?? d.brows; mouth = s(.mouth) ?? d.mouth; accessory = s(.accessory) ?? d.accessory
        version = try? c.decode(Int.self, forKey: .version); outfit = s(.outfit)
    }
    private static let blank: AvatarConfig = { var a = AvatarConfig(); a.version = nil; return a }()
}

/// The modular wardrobe: full-canvas layers stacked in order (web: makeModularAvatar).
final class Wardrobe {
    static let shared = Wardrobe()
    private let data: [String: Any]
    static let keys = ["body", "tone", "hair", "hairColour", "top", "bottom", "shoes", "eyes", "brows", "mouth", "accessory"]
    static let legacyOutfits: [String: (top: String, bottom: String, shoes: String)] = [
        "hoodie_trousers": ("Cream hoodie", "Blue trousers", "Cream trainers"), "jacket": ("Yellow jacket", "Blue trousers", "Cream trainers"),
        "shorts": ("Cream hoodie", "Teal shorts", "Cream trainers"), "skirt": ("Cream hoodie", "Coral skirt", "Cream trainers"),
        "shoes": ("Cream hoodie", "Blue trousers", "Charcoal trainers"), "teal_tan": ("Teal hoodie", "Tan trousers", "Cream trainers"),
        "blue_charcoal": ("Blue sweatshirt", "Charcoal shorts", "Cream trainers"), "striped_blue": ("Striped top", "Blue shorts", "Cream trainers"),
        "dark_hoodie": ("Dark hoodie", "Blue trousers", "Cream trainers"), "coral_sweatshirt": ("Coral sweatshirt", "Blue trousers", "Cream trainers"),
        "cream_cardigan": ("Cream cardigan", "Blue trousers", "Cream trainers"), "tan_shorts": ("Cream hoodie", "Tan shorts", "Cream trainers"),
        "dark_trousers": ("Cream hoodie", "Charcoal trousers", "Cream trainers"), "cream_skirt": ("Cream hoodie", "Cream skirt", "Cream trainers"),
        "brown_shoes": ("Cream hoodie", "Blue trousers", "Brown shoes"),
    ]

    private init() {
        if let url = Bundle.main.url(forResource: "avatar", withExtension: "json"),
           let d = try? Data(contentsOf: url), let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            data = o
        } else { data = [:] }
    }

    private func dict(_ k: String) -> [String: Any] { data[k] as? [String: Any] ?? [:] }
    private func nested(_ k: String, _ sub: String) -> [String: Any] { dict(k)[sub] as? [String: Any] ?? [:] }

    var defaults: AvatarConfig {
        var a = AvatarConfig()
        for (k, v) in dict("defaults") { if let s = v as? String { a[k] = s } }
        a.version = 3
        return a
    }

    /// The choices for one part of the look.
    func choices(_ s: AvatarConfig, _ key: String) -> [String] {
        switch key {
        case "tone": return ["light", "warm", "tan", "brown", "deep", "dark"].filter { nested("skin", s.body)[$0] != nil }
        case "body": return orderOf("skin")
        case "hairColour": return (dict("order")["hairColours"] as? [String: [String]])?[s.hair] ?? []
        default: return orderOf(key)
        }
    }
    /// A list's options in the web's order.
    private func orderOf(_ key: String) -> [String] { dict("order")[key] as? [String] ?? [] }

    func supported(_ s: AvatarConfig) -> Bool { Self.keys.allSatisfy { choices(s, $0).contains(s[$0]) } }

    /// A saved look, brought up to date; anything it can't use falls back to the defaults.
    func migrate(_ saved: AvatarConfig?) -> AvatarConfig {
        guard var old = saved else { return defaults }
        if old.version == 3 { old.body = "male"; return supported(old) ? old : defaults }
        var next = defaults
        if old.version == 2, let o = old.outfit.flatMap({ Self.legacyOutfits[$0] }) {
            let slug = { (s: String) in s.lowercased().replacingOccurrences(of: " ", with: "-") }
            old.top = slug(o.top); old.bottom = slug(o.bottom); old.shoes = slug(o.shoes)
        }
        let aliases = ["top": ["hoodie": "cream-hoodie", "jacket": "yellow-jacket"],
                       "bottom": ["shorts": "blue-shorts", "trousers": "blue-trousers", "skirt": "cream-skirt"],
                       "shoes": ["cream": "cream-trainers", "charcoal": "charcoal-trainers"]]
        for key in ["body", "tone", "hair", "hairColour", "top", "bottom", "shoes", "eyes", "brows", "mouth"] {
            let value = aliases[key]?[old[key]] ?? old[key]
            if choices(next, key).contains(value) { next[key] = value }
        }
        if !choices(next, "hairColour").contains(next.hairColour) { next.hairColour = choices(next, "hairColour").first ?? "darkbrown" }
        return next
    }

    /// The look with one part changed; a new hairstyle keeps its colour where it can.
    func change(_ s: AvatarConfig, _ key: String, _ value: String) -> AvatarConfig? {
        var n = s
        n[key] = value
        if key == "hair" && nested("hair", value)[n.hairColour] == nil {
            n.hairColour = nested("hair", value)["darkbrown"] != nil ? "darkbrown" : (choices(n, "hairColour").first ?? n.hairColour)
        }
        return supported(n) ? n : nil
    }

    /// The layers, bottom to top.
    func layers(_ s: AvatarConfig) -> [String] {
        guard supported(s) else { return [] }
        let parts: [Any?] = [nested("skin", s.body)[s.tone], dict("bottom")[s.bottom], dict("shoes")[s.shoes], dict("top")[s.top],
                             dict("eyes")[s.eyes], dict("brows")[s.brows], dict("mouth")[s.mouth],
                             nested("hair", s.hair)[s.hairColour], dict("accessory")[s.accessory]]
        return parts.compactMap { $0 as? String }
    }

    /// The layer a choice shows, for its thumbnail.
    func layer(for key: String, in s: AvatarConfig) -> String? {
        if key == "hair" || key == "hairColour" { return nested("hair", s.hair)[s.hairColour] as? String }
        return dict(key)[s[key]] as? String
    }
    func thumbnail(_ layer: String) -> String? { dict("thumbnails")[layer] as? String }
    func toneColour(_ id: String) -> Color {
        let hex = (dict("toneColours")[id] as? String ?? "#cccccc").dropFirst()
        return Color(UIColor(hex: UInt32(hex, radix: 16) ?? 0xCCCCCC))
    }

    static func label(_ id: String) -> String {
        if id == "darkbrown" { return "Dark brown" }
        return id.replacingOccurrences(of: "-", with: " ").capitalized
    }
}

/// The avatar, drawn from its layers.
struct AvatarView: View {
    let config: AvatarConfig
    var body: some View {
        ZStack {
            ForEach(Wardrobe.shared.layers(config), id: \.self) { l in
                Image(l).resizable().scaledToFit()
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
