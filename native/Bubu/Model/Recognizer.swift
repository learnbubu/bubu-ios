import Foundation
import Speech
import AVFoundation

/// Listens for Mandarin once, as the web's recognizeOnce: live partial guesses,
/// settles when you've said the whole phrase or paused, and gives up after 12 s.
@MainActor
final class Recognizer {
    enum Failure { case notAllowed, unavailable, noSpeech }

    private lazy var recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private var engine = AVAudioEngine()
    private var generation = 0
    private var request: SFSpeechAudioBufferRecognitionRequest?
    /// The request the microphone feeds (from the audio thread): swapped when a held recording starts a new one.
    private let feed = Feed()
    /// Held (not settling on a pause): what was heard before the recogniser called it final on its own, and how many
    /// times it's been started again this hold.
    private var carried = ""
    private var restarts = 0
    private var taskGen = 0
    /// Held and let go: the microphone's off, the recogniser finishing what it heard
    private var releasing = false
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
    /// Where to keep what's heard, as a sound file (Speaking's voice notes play yours back); nil keeps nothing.
    var recordTo: URL?
    /// Settles by itself once you've paused (off for hold-to-talk: it waits for you to let go).
    var settlesOnPause = true
    /// Words and names to expect (the line's, the chat's people): heard more surely, fewer added or dropped.
    var hints: [String] = []
    private var file: AVAudioFile?

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Ask for the microphone and speech recognition. True when both are allowed.
    /// Speech recognition and the microphone both already allowed (nothing asked).
    static var allowed: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized && AVAudioApplication.shared.recordPermission == .granted
    }

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
        carried = ""; restarts = 0; releasing = false
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
                let req = newRequest()
                request = req
                feed.set(req)
                // (a fresh engine each time: one made under another audio route can't take the microphone's format,
                // and installing its tap throws, which is a crash)
                if !engine.isRunning { engine = AVAudioEngine() }
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                // no input yet (a call, or Bluetooth switching): installing a tap would throw
                guard format.sampleRate > 0, format.channelCount > 0 else { onError(.unavailable); end(); return }
                input.removeTap(onBus: 0)
                let report = onLevel
                file = recordTo.flatMap { try? AVAudioFile(forWriting: $0, settings: format.settings) }
                let keep = file
                let feed = feed
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in
                    feed.append(buf)
                    try? keep?.write(from: buf)
                    let level = Recognizer.level(of: buf)
                    DispatchQueue.main.async { report(level) }
                }
                engine.prepare()
                try engine.start()
                startTask(recognizer, req)
                // (held: as long as you hold, within reason)
                let limit: Double = settlesOnPause ? 12 : 60
                watchdog = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(limit))
                    guard !Task.isCancelled else { return }
                    self?.settle()
                }
            } catch {
                onError(.unavailable); end()
            }
        }
    }

    private func newRequest() -> SFSpeechAudioBufferRecognitionRequest {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if !hints.isEmpty { req.contextualStrings = Array(hints.prefix(100)) }
        if let recognizer, recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = false }
        return req
    }

    private func startTask(_ recognizer: SFSpeechRecognizer, _ req: SFSpeechAudioBufferRecognitionRequest) {
        taskGen += 1
        let g = taskGen
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor in
                // (a task given up on may still call back: only the current one counts)
                guard let self, self.taskGen == g else { return }
                self.handle(result, error)
            }
        }
    }

    /// Held, and the recogniser stopped by itself (a pause it took for the end, or silence): it listens on, a new
    /// request on the same microphone, what was heard so far kept in front (the owner, 23 Oct 2026: "sometimes I
    /// noticed it thinks that I finished talking"). False when it can't (then it settles as before).
    private func carryOn() -> Bool {
        guard !settlesOnPause, !finished, !releasing, restarts < 6, let recognizer, recognizer.isAvailable else { return false }
        restarts += 1
        carried = last.first ?? carried
        task?.cancel()
        let req = newRequest()
        request = req
        feed.set(req)
        startTask(recognizer, req)
        return true
    }

    private func handle(_ result: SFSpeechRecognitionResult?, _ error: Error?) {
        guard !finished else { return }
        if let result {
            // up to eight guesses, best first, as the web asks for (held: after what was heard before a restart)
            let alts = Array(result.transcriptions.prefix(8).map { carried + $0.formattedString })
            guard !alts.isEmpty else { return }
            last = alts
            if result.isFinal {
                if carryOn() { return }
                return deliver(alts)
            }
            onInterim(alts)
            if acceptEarly(alts) { return deliver(alts) }
            // the recogniser doesn't stop on silence: settle once you've paused
            guard settlesOnPause else { return }
            quiet?.cancel()
            quiet = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1400))
                guard !Task.isCancelled else { return }
                self?.settle()
            }
        } else if error != nil {
            if carryOn() { return }
            if releasing { return deliver(last) }
            settle()
        }
    }

    func settle() {
        guard !finished else { return }
        // held and let go: the microphone off, a moment for the recogniser's final word on all of it (judged on what
        // it last guessed, the end of what you said could be missing)
        if !settlesOnPause && !releasing && !last.isEmpty && task != nil {
            releasing = true
            if engine.isRunning { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
            feed.set(nil)
            request?.endAudio()
            let gen = generation
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                guard let self, self.generation == gen, !self.finished else { return }
                self.deliver(self.last)
            }
            return
        }
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
        file = nil      // (closes the recording)
        feed.set(nil)
        request?.endAudio()
        task?.cancel()
        task = nil; request = nil
        Sounds.shared.useForRecording(false)
        onEnd()
    }
}

/// The request the microphone's buffers go to, set on the main thread and read on the audio thread.
private final class Feed: @unchecked Sendable {
    private let lock = NSLock()
    private var req: SFSpeechAudioBufferRecognitionRequest?
    func set(_ r: SFSpeechAudioBufferRecognitionRequest?) { lock.lock(); req = r; lock.unlock() }
    func append(_ buf: AVAudioPCMBuffer) { lock.lock(); let r = req; lock.unlock(); r?.append(buf) }
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
