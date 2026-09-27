import AVFoundation
import UIKit

/// Chinese read aloud, as the web's speak(): zh-CN, a little slower than normal,
/// the best-sounding voice installed.
final class Speech {
    static let shared = Speech()
    private let synth = AVSpeechSynthesizer()
    /// the web's default rate of 0.85, on AVSpeech's scale where 0.5 is normal speed
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate * 0.85

    lazy var voice: AVSpeechSynthesisVoice? = {
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

/// The web's sound effects: correct, wrong, complete and goal.
final class Sounds {
    static let shared = Sounds()
    private var players: [String: AVAudioPlayer] = [:]
    private var lastGoal = Date.distantPast
    var enabled = true

    private init() {
        for name in ["correct", "wrong", "complete", "goal"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "mp3"),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.volume = 0.6
                p.prepareToPlay()
                players[name] = p
            }
        }
    }

    private var active = false
    private var recording = false
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
        guard let p = players[name] else { return }
        p.currentTime = 0
        p.play()
    }
}
