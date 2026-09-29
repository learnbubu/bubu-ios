import Foundation
import Speech
import AVFoundation

/// Listens for Mandarin once, as the web's recognizeOnce: live partial guesses,
/// settles when you've said the whole phrase or paused, and gives up after 12 s.
@MainActor
final class Recognizer {
    enum Failure { case notAllowed, unavailable, noSpeech }

    private lazy var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private lazy var engine = AVAudioEngine()
    private var generation = 0
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var last: [String] = []
    private var quiet: Task<Void, Never>?
    private var watchdog: Task<Void, Never>?
    private var finished = true

    var onInterim: ([String]) -> Void = { _ in }
    var acceptEarly: ([String]) -> Bool = { _ in false }
    var onResult: ([String]) -> Void = { _ in }
    var onError: (Failure) -> Void = { _ in }
    var onEnd: () -> Void = {}
    /// How loud the microphone is, 0…1, with every buffer heard (a few dozen times a second; the
    /// speaking button's waveform).
    var onLevel: (Float) -> Void = { _ in }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Ask for the microphone and speech recognition. True when both are allowed.
    static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func start() {
        guard finished else { return }
        finished = false
        last = []
        generation += 1
        let gen = generation
        Task {
            let allowed = await Self.authorize()
            // stopped while we were asking: don't turn the microphone on after all
            guard !finished, gen == generation else { return }
            guard allowed else { onError(.notAllowed); end(); return }
            guard let recognizer, recognizer.isAvailable else { onError(.unavailable); end(); return }
            do {
                Sounds.shared.useForRecording(true)
                let req = SFSpeechAudioBufferRecognitionRequest()
                req.shouldReportPartialResults = true
                if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = false }
                request = req
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                // no input yet (a call, or Bluetooth switching): installing a tap would throw
                guard format.sampleRate > 0, format.channelCount > 0 else { onError(.unavailable); end(); return }
                input.removeTap(onBus: 0)
                let report = onLevel
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buf, _ in
                    req?.append(buf)
                    let level = Recognizer.level(of: buf)
                    DispatchQueue.main.async { report(level) }
                }
                engine.prepare()
                try engine.start()
                task = recognizer.recognitionTask(with: req) { [weak self] result, error in
                    Task { @MainActor in self?.handle(result, error) }
                }
                watchdog = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(12))
                    guard !Task.isCancelled else { return }
                    self?.settle()
                }
            } catch {
                onError(.unavailable); end()
            }
        }
    }

    private func handle(_ result: SFSpeechRecognitionResult?, _ error: Error?) {
        guard !finished else { return }
        if let result {
            // up to eight guesses, best first, as the web asks for
            let alts = Array(result.transcriptions.prefix(8).map(\.formattedString))
            guard !alts.isEmpty else { return }
            last = alts
            if result.isFinal { return deliver(alts) }
            onInterim(alts)
            if acceptEarly(alts) { return deliver(alts) }
            // the recogniser doesn't stop on silence: settle once you've paused
            quiet?.cancel()
            quiet = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1400))
                guard !Task.isCancelled else { return }
                self?.settle()
            }
        } else if error != nil {
            settle()
        }
    }

    func settle() {
        guard !finished else { return }
        if last.isEmpty { onError(.noSpeech); end() } else { deliver(last) }
    }

    private func deliver(_ alts: [String]) {
        guard !finished else { return }
        onResult(alts)
        end()
    }

    /// A buffer's loudness, 0 (quiet room) to 1 (speaking up): its RMS in decibels,
    /// -50 dB to -12 dB mapped onto 0…1.
    nonisolated static func level(of buf: AVAudioPCMBuffer) -> Float {
        guard let data = buf.floatChannelData else { return 0 }
        let n = Int(buf.frameLength)
        guard n > 0 else { return 0 }
        let samples = data[0]
        var sum: Float = 0
        for i in 0..<n { sum += samples[i] * samples[i] }
        let rms = (sum / Float(n)).squareRoot()
        guard rms > 0 else { return 0 }
        let db = 20 * log10(rms)
        return min(1, max(0, (db + 50) / 38))
    }

    /// Stop everything. Always runs exactly once per start.
    func end() {
        guard !finished else { return }
        finished = true
        quiet?.cancel(); watchdog?.cancel()
        if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        request?.endAudio()
        task?.cancel()
        task = nil; request = nil
        Sounds.shared.useForRecording(false)
        onEnd()
    }
}

/// Scoring what was heard against what was asked, as the web's scoreSpeech.
enum SpeechScore {
    enum Level { case exact, close, no }

    static func clean(_ s: String) -> String {
        String(s.filter { !"，。！？、,.!?·…\"'“” ".contains($0) && !$0.isWhitespace })
    }

    /// Has a partial already contained the whole phrase? Only then settle early.
    static func saidWhole(_ expected: String, _ alts: [String]) -> Bool {
        let exp = clean(expected)
        guard !exp.isEmpty else { return false }
        return alts.contains { let t = clean($0); return !t.isEmpty && t.contains(exp) }
    }

    /// One character of the phrase asked for, and whether it was heard (nil: punctuation,
    /// which isn't judged).
    struct Mark: Equatable {
        let char: Character
        let heard: Bool?
    }

    /// Whether a character is said aloud (and so judged), not punctuation or a space.
    static func isSpoken(_ ch: Character) -> Bool { !clean(String(ch)).isEmpty }

    /// Two characters that sound the same apart from the tone: speaking is judged on the
    /// words, not the tones, and the recogniser often writes a homophone (她 for 他).
    static func sameSound(_ a: Character, _ b: Character) -> Bool {
        if a == b { return true }
        let chars = CharData.shared.chars
        guard let pa = chars[String(a)]?.p, let pb = chars[String(b)]?.p, !pa.isEmpty else { return false }
        return Pinyin.toneless(pa.lowercased()) == Pinyin.toneless(pb.lowercased())
    }

    /// Each character of `expected`, green if it was heard and red if it was missed: the
    /// characters in order that the best guess shares with it (their longest common run,
    /// gaps allowed), punctuation stripped from both.
    static func marks(_ expected: String, _ alts: [String],
                      same: (Character, Character) -> Bool = SpeechScore.sameSound) -> [Mark] {
        let target = Array(expected)
        let judged = target.indices.filter { isSpoken(target[$0]) }
        let exp = judged.map { target[$0] }
        var best = Set<Int>()
        for a in alts {
            let hits = commonHits(exp, Array(clean(a)), same)
            if hits.count > best.count { best = hits }
        }
        var out: [Mark] = []
        var k = 0
        for (i, ch) in target.enumerated() {
            if k < judged.count && judged[k] == i {
                out.append(Mark(char: ch, heard: best.contains(k)))
                k += 1
            } else {
                out.append(Mark(char: ch, heard: nil))
            }
        }
        return out
    }

    /// The positions in `a` of a longest common subsequence of `a` and `b`.
    static func commonHits(_ a: [Character], _ b: [Character], _ same: (Character, Character) -> Bool) -> Set<Int> {
        let n = a.count, m = b.count
        guard n > 0, m > 0 else { return [] }
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                dp[i][j] = same(a[i], b[j]) ? dp[i + 1][j + 1] + 1 : max(dp[i + 1][j], dp[i][j + 1])
            }
        }
        var hits = Set<Int>()
        var i = 0, j = 0
        while i < n && j < m {
            if same(a[i], b[j]) && dp[i][j] == dp[i + 1][j + 1] + 1 {
                hits.insert(i); i += 1; j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }
        return hits
    }

    /// The share of the judged characters that were heard (1 when nothing is judged).
    static func heardShare(_ marks: [Mark]) -> Double {
        let judged = marks.compactMap(\.heard)
        guard !judged.isEmpty else { return 1 }
        return Double(judged.filter { $0 }.count) / Double(judged.count)
    }

    /// Lenient: a pass when the old scoring says close enough (or the word practised was
    /// heard), or when at least 70% of the characters were heard, homophones counting.
    static func passes(_ expected: String, _ alts: [String], keyword: String?,
                       same: (Character, Character) -> Bool = SpeechScore.sameSound) -> Bool {
        if score(expected, alts, keyword: keyword).level != .no { return true }
        return heardShare(marks(expected, alts, same: same)) >= 0.7
    }

    /// `keyword` is the word being practised: hearing it back is a pass even if the rest drifts.
    static func score(_ expected: String, _ alts: [String], keyword: String?) -> (level: Level, heard: String) {
        let exp = clean(expected)
        var best: (level: Level, heard: String, ratio: Double) = (.no, alts.first ?? "", 0)
        for a in alts {
            let t = clean(a)
            if t.isEmpty { continue }
            if t == exp { return (.exact, a) }
            if t.contains(exp) || exp.contains(t) { best = (.close, a, 0.95); continue }
            let set = Set(t)
            let hit = Double(exp.filter { set.contains($0) }.count) / Double(max(1, exp.count))
            if hit > best.ratio { best = (hit >= 0.7 ? .close : .no, a, hit) }
        }
        if best.level != .exact, let k = keyword.map(clean), !k.isEmpty {
            for a in alts where clean(a).contains(k) { return (.close, a) }
        }
        return (best.level, best.heard)
    }
}
