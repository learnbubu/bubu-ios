import SwiftUI
import UIKit

// The web app's colour tokens, day and night.
extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(UIColor { t in UIColor(hex: t.userInterfaceStyle == .dark ? dark : light) })
    }
    static let bg = Color(light: 0xFAF7F1, dark: 0x0A1420)
    static let panel = Color(light: 0xFFFFFF, dark: 0x121F2D)
    static let ink = Color(light: 0x172530, dark: 0xF1F5F9)
    static let muted = Color(light: 0x66768A, dark: 0x8A9DB3)
    static let line = Color(light: 0xE8E6DF, dark: 0x1F2F42)
    static let accent = Color(light: 0x2B776D, dark: 0x6C9DFC)
    static let accentSoft = Color(light: 0xD9ECE5, dark: 0x182B48)
    static let accentDark = Color(light: 0x1D645C, dark: 0x4F7FDC)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0B1626)
    static let gold = Color(light: 0xB7822E, dark: 0xF0B95A)
    static let good = Color(light: 0x1F8A6D, dark: 0x4CE1AD)
    static let again = Color(light: 0xD9695A, dark: 0xF08A7A)
    static let goodSoft = Color(light: 0xDAF1E3, dark: 0x112A2D)
    static let againSoft = Color(light: 0xFDE7E5, dark: 0x2B2230)
    static let todoHero = Color(light: 0x1D6B5C, dark: 0xA9C6FB)
    // practice tiles: pastel ground and ink, one per skill
    struct Tile { let bg: Color; let ink: Color }
    static let tiles: [String: Tile] = [
        "red": Tile(bg: Color(light: 0xFDE7E5, dark: 0x26232F), ink: Color(light: 0xE0574A, dark: 0xFF8A7A)),
        "blue": Tile(bg: Color(light: 0xDCF0FE, dark: 0x122136), ink: Color(light: 0x3B82F6, dark: 0x6C9DFC)),
        "green": Tile(bg: Color(light: 0xDAF1D3, dark: 0x112A2D), ink: Color(light: 0x0F8A68, dark: 0x4CE1AD)),
        "yellow": Tile(bg: Color(light: 0xFEEBBB, dark: 0x2A2B23), ink: Color(light: 0xDD8512, dark: 0xF5B03D)),
        "purple": Tile(bg: Color(light: 0xECE6FB, dark: 0x201F36), ink: Color(light: 0x7C5CD6, dark: 0xA78BFA)),
        "teal": Tile(bg: Color(light: 0xD8F0EF, dark: 0x10282C), ink: Color(light: 0x2A8B90, dark: 0x4FC9C4)),
        "orange": Tile(bg: Color(light: 0xFFE6D5, dark: 0x2C2219), ink: Color(light: 0xD9651C, dark: 0xFF9D5C)),
        "pink": Tile(bg: Color(light: 0xFBE3EE, dark: 0x2A1D2A), ink: Color(light: 0xC84A86, dark: 0xF28CBC)),
    ]
    // tone colours 1–4 and neutral
    static let tones: [Color] = [
        Color(light: 0xD4493F, dark: 0xFF7B70), Color(light: 0xC9861C, dark: 0xF3B54A),
        Color(light: 0x2C8F57, dark: 0x52D08A), Color(light: 0x2F6FB8, dark: 0x74A8FF),
        Color(light: 0x8A96A3, dark: 0x8A9DB3),
    ]
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

// Nunito for everything written in English, the system's PingFang for Chinese,
// Long Cang for the brush characters on the path stones.
extension Font {
    static func nunito(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        let face: String
        switch weight {
        case .black, .heavy: face = "Nunito-Black"
        case .bold: face = "Nunito-Bold"
        case .semibold: face = "Nunito-SemiBold"
        case .medium: face = "Nunito-SemiBold"
        default: face = "Nunito-Regular"
        }
        return .custom(face, size: size)
    }
    static func nunitoXB(_ size: CGFloat) -> Font { .custom("Nunito-ExtraBold", size: size) }
    static func hanzi(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
    static func brush(_ size: CGFloat) -> Font { .custom("LongCang-Regular", size: size) }
}

/// The tone (1–4, 5 = neutral) of one pinyin syllable, from its mark.
func toneOf(_ syllable: String) -> Int {
    for ch in syllable {
        if "āēīōūǖ".contains(ch) { return 1 }
        if "áéíóúǘ".contains(ch) { return 2 }
        if "ǎěǐǒǔǚ".contains(ch) { return 3 }
        if "àèìòùǜ".contains(ch) { return 4 }
    }
    return 5
}

/// Characters coloured by tone, when each character has its own syllable.
struct ToneText: View {
    let hanzi: String
    let pinyin: String
    var size: CGFloat = 28
    var weight: Font.Weight = .regular

    var body: some View {
        let syl = pinyin.split(whereSeparator: { $0 == " " }).map(String.init)
        let chars = Array(hanzi)
        let hanCount = chars.filter(Course.isHan).count
        var k = 0
        var t = Text("")
        for c in chars {
            if Course.isHan(c) && syl.count == hanCount {
                t = t + Text(String(c)).foregroundColor(Color.tones[toneOf(syl[k]) - 1])
                k += 1
            } else {
                t = t + Text(String(c)).foregroundColor(.ink)
            }
        }
        return t.font(.hanzi(size, weight))
    }
}

struct Card3D<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.line, lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 6)
    }
}

/// The chunky green button with a 3D base, as on the web app.
struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accent
    var base: Color = .accentDark
    var text: Color = .onAccent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.nunitoXB(17))
            .foregroundStyle(text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .background(base, in: RoundedRectangle(cornerRadius: 16, style: .continuous).offset(y: configuration.isPressed ? 0 : 4))
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.7), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed)
    }
}

/// The web's `--shadow`: a soft lift under panels.
extension View {
    func panelShadow() -> some View {
        shadow(color: .black.opacity(0.06), radius: 12, y: 6).shadow(color: .black.opacity(0.05), radius: 1.5, y: 1)
    }
    /// A panel with a thin line border, the web's `.card` look
    func panel(radius: CGFloat = 20) -> some View {
        background(Color.panel, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.line, lineWidth: 1))
    }
}

/// A thin rounded progress bar.
struct Bar: View {
    var value: Double
    var height: CGFloat = 6
    var fill: Color = .accent
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.line)
                Capsule().fill(fill).frame(width: g.size.width * min(1, max(0, value)))
            }
        }
        .frame(height: height)
    }
}

extension Lesson {
    /// "你好！" and "Hello! Sounds and survival" from the lesson's name
    var nameParts: (hanzi: String, en: String) {
        let n = name
        guard let i = n.firstIndex(where: { $0.isASCII && ($0.isLetter || $0 == "(") }), i != n.startIndex else { return (n, "") }
        return (n[..<i].trimmingCharacters(in: .whitespaces),
                n[i...].trimmingCharacters(in: CharacterSet(charactersIn: "() ")))
    }
}
