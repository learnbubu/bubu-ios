import Foundation
import Speech
import AVFoundation

/// Listens for Mandarin once, as the web's recognizeOnce: live partial guesses,
/// settles when you've said the whole phrase or paused, and gives up after 12 s.
@MainActor
final class Recognizer {
    enum Failure { case notAllowed, unavailable, noSpeech }

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))
    private let engine = AVAudioEngine()
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
        Task {
            guard await Self.authorize() else { onError(.notAllowed); end(); return }
            guard let recognizer, recognizer.isAvailable else { onError(.unavailable); end(); return }
            do {
                Sounds.shared.useForRecording(true)
                let req = SFSpeechAudioBufferRecognitionRequest()
                req.shouldReportPartialResults = true
                if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = false }
                request = req
                let input = engine.inputNode
                let format = input.outputFormat(forBus: 0)
                input.removeTap(onBus: 0)
                input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buf, _ in req?.append(buf) }
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

    /// Stop everything. Always runs exactly once per start.
    func end() {
        guard !finished else { return }
        finished = true
        quiet?.cancel(); watchdog?.cancel()
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
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
