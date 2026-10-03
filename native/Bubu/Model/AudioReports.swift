import Foundation

/// Clips flagged from a lesson's feedback ("this sounds wrong"), kept on the phone until they're
/// copied from Settings and sent over, so a bad clip takes one tap to report instead of a
/// screenshot (the owner, 3 Oct 2026). The copied list names each clip as the voice tools do.
enum AudioReports {
    struct Report: Codable, Hashable {
        let text: String
        let clip: String
        let reason: String
        let at: Date
    }

    static let reasons = ["Wrong tone", "Wrong sound or word", "Noise, cut off or glitchy", "Sounds unnatural"]
    private static let key = "audioReports"

    static var all: [Report] {
        guard let d = UserDefaults.standard.data(forKey: key),
              let r = try? JSONDecoder().decode([Report].self, from: d) else { return [] }
        return r
    }

    private static func save(_ r: [Report]) {
        if let d = try? JSONEncoder().encode(r) { UserDefaults.standard.set(d, forKey: key) }
    }

    static func add(_ text: String, reason: String) {
        var r = all.filter { $0.text != text }
        r.append(Report(text: text, clip: Speech.clipName(text), reason: reason, at: Date()))
        save(r)
    }

    static func has(_ text: String) -> Bool { all.contains { $0.text == text } }

    static func clear() { UserDefaults.standard.removeObject(forKey: key) }

    /// One line a clip: its file name, its text and why.
    static var exportText: String {
        all.map { "\($0.clip) | \($0.text) | \($0.reason)" }.joined(separator: "\n")
    }
}
