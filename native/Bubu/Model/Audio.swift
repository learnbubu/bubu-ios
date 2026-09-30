import AVFoundation
import CryptoKit
import UIKit

/// Chinese read aloud, as the web's speak(): zh-CN, a little slower than normal,
/// the best-sounding voice installed.
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()
    /// the speed from Settings (the web's 0.85 by default), on AVSpeech's scale where 0.5 is normal
    var rate: Float { Float(ProgressStore.current?.prefs.rate ?? 0.85) * AVSpeechUtteranceDefaultSpeechRate }

    /// the voice chosen in Settings, if it's still installed
    var voice: AVSpeechSynthesisVoice? {
        if let id = ProgressStore.current?.prefs.voiceURI, let v = AVSpeechSynthesisVoice(identifier: id) { return v }
        return bestVoice
    }

    /// Every Chinese voice on the phone, best first. Listing the voices can take many
    /// seconds the first time (it loads the voice catalogue), so it's done off the main
    /// thread at launch (`loadVoices`) and read from here; empty until it's loaded.
    static var chineseVoices: [AVSpeechSynthesisVoice] { voicesLock.withLock { cachedVoices ?? [] } }
    static var voicesLoaded: Bool { voicesLock.withLock { cachedVoices != nil } }
    private static let voicesLock = NSLock()
    private static var cachedVoices: [AVSpeechSynthesisVoice]?

    /// Look the voices up in the background; again whenever the phone's voices change.
    static func loadVoices() {
        DispatchQueue.global(qos: .utility).async {
            let list = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("cmn") }
                .sorted { score($0) > score($1) }
            voicesLock.withLock { cachedVoices = list }
            DispatchQueue.main.async { shared.cachedBest = nil }
        }
    }

    static func score(_ v: AVSpeechSynthesisVoice) -> Int {
        var s = v.language == "zh-CN" ? 3 : 1
        switch v.quality {
        case .premium: s += 10
        case .enhanced: s += 8
        default: break
        }
        if ["Lilian", "Tingting", "Meijia", "Lili", "Yu-shu"].contains(where: v.name.contains) { s += 4 }
        return s
    }

    /// The best Chinese voice installed, looked up again whenever the phone's voices
    /// change (a Premium or Enhanced voice downloaded in iOS Settings is used straight away).
    fileprivate var cachedBest: AVSpeechSynthesisVoice??
    private var voicesObserver: NSObjectProtocol?
    var bestVoice: AVSpeechSynthesisVoice? {
        if voicesObserver == nil {
            voicesObserver = NotificationCenter.default.addObserver(
                forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil, queue: .main) { _ in
                Speech.loadVoices()
            }
        }
        if let c = cachedBest { return c }
        // until the list is loaded, the system's zh-CN voice (quick to get) stands in
        guard Self.voicesLoaded else { return AVSpeechSynthesisVoice(language: "zh-CN") }
        let v = Self.chineseVoices.first ?? AVSpeechSynthesisVoice(language: "zh-CN")
        cachedBest = .some(v)
        return v
    }

    func stop() {
        synth.stopSpeaking(at: .immediate)
        clipQueue.async { [self] in clip?.stop() }
    }

    // MARK: recorded clips

    /// Each character in the story has their own voice, and their clips a code of their own
    /// (tools/voice.py SPEAKERS uses the same codes). Bùbù, who says every word, is k.
    static let speakerCodes = ["马克": "mk", "小雨": "xy", "林小雨": "xy", "陈明": "cm",
                               "陈妈妈": "mm", "陈爸爸": "bb", "朵朵": "dd"]

    /// The name of the recorded clip for a text (tools/voice.py makes them under the same
    /// names): the voice's code (k for Bùbù, or the speaker's), then the first 16 hex digits
    /// of the text's SHA-256.
    static func clipName(_ text: String, speaker: String? = nil) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hash = SHA256.hash(data: Data(t.utf8)).prefix(8).map { String(format: "%02x", $0) }.joined()
        return (speaker.flatMap { speakerCodes[$0] } ?? "k") + "_" + hash
    }

    /// The clip for a text, if the app has one: in the speaker's voice when there's one of
    /// those, else in Bùbù's.
    static func clipURL(_ text: String, speaker: String? = nil) -> URL? {
        if speaker.flatMap({ speakerCodes[$0] }) != nil,
           let u = Bundle.main.url(forResource: clipName(text, speaker: speaker), withExtension: "mp3") { return u }
        return Bundle.main.url(forResource: clipName(text), withExtension: "mp3")
    }

    /// Slow is the same clip played at this rate (its pitch kept).
    static let slowClipRate: Float = 0.7
    private let clipQueue = DispatchQueue(label: "bubu.voice")
    private var clip: AVAudioPlayer?

    /// Plays a clip off the main thread (preparing a player waits on the audio hardware).
    private func play(_ url: URL, rate: Float) {
        clipQueue.async { [self] in
            clip?.stop()
            guard let p = try? AVAudioPlayer(contentsOf: url) else { return }
            // at its own speed it's played untouched: changing the rate stretches the sound
            if abs(rate - 1) > 0.02 {
                p.enableRate = true
                p.rate = rate
            }
            clip = p
            p.play()
        }
    }

    /// Said by itself (an exercise's prompt, the answer in the feedback): what `Autoplay` picked,
    /// nil for nothing. Goes through `speak`, so the same audio session as everything else.
    func autoSpeak(_ text: String?, always: Bool = false, within gap: TimeInterval = Speech.repeatGap) {
        guard let text, !text.isEmpty else { return }
        // just heard (the new-word card said it, then its first exercise would again): once is enough
        // (not for listening, where the sound is the question: that always plays)
        if !always, text == lastText, Date().timeIntervalSince(lastAt) < gap { return }
        speak(text)
    }
    /// An exercise doesn't say again by itself what was said this recently.
    static let repeatGap: TimeInterval = 12
    private var lastText = ""
    private var lastAt = Date.distantPast

    /// Said once: there's no Chinese voice, or there's a far better one to download.
    private func voiceTips() {
        let d = UserDefaults.standard
        guard Self.voicesLoaded else { return }
        if Self.chineseVoices.isEmpty {
            guard !d.bool(forKey: "noVoiceTip") else { return }
            d.set(true, forKey: "noVoiceTip")
            Moments.shared.toast("No Chinese voice on this phone, so audio is silent. Add one in Settings → Accessibility → Spoken Content → Voices.")
        } else if let v = voice, v.quality == .default, !d.bool(forKey: "voiceTip") {
            d.set(true, forKey: "voiceTip")
            Moments.shared.toast("Tip: for a far more natural voice, go to iPhone Settings → Accessibility → Spoken Content → Voices → Chinese (China mainland) and download Lilian (Premium) or Tingting (Enhanced).")
        }
    }

    /// The 🐢 plays at this fraction of the normal speed (the speed chosen in Settings).
    static let slowFactor: Float = 0.6

    /// The slow rate for a normal one: always slower than it (it used to be a fixed rate,
    /// which was no slower at all for someone who had turned the speed down).
    static func slowRate(_ normal: Float) -> Float {
        max(AVSpeechUtteranceMinimumSpeechRate, normal * slowFactor)
    }

    /// Says a text: a recorded clip in the speaker's voice (Bùbù's when no speaker is given, or
    /// the speaker has none), else the phone's own voice.
    func speak(_ text: String, slow: Bool = false, speaker: String? = nil) {
        // asked for twice at once (two parts of a screen both saying it): said once, not
        // cut off and started again
        if !slow, text == lastText, Date().timeIntervalSince(lastAt) < 0.6 { return }
        lastText = text; lastAt = Date()
        Sounds.shared.activate()
        // a recorded clip when there is one; the phone's own voice otherwise
        if let url = Self.clipURL(text, speaker: speaker) {
            synth.stopSpeaking(at: .immediate)
            let chosen = Float(ProgressStore.current?.prefs.rate ?? 0.85) / 0.85
            play(url, rate: slow ? Self.slowClipRate : min(1.2, max(0.6, chosen)))
            return
        }
        clipQueue.async { [self] in clip?.stop() }
        voiceTips()
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = slow ? Self.slowRate(rate) : rate
        u.pitchMultiplier = 1
        // speaking straight after stopping can be dropped by the synthesiser, so a word
        // cut short gets a moment to stop before the next one starts
        if synth.isSpeaking || synth.isPaused {
            synth.stopSpeaking(at: .immediate)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [synth] in synth.speak(u) }
        } else {
            synth.speak(u)
        }
    }
}

/// The web's sound effects: correct, wrong, complete and goal. Loaded on first use and
/// played off the main thread, since preparing a player waits on the audio hardware.
final class Sounds {
    static let shared = Sounds()
    private let queue = DispatchQueue(label: "bubu.sounds")
    private var players: [String: AVAudioPlayer] = [:]
    private var lastGoal = Date.distantPast
    private var active = false
    private var recording = false

    private init() {
        // iOS switches our audio off for a call, Siri, another app or the lock screen;
        // forget that it was on, so the next sound switches it back on
        let nc = NotificationCenter.default
        for name in [AVAudioSession.interruptionNotification, AVAudioSession.mediaServicesWereResetNotification,
                     UIApplication.willEnterForegroundNotification] {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.active = false }
        }
    }

    var enabled: Bool { ProgressStore.current?.prefs.sound ?? true }

    /// One audio setup for speech and effects, so neither cuts the other off.
    func activate() {
        guard !active, !recording else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            active = true
        } catch {
            active = false          // try again on the next sound
        }
    }

    /// Switch to the microphone for speaking practice, and back.
    func useForRecording(_ on: Bool) {
        let session = AVAudioSession.sharedInstance()
        recording = on
        if on {
            try? session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .duckOthers, .allowBluetooth])
            try? session.setActive(true)
        } else {
            // let other audio (music) come back up, then return to playback
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? session.setActive(true)
        }
        active = !on
    }

    func play(_ name: String) {
        guard enabled else { return }
        if name == "goal" { lastGoal = Date() }
        // the lesson-complete chime is dropped if the goal fanfare just played
        if name == "complete" && Date().timeIntervalSince(lastGoal) < 1.5 { return }
        activate()
        queue.async { [self] in
            if players[name] == nil, let url = Bundle.main.url(forResource: name, withExtension: "mp3")
                ?? Bundle.main.url(forResource: name, withExtension: "wav"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.volume = 0.6
                players[name] = p
            }
            guard let p = players[name] else { return }
            p.currentTime = 0
            p.play()
        }
    }
}
