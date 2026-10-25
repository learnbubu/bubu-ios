import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Settings, simple (the owner, 14 Oct 2026: "so cluttered"): short rows in a few groups, each a
/// switch or a value and a chevron; the long explanations and the rarely used controls on the
/// pages they open. In the Home look; light only for now.
struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var cloud = Cloud.shared


    /// A kind of exercise switched on or off in every lesson (meanings are always asked).
    private func exerciseToggle(_ icon: String, _ tint: UInt32, _ title: String, _ dir: String) -> some View {
        SettingsToggle(icon: icon, tint: tint, title: title, on: Binding(
            get: { progress.selectedFocuses.contains(dir) },
            set: { on in
                var s = progress.selectedFocuses
                if on { s.insert(dir) } else { s.remove(dir) }
                s.formUnion(["recognize", "recall"])
                progress.prefs.focuses = StudySession.allDirs.filter(s.contains)
            }))
    }
    var body: some View {
        @Bindable var p = progress
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Settings").font(.nunito(32, .black)).tracking(-0.5).foregroundStyle(Home.ink).padding(.top, 8)

                // you: the account, and your name
                SettingsGroup {
                    SettingsLink(icon: "person.crop.circle.fill", tint: 0x1F7A6C, title: "Account",
                                 value: cloud.signedIn ? cloud.email : "Not signed in") { SettingsPage("Account") { AccountSection() } }
                    SettingsDivider()
                    SettingsRow(icon: "character.cursor.ibeam", tint: 0x7C5CD6, title: "Your name") {
                        TextField("Name", text: $p.name)
                            .font(.nunito(16, .bold)).foregroundStyle(Home.ink).multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                            .frame(maxWidth: 170)
                            .onChange(of: p.name) { _, v in if v.count > 24 { p.name = String(v.prefix(24)) }; progress.save() }
                    }
                }

                SettingsGroup("Learning") {
                    SettingsLink(icon: "textformat", tint: 0x3B82F6, title: "Pinyin", value: pinyinName) {
                        SettingsPage("Pinyin") {
                            ChoiceList(note: "Over the Chinese in exercises. Auto: over a word until you know it well, then a tap away. Hide when known: only until you've got a word right once.",
                                       options: [(PinyinMode.auto.rawValue, "Auto"), (PinyinMode.always.rawValue, "Always"), (PinyinMode.known.rawValue, "Hide when known")],
                                       value: Binding(get: { p.prefs.pinyin.rawValue }, set: { p.prefs.pinyin = PinyinMode(rawValue: $0) ?? .auto }))
                        }
                    }
                    SettingsDivider()
                    SettingsLink(icon: "keyboard", tint: 0x2A8B90, title: "Typing answers", value: typingName) {
                        SettingsPage("Typing answers") {
                            ChoiceList(note: "Automatic: pinyin in 起步 1–3, then characters with the Chinese keyboard. Characters always count.",
                                       options: [("auto", "Automatic"), ("pinyin", "Pinyin"), ("hanzi", "Characters")],
                                       value: Binding(get: { p.prefs.typing ?? "auto" }, set: { p.prefs.typing = $0 == "auto" ? nil : $0 }))
                        }
                    }
                    SettingsDivider()
                    SettingsToggle(icon: "paintpalette.fill", tint: 0xE0574A, title: "Tone colours", on: $p.prefs.toneColours)
                    SettingsDivider()
                    SettingsToggle(icon: "pencil.tip", tint: 0xC98A10, title: "Check my strokes", on: $p.prefs.checkStrokes)
                }

                // (what lessons ask of you: moved here from the Classroom's "What to study", gone; the owner, 25 Oct 2026)
                SettingsGroup("Lesson exercises") {
                    exerciseToggle("mic.fill", 0xE0574A, "Speaking", "speak")
                    SettingsDivider()
                    exerciseToggle("headphones", 0x3B82F6, "Listening", "listen")
                    SettingsDivider()
                    exerciseToggle("pencil.and.scribble", 0xC98A10, "Writing characters", "write")
                    SettingsDivider()
                    exerciseToggle("character.textbox", 0x2A8B90, "Pinyin", "pinyin")
                    SettingsDivider()
                    exerciseToggle("text.word.spacing", 0x7C5CD6, "Sentences", "sentence")
                }

                SettingsGroup("Sound") {
                    SettingsToggle(icon: "speaker.wave.2.fill", tint: 0x1F7A6C, title: "Sound effects", on: $p.prefs.sound)
                    SettingsDivider()
                    SettingsToggle(icon: "play.circle.fill", tint: 0x3B82F6, title: "Play audio automatically",
                                   on: Binding(get: { p.prefs.autoplay ?? true }, set: { p.prefs.autoplay = $0 }))
                    SettingsDivider()
                    SettingsLink(icon: "waveform", tint: 0x7C5CD6, title: "Voice and speed", value: nil) { SettingsPage("Voice and speed") { VoicePage() } }
                }

                SettingsGroup("Streak") {
                    SettingsLink(icon: "bell.fill", tint: 0xD9651C, title: "Reminders", value: p.prefs.reminders == true ? "On" : "Off") {
                        SettingsPage("Reminders") { ReminderSettings() }
                    }
                    SettingsDivider()
                    SettingsToggle(icon: "lamp.table.fill", tint: 0xB7822E, title: "Use spare lanterns for me", on: $p.prefs.autoRelight)
                }

                SettingsGroup("Help") {
                    SettingsLink(icon: "questionmark.circle.fill", tint: 0x1F7A6C, title: "How it works", value: nil) { SettingsPage("How it works") { HelpPage() } }
                    SettingsDivider()
                    SettingsLink(icon: "music.note", tint: 0xC84A86, title: "The four tones", value: nil) { SettingsPage("The four tones") { TonesPrimer() } }
                }

                SettingsGroup("Your data") {
                    SettingsLink(icon: "externaldrive.fill", tint: 0x5F6E7E, title: "Backup and reset", value: nil) { SettingsPage("Backup and reset") { DataPage() } }
                    if Tester.isTestBuild {
                        SettingsDivider()
                        SettingsLink(icon: "wrench.and.screwdriver.fill", tint: 0x5F6E7E, title: "Tester", value: nil) { SettingsPage("Tester") { TesterPage() } }
                    }
                }

                Text("步步 Bùbù \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · Character breakdowns from Make Me a Hanzi")
                    .font(.nunito(12)).foregroundStyle(Home.muted).frame(maxWidth: .infinity).padding(.top, 2)
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .environment(\.colorScheme, .light)
    }

    private var pinyinName: String {
        switch progress.prefs.pinyin { case .always: return "Always"; case .known: return "Hide when known"; default: return "Auto" }
    }
    private var typingName: String {
        switch progress.prefs.typing { case "pinyin": return "Pinyin"; case "hanzi": return "Characters"; default: return "Automatic" }
    }
}

// MARK: the pieces of a settings page

/// A group of rows on one card, with a small heading above.
struct SettingsGroup<C: View>: View {
    var title: String? = nil
    var content: C
    init(_ title: String? = nil, @ViewBuilder content: () -> C) { self.title = title; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased()).font(.nunito(12, .black)).tracking(1.3).foregroundStyle(Home.teal).padding(.leading, 4)
            }
            VStack(spacing: 0) { content }.homeCard()
        }
    }
}

struct SettingsDivider: View {
    var body: some View { Rectangle().fill(Home.line).frame(height: 1).padding(.leading, 57) }
}

/// The row's icon: white on a small coloured square, as iOS's own Settings.
private struct SettingsIcon: View {
    let name: String, tint: UInt32
    var body: some View {
        Image(systemName: name).font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(Color(UIColor(hex: tint)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SettingsRow<C: View>: View {
    let icon: String, tint: UInt32, title: String
    var control: C
    init(icon: String, tint: UInt32, title: String, @ViewBuilder control: () -> C) {
        self.icon = icon; self.tint = tint; self.title = title; self.control = control()
    }
    var body: some View {
        HStack(spacing: 13) {
            SettingsIcon(name: icon, tint: tint)
            Text(title).font(.nunito(16, .heavy)).foregroundStyle(Home.ink).lineLimit(1).minimumScaleFactor(0.85)
            Spacer(minLength: 8)
            control
        }
        .padding(.horizontal, 14).frame(minHeight: 54)
    }
}

struct SettingsToggle: View {
    let icon: String, tint: UInt32, title: String
    @Binding var on: Bool
    var body: some View {
        SettingsRow(icon: icon, tint: tint, title: title) { Toggle("", isOn: $on).labelsHidden().tint(Home.teal) }
    }
}

/// A row that opens a page: its value (if any) in grey, then a chevron.
struct SettingsLink<D: View>: View {
    let icon: String, tint: UInt32, title: String, value: String?
    let destination: () -> D
    init(icon: String, tint: UInt32, title: String, value: String?, @ViewBuilder destination: @escaping () -> D) {
        self.icon = icon; self.tint = tint; self.title = title; self.value = value; self.destination = destination
    }
    var body: some View {
        NavigationLink { destination() } label: {
            SettingsRow(icon: icon, tint: tint, title: title) {
                if let value { Text(value).font(.nunito(15, .semibold)).foregroundStyle(Home.muted).lineLimit(1).truncationMode(.middle) }
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .heavy)).foregroundStyle(Home.muted.opacity(0.7))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CardPress())
    }
}

/// A page opened from Settings: a back button, its title, then what's on it.
struct SettingsPage<C: View>: View {
    let title: String
    var content: C
    @Environment(\.dismiss) private var dismiss
    init(_ title: String, @ViewBuilder content: () -> C) { self.title = title; self.content = content() }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BackPill(label: "Settings") { dismiss() }
                Text(title).font(.nunito(30, .black)).tracking(-0.5).foregroundStyle(Home.ink)
                content
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18).padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .background(Home.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.colorScheme, .light)
    }
}

/// One of a few options, ticked, with what they mean underneath.
struct ChoiceList: View {
    let note: String
    let options: [(String, String)]
    @Binding var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { i, o in
                    if i > 0 { Rectangle().fill(Home.line).frame(height: 1).padding(.leading, 14) }
                    Button { value = o.0 } label: {
                        HStack {
                            Text(o.1).font(.nunito(16, .heavy)).foregroundStyle(Home.ink)
                            Spacer()
                            if value == o.0 { Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(Home.teal) }
                        }
                        .padding(.horizontal, 14).frame(minHeight: 52).contentShape(Rectangle())
                    }
                    .buttonStyle(CardPress())
                }
            }
            .homeCard()
            .sensoryFeedback(.selection, trigger: value)
            Text(note).font(.nunito(13.5, .semibold)).foregroundStyle(Home.muted).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4)
        }
    }
}

/// How fast words are spoken, Bùbù's recorded voices, and the phone's voice for what has no recording.
private struct VoicePage: View {
    @Environment(ProgressStore.self) private var progress
    var body: some View {
        @Bindable var p = progress
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup("Speed") {
                HStack(spacing: 12) {
                    Image(systemName: "tortoise.fill").foregroundStyle(Home.muted)
                    Slider(value: $p.prefs.rate, in: 0.4...1, step: 0.05, onEditingChanged: { editing in
                        if !editing { Speech.shared.speak("你好，很高兴认识你") }
                    })
                    .tint(Home.teal)
                    Image(systemName: "hare.fill").foregroundStyle(Home.muted)
                }
                .padding(14)
            }
            SettingsGroup("Bùbù's voice") {
                SettingsRow(icon: "waveform", tint: 0x1F7A6C, title: "Recorded voices") {
                    Button("Hear it") { Speech.shared.speak("你好") }.font(.nunito(15, .black)).foregroundStyle(Home.teal)
                }
            }
            note("Natural recorded voices, used wherever a word or sentence has a recording.")
            SettingsGroup("Phone voice") {
                HStack {
                    Picker("Voice", selection: Binding(get: { p.prefs.voiceURI ?? "" }, set: { p.prefs.voiceURI = $0.isEmpty ? nil : $0 })) {
                        Text("Best available").tag("")
                        ForEach(Speech.chineseVoices, id: \.identifier) { v in Text(Self.voiceName(v)).tag(v.identifier) }
                    }
                    .tint(Home.ink)
                    Spacer()
                    // a sentence with no recording, so it's the phone's voice that's heard
                    Button("Test") { Speech.shared.speak("这是手机的声音，你好") }.font(.nunito(15, .black)).foregroundStyle(Home.teal)
                }
                .padding(.horizontal, 10).padding(.vertical, 8)
            }
            note("Only for words with no recording yet. For the most natural sound, download an Enhanced or Premium Chinese voice in the iPhone's Settings → Accessibility → Spoken Content → Voices.")
        }
    }

    private func note(_ t: String) -> some View {
        Text(t).font(.nunito(13.5, .semibold)).foregroundStyle(Home.muted).fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4).padding(.top, -8)
    }

    static func voiceName(_ v: AVSpeechSynthesisVoice) -> String {
        let q = v.quality == .premium ? " (Premium)" : v.quality == .enhanced ? " (Enhanced)" : ""
        let place = v.language == "zh-CN" ? "" : v.language == "zh-TW" ? " · Taiwan" : v.language == "zh-HK" ? " · Hong Kong" : " · \(v.language)"
        return v.name + q + place
    }
}

/// Back up to a file (the website's format), restore one, or start again.
private struct DataPage: View {
    @Environment(ProgressStore.self) private var progress
    @State private var importing = false
    @State private var pending: (data: Data, summary: Backup.Summary)?
    @State private var confirmReset = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup {
                SettingsRow(icon: "square.and.arrow.up", tint: 0x1F7A6C, title: "Back up progress") { ExportButton() }
                SettingsDivider()
                SettingsRow(icon: "square.and.arrow.down", tint: 0x3B82F6, title: "Restore a backup") {
                    Button("Import") { importing = true }.font(.nunito(15, .bold)).foregroundStyle(Color.accent)
                }
            }
            Text("Progress lives only on this phone (\(progress.backupAge)) unless you sign in. A backup is a file in the website's own format, so it restores in either.")
                .font(.nunito(13.5, .semibold)).foregroundStyle(Home.muted).fixedSize(horizontal: false, vertical: true).padding(.horizontal, 4).padding(.top, -8)
            SettingsGroup {
                SettingsRow(icon: "trash.fill", tint: 0xE0574A, title: "Reset progress") {
                    Button("Reset") { confirmReset = true }.font(.nunito(15, .bold)).foregroundStyle(Color.again)
                }
            }
            if let m = message { Text(m).font(.nunito(14, .bold)).foregroundStyle(Home.teal).padding(.horizontal, 4) }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let s = Backup.summary(data) else { message = "That isn't a progress backup."; return }
            pending = (data, s)
        }
        .alert("Restore backup from \(pending?.summary.date ?? "")?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Restore", role: .destructive) {
                if let d = pending?.data { message = Backup.restore(d, into: progress) ? "Backup restored." : "That backup couldn't be read." }
                pending = nil
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: {
            Text("\(pending?.summary.lessons ?? 0) lesson(s) complete, \(pending?.summary.words ?? 0) word(s) with progress.\n\nThis replaces the progress on this phone.")
        }
        .alert("Reset all progress?", isPresented: $confirmReset) {
            Button("Reset", role: .destructive) { progress.resetProgress(); message = "Progress reset." }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every word, lesson, streak and XP goes. This can't be undone, so back up first if you might want it.")
        }
    }
}

/// TestFlight only: unlimited buns, the reported audio, and the look (light for now, dark to come).
private struct TesterPage: View {
    @Environment(ProgressStore.self) private var progress
    @State private var reportsTick = 0
    var body: some View {
        @Bindable var p = progress
        VStack(alignment: .leading, spacing: 16) {
            SettingsGroup {
                SettingsRow(icon: "infinity", tint: 0xB7822E, title: "Unlimited buns") {
                    Toggle("", isOn: Binding(get: { progress.isPlus }, set: { progress.setPlus($0) })).labelsHidden().tint(Home.teal)
                }
                SettingsDivider()
                SettingsRow(icon: "flag.fill", tint: 0xE0574A, title: "Reported audio (\(AudioReports.all.count))") {
                    HStack(spacing: 14) {
                        Button("Copy") { UIPasteboard.general.string = AudioReports.exportText }.font(.nunito(15, .bold)).foregroundStyle(Color.accent)
                        Button("Clear") { AudioReports.clear(); reportsTick += 1 }.font(.nunito(15, .bold)).foregroundStyle(Color.again)
                    }
                    .id(reportsTick)
                }
            }
            SettingsGroup("Appearance") {
                Segments(options: [("system", "Auto"), ("light", "Light"), ("dark", "Dark")], value: $p.prefs.theme).padding(10)
            }
        }
    }
}

/// How it works (web: #helpModal), written for the app: the words of it, on a Settings page.
struct HelpPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            p("**Study** uses spaced repetition: it brings back words you find hard and spaces out ones you know. Get a word right and it comes back less often; miss it and it returns soon, then again at the end of the session.")
            p("Each word climbs a ladder: first you recognise it and hear it, then recall it, read its pinyin and use it in sentences, and once it's solid, write it and say it.")
            h("Practice")
            p("• **Fix your mistakes** asks each missed word the way you missed it.\n• **Review** brings back words that are due.\n• **Weak words** are the ones that keep slipping.\n• **Listening, Writing, Quiz, Tones, Reading and Speaking** each practise one thing.\n• **Vocabulary** lets you pick any words for flashcards, matching or a quiz.")
            h("Buttons you'll see")
            p("• The speaker plays a word; the tortoise (or **½×**) plays it slowly.\n• Tap a dotted word for its meaning, or a character to see how it's built.\n• The pencil opens a writing sheet.\n• The microphone checks what you say.")
            h("Streaks and XP")
            p("Finish a session to light the day's lantern. Miss a day and a spare lantern can save your streak; you earn them at 3, 7, 14, 30, 60 and 100 days. Finish one session a day — a lesson, a review, practice or a story — to keep your streak. XP counts toward your level and your daily quests.")
        }
    }
    private func h(_ t: String) -> some View { Text(t).font(.nunito(18, .black)).foregroundStyle(Home.ink).padding(.top, 6) }
    private func p(_ t: String) -> some View {
        Text(.init(t)).font(.nunito(15, .semibold)).foregroundStyle(Home.ink).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
    }
}

/// Share the backup file; sharing it counts as backing up.
struct ExportButton: View {
    @Environment(ProgressStore.self) private var progress
    var label = "Export"
    var body: some View {
        ShareLink(item: BackupFile(progress: progress), preview: SharePreview("Bùbù progress")) {
            Text(label).font(.nunito(15, .bold)).foregroundStyle(Color.accent)
        }
        .simultaneousGesture(TapGesture().onEnded { progress.markBackedUp() })
    }
}

/// A row of options, one chosen.
struct Segments: View {
    let options: [(String, String)]
    @Binding var value: String
    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { o in
                let on = value == o.0
                Button { value = o.0 } label: {
                    Text(o.1).font(.nunito(14.5, .bold)).foregroundStyle(on ? Color.ink : Color.muted)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                        .background(on ? Color.panel : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: on ? .black.opacity(0.08) : .clear, radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.bg, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .sensoryFeedback(.selection, trigger: value)
    }
}

/// TestFlight (and debug) builds: the tester switches in Settings. A TestFlight install's
/// App Store receipt is the sandbox one.
enum Tester {
    static let isTestBuild: Bool = {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }()
}
