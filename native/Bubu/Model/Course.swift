import Foundation

// The course, exactly as the web app has it (exported by scripts/export-data.js).

struct Word: Codable, Hashable {
    let hanzi: String
    let pinyin: String
    let pos: String?
    let en: String
    /// the word's card id, kept when the exporter moves it to another stone ("qibu1-s0-1:8")
    var id: String? = nil
    /// a phrase's words, each taught in an earlier stone (我不懂 → 我, 不, 懂)
    var parts: [String]? = nil
}

struct Lesson: Codable, Identifiable {
    let id: String
    let title: String          // "起步1 U1.2 · 很高兴认识你！ Nice to meet you!"
    let words: [Word]

    /// "起步1 U1.2"
    var code: String { title.components(separatedBy: " · ").first ?? title }
    /// "很高兴认识你！ Nice to meet you!"
    var name: String {
        guard let r = title.range(of: " · ") else { return title }
        return String(title[r.upperBound...])
    }
}

struct Chapter: Codable {
    let unit: String           // the book: "起步 1"
    let title: String
    let lessons: [String]
}

struct Note: Codable, Hashable {
    let title: String
    let body: String
}

struct Turn: Codable, Hashable {
    let who: String            // "app" or "you"
    let hanzi: String
    let pinyin: String
    let en: String
    let free: Bool?
}

struct Dialogue: Codable, Identifiable {
    let id: String
    let title: String
    let lesson: String
    let turns: [Turn]
}

struct ReadingQuestion: Codable {
    let text: String
    let options: [String]
    let answer: Int
}

struct Reading: Codable, Identifiable {
    let id: String
    let chapter: Int
    let title: String
    let py: String
    let en: String
    let sentences: [[String]]  // tokens "汉字|pin yin|meaning", punctuation plain
    let translation: String
    let q: ReadingQuestion
    let allow: String?
}

struct PathPiece: Codable {
    let art: String
    let stone: String
    let dx: Double
    let dy: Double
    let w: Double
    let flip: Bool
    let behind: Bool
}

struct PathLayout: Codable {
    let headers: [String: String]
    let pieces: [PathPiece]
}

struct ArtSize: Codable {
    let w: Double
    let ar: Double
    let side: String
}

struct CourseData: Codable {
    let names: [String]
    let lessons: [Lesson]
    let chapters: [Chapter]
    let notes: [String: [Note]]
    let dialogues: [Dialogue]
    let readings: [Reading]
    let pathLayout: PathLayout
    let art: [String: ArtSize]
}

/// One flashcard per unique word. Ids match the web app: the id the course data gives the
/// word (the lesson and index where it was first taught, kept when it moves), or
/// "lessonId:index". Progress moves between the two without any mapping.
struct Card: Identifiable, Hashable {
    let id: String
    let lessonId: String
    let word: Word
}

final class Course {
    static let shared: Course = {
        do { return try Course.load() } catch { fatalError("course.json: \(error)") }
    }()

    let data: CourseData
    let cards: [Card]
    let cardById: [String: Card]
    let lessonById: [String: Lesson]
    let lessonOrder: [String: Int]
    /// chapter index for each lesson id
    let chapterOf: [String: Int]
    /// the character shown on each lesson's stone
    let hero: [String: String]

    var lessons: [Lesson] { data.lessons }
    var chapters: [Chapter] { data.chapters }

    let cardsByLesson: [String: [Card]]

    init(data: CourseData) {
        self.data = data
        var seen = Set<String>(), cards: [Card] = []
        for lesson in data.lessons {
            for (i, w) in lesson.words.enumerated() {
                // same rule as the web app: hanzi + meaning, first lesson wins
                let key = w.hanzi + "|" + Course.normEn(w.en)
                if seen.contains(key) { continue }
                seen.insert(key)
                cards.append(Card(id: w.id ?? "\(lesson.id):\(i)", lessonId: lesson.id, word: w))
            }
        }
        self.cards = cards
        cardsByLesson = Dictionary(grouping: cards, by: \.lessonId)
        cardById = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        lessonById = Dictionary(uniqueKeysWithValues: data.lessons.map { ($0.id, $0) })
        lessonOrder = Dictionary(uniqueKeysWithValues: data.lessons.enumerated().map { ($1.id, $0) })
        var ch: [String: Int] = [:]
        for (ci, c) in data.chapters.enumerated() { for l in c.lessons { ch[l] = ci } }
        chapterOf = ch
        hero = Course.heroes(data.lessons)
    }

    static func load(bundle: Bundle = .main) throws -> Course {
        guard let url = bundle.url(forResource: "course", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return Course(data: try JSONDecoder().decode(CourseData.self, from: Data(contentsOf: url)))
    }

    /// "Café, bar!" → "cafbar"-style key, as the web app's normEn
    static func normEn(_ s: String) -> String {
        String(s.lowercased().unicodeScalars.filter { ($0 >= "a" && $0 <= "z") || ($0 >= "0" && $0 <= "9") })
    }

    static func isHan(_ c: Character) -> Bool {
        c.unicodeScalars.contains { (0x3400...0x9FFF).contains($0.value) }
    }

    /// Each lesson's stone shows the first character of its words that no earlier stone used.
    static func heroes(_ lessons: [Lesson]) -> [String: String] {
        var used = Set<Character>(), out: [String: String] = [:]
        for l in lessons {
            let firsts = l.words.compactMap { $0.hanzi.first(where: isHan) }
            let all = l.words.flatMap { $0.hanzi.filter(isHan) }
            let c = firsts.first { !used.contains($0) } ?? all.first { !used.contains($0) } ?? firsts.first ?? "字"
            used.insert(c)
            out[l.id] = String(c)
        }
        return out
    }

    func cards(in lessonId: String) -> [Card] { cardsByLesson[lessonId] ?? [] }
    /// every chapter's words
    private(set) lazy var chapterCards: [[Card]] = chapters.map { ch in ch.lessons.flatMap { cardsByLesson[$0] ?? [] } }
    func notes(for lessonId: String) -> [Note] { data.notes[lessonId] ?? [] }
    /// the cards for each word, by its characters: to tell whether a sentence's words have been met
    private(set) lazy var cardsByHanzi: [String: [Card]] = Dictionary(grouping: cards) { $0.word.hanzi.filter(Course.isHan) }
    /// the cards whose word has each character in it
    private(set) lazy var cardsByChar: [Character: [Card]] = {
        var out: [Character: [Card]] = [:]
        for c in cards { for ch in Set(c.word.hanzi.filter(Course.isHan)) { out[ch, default: []].append(c) } }
        return out
    }()

    /// "起步 1 · Chapter 2": chapters are counted within their book
    func chapterLabel(_ ci: Int) -> String {
        let unit = chapters[ci].unit
        let n = chapters[0...ci].filter { $0.unit == unit }.count
        return "\(unit) · Chapter \(n)"
    }
}
