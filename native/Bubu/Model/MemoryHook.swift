import Foundation

/// One short line to remember a new word by, shown under its meaning on the meet card (the
/// first time the word is met): "好 = 女 woman + 子 child → good". Chapter 1's words have
/// hooks written by hand; other characters are built from their parts in CharData, and a
/// word of several characters from the words it's made of ("你好 = you + good → hello").
/// Where there's no sensible hook there's none; the full breakdown stays behind
/// "How it's built".
enum MemoryHook {
    /// Chapter 1's seventeen words, by hand.
    static let chapterOne: [String: String] = [
        "你": "你 = 亻 person + 尔 you",
        "好": "好 = 女 woman + 子 child → good",
        "你好": "你好 = you + good → hello",
        "我": "我 = 扌 hand + 戈 spear → I, me",
        "是": "是 = 日 sun over 正 right → is, yes",
        "谢谢": "谢 = 讠 words + 射 shè (sound): said twice → thank you",
        "再见": "再见 = 再 again + 见 see → goodbye",
        "叫": "叫 = 口 mouth + 丩 jiū (sound) → to call, be called",
        "名字": "名字 = 名 name + 字 character → name",
        "很": "很 = 彳 step + 艮 gěn (sound) → very",
        "高兴": "高兴 = 高 high + 兴 spirits rising → happy",
        "认识": "认识 = 认 recognise + 识 know → to know (someone)",
        "吗": "吗 = 口 mouth + 马 mǎ (sound) → a yes/no question",
        "呢": "呢 = 口 mouth + 尼 ní (sound) → asks it back: 你呢？ and you?",
        "你呢": "你呢 = 你 you + 呢 asks it back → and you?",
    ]
    /// Chapter 1's words with no sensible hook: 什么 (neither half means "what" alone) and
    /// 也 (a single shape with no parts).
    static let none: Set<String> = ["什么", "也"]

    /// The longest part name or meaning a hook will use: longer ones make it a sentence.
    static let maxLabel = 14

    /// The hook for a word just met, or nil.
    static func line(for c: Card) -> String? {
        let w = c.word
        if none.contains(w.hanzi) { return nil }
        if let h = chapterOne[w.hanzi] { return h }
        let han = w.hanzi.filter(Course.isHan).map(String.init)
        guard !han.isEmpty, han.count == w.hanzi.count else { return nil }
        if han.count == 1 { return charHook(han[0], gloss: w.gloss) }
        return wordHook(c)
    }

    /// "吗 = 口 mouth + 马 mǎ (sound) → gloss", from the character's meaning and sound parts;
    /// nil when a part has no role or no short name.
    static func charHook(_ ch: String, gloss: String) -> String? {
        let cd = CharData.shared
        guard let parts = cd.chars[ch]?.c, (2...3).contains(parts.count) else { return nil }
        var bits: [String] = []
        for part in parts {
            guard part.count > 1, let comp = part.first, part[1] == "m" || part[1] == "s" else { return nil }
            let sound = part[1] == "s"
            var names: [String] = cd.partNames[comp] ?? []
            if names.isEmpty, let info = cd.chars[comp] { names = [info.d ?? "", info.p ?? ""] }
            guard names.count > 1 else { return nil }
            let label = short(sound ? names[1] : names[0])
            guard !label.isEmpty, label.count <= maxLabel else { return nil }
            bits.append(sound ? "\(comp) \(label) (sound)" : "\(comp) \(label)")
        }
        return "\(ch) = " + bits.joined(separator: " + ") + " → " + gloss
    }

    /// "你好 = you + good → hello", from the words a phrase is made of (or its characters),
    /// each taught no later than the word itself; nil when a part isn't one.
    static func wordHook(_ c: Card) -> String? {
        let course = Course.shared
        let w = c.word
        let pieces = w.parts ?? w.hanzi.map(String.init)
        guard (2...3).contains(pieces.count) else { return nil }
        let here = course.lessonOrder[c.lessonId] ?? Int.max
        var glosses: [String] = []
        for p in pieces {
            guard let part = course.cardsByHanzi[p]?.min(by: { (course.lessonOrder[$0.lessonId] ?? Int.max) < (course.lessonOrder[$1.lessonId] ?? Int.max) }),
                  part.id != c.id, (course.lessonOrder[part.lessonId] ?? Int.max) <= here else { return nil }
            let g = short(part.word.gloss)
            guard !g.isEmpty, g.count <= maxLabel, g.lowercased() != w.gloss.lowercased() else { return nil }
            glosses.append(g)
        }
        return "\(w.hanzi) = " + glosses.joined(separator: " + ") + " → " + w.gloss
    }

    /// A name's first sense: "good, well" → "good".
    static func short(_ s: String) -> String {
        (s.components(separatedBy: CharacterSet(charactersIn: ",;(")).first ?? "").trimmingCharacters(in: .whitespaces)
    }
}
