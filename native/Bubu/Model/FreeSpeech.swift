import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Speaking freely in the Classroom's chats (the owner, 23 Oct 2026: "inside the classroom ... more freely say whatever
/// you think is right, and then [it] will come back: well done, that works well, or give you ways to improve or correct
/// you"): you're told what to say in English, say it your own way, and a tutor judges it. The tutor is Apple's on-phone
/// model (Apple Intelligence: free, private, offline; the owner's pick), where the phone has it. Elsewhere the chats keep
/// their set lines, judged as before.
struct SpeakingVerdict: Equatable {
    /// a sensible reply that fits, worded however
    var works: Bool
    /// a sentence or two for you, in English
    var comment: String
    /// how a native speaker might say it (a correction, or another natural way), with its pinyin
    var better: String?
    var betterPinyin: String?
    /// it was the example, or near enough, without asking the tutor
    var spotOn = false
}

enum FreeSpeech {
    /// The phone has the on-phone model, ready (iOS 26 and Apple Intelligence on).
    static var available: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), !Launch.underTests {
            if case .available = SystemLanguageModel.default.availability { return true }
        }
        #endif
        return false
    }

    /// What you said, judged: against the example first (said near enough, no need to ask), then by the tutor.
    /// `before` is the line you're answering; nil if the tutor couldn't be reached (the chat then judges as before).
    static func judge(said alts: [String], goal: Turn, before: Turn?) async -> SpeakingVerdict? {
        guard let heard = alts.first?.trimmingCharacters(in: .whitespacesAndNewlines), !heard.isEmpty else { return nil }
        if SpeechScore.score(goal.hanzi, alts, keyword: nil).level == .exact {
            return SpeakingVerdict(works: true, comment: "Spot on!", spotOn: true)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), available {
            return await ask(heard: heard, goal: goal, before: before)
        }
        #endif
        return nil
    }

    static let instructions = """
    You are a warm, encouraging Mandarin tutor for a beginner learning Chinese in an app. The learner is in a chat \
    conversation and speaks a reply aloud; you see what speech recognition heard (simplified characters; it may write a \
    word that sounds the same, so ignore those slips and ignore tones). Decide whether their reply is sensible, \
    understandable Chinese that fits the conversation and says roughly what they meant. It does NOT have to match the \
    example: any natural way of saying it works. Be generous to a beginner: small slips still work if the meaning is \
    clear. Write your comment in plain English, one or two short sentences, kind and specific (what was good, or what \
    to change). Give a better version only if a native speaker would say it differently or there is a mistake.
    """

    static func prompt(heard: String, goal: Turn, before: Turn?) -> String {
        var p = ""
        if let b = before { p += "\(b.name ?? "They") said: \(b.hanzi) (\(b.en))\n" }
        p += "The learner wanted to say: \(goal.en)\n"
        p += "An example answer: \(goal.hanzi)\n"
        p += "The learner said: \(heard)"
        return p
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private static func ask(heard: String, goal: Turn, before: Turn?) async -> SpeakingVerdict? {
        do {
            let session = LanguageModelSession(instructions: instructions)
            let r = try await session.respond(to: prompt(heard: heard, goal: goal, before: before), generating: TutorFeedback.self)
            let f = r.content
            let better = f.better.trimmingCharacters(in: .whitespacesAndNewlines)
            // (no "better" that's only what they said again)
            let same = SpeechScore.clean(better) == SpeechScore.clean(heard)
            return SpeakingVerdict(works: f.works, comment: f.comment,
                                   better: better.isEmpty || same ? nil : better,
                                   betterPinyin: better.isEmpty || same ? nil : f.betterPinyin)
        } catch {
            return nil
        }
    }
    #endif
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
struct TutorFeedback {
    @Guide(description: "true if the learner's reply is sensible, understandable Chinese that fits the conversation and means roughly what they wanted, even if worded differently from the example")
    var works: Bool
    @Guide(description: "One or two short, warm sentences in English for the learner: what was good, or gently what to change")
    var comment: String
    @Guide(description: "If there's a mistake or a native speaker would say it differently, the corrected or more natural sentence in simplified Chinese characters; otherwise an empty string")
    var better: String
    @Guide(description: "The pinyin with tone marks for the better sentence, or an empty string")
    var betterPinyin: String
}
#endif
