import AVFoundation
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

    /// Every Chinese voice on the phone, best first.
    static var chineseVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("cmn") }
            .sorted { score($0) > score($1) }
    }

    static func score(_ v: AVSpeechSynthesisVoice) -> Int {
        var s = v.language == "zh-CN" ? 3 : 1
        switch v.quality {
        case .premium: s += 10
        case .enhanced: s += 8
        default: break
        }
        if ["Tingting", "Meijia", "Lili", "Yu-shu"].contains(where: v.name.contains) { s += 4 }
        return s
    }

    lazy var bestVoice: AVSpeechSynthesisVoice? = {
        let zh = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("zh") || $0.language.hasPrefix("cmn") }
        func score(_ v: AVSpeechSynthesisVoice) -> Int {
            var s = 0
            if v.language == "zh-CN" { s += 3 } else { s += 1 }
            switch v.quality {
            case .premium: s += 10
            case .enhanced: s += 8
            default: break
            }
            if ["Tingting", "Meijia", "Lili", "Yu-shu"].contains(where: v.name.contains) { s += 4 }
            return s
        }
        return zh.max { score($0) < score($1) } ?? AVSpeechSynthesisVoice(language: "zh-CN")
    }()

    func speak(_ text: String, slow: Bool = false) {
        Sounds.shared.activate()
        synth.stopSpeaking(at: .immediate)
        let u = AVSpeechUtterance(string: text)
        u.voice = voice
        u.rate = slow ? AVSpeechUtteranceDefaultSpeechRate * 0.5 : rate
        u.pitchMultiplier = 1
        synth.speak(u)
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

    private init() {}

    var enabled: Bool { ProgressStore.current?.prefs.sound ?? true }

    /// One audio setup for speech and effects, so neither cuts the other off.
    func activate() {
        guard !active, !recording else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        active = true
    }

    /// Switch to the microphone for speaking practice, and back.
    func useForRecording(_ on: Bool) {
        let session = AVAudioSession.sharedInstance()
        recording = on
        if on {
            try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
            try? session.setActive(true, options: .notifyOthersOnDeactivation)
        } else {
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
            if players[name] == nil, let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
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
