import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

/// Settings, as the web's: your name, look, voice and speed, daily goal, the
/// practice switches, and backups in the website's own format.
struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var importing = false
    @State private var pending: (data: Data, summary: Backup.Summary)?
    @State private var confirmReset = false
    @State private var reportsTick = 0
    @State private var message: String?

    var body: some View {
        @Bindable var p = progress
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Settings").font(.nunitoXB(28)).foregroundStyle(Color.ink).padding(.top, 8)

                AccountSection()

                section {
                    row("Your name", "Shown in the greeting on the Home screen.", stack: true) {
                        TextField("e.g. Dominic", text: $p.name)
                            .font(.nunito(16)).textInputAutocapitalization(.words).autocorrectionDisabled()
                            .padding(10).background(Color.bg, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
                            .onChange(of: p.name) { _, v in if v.count > 24 { p.name = String(v.prefix(24)) }; progress.save() }
                    }
                    divider
                    row("Appearance", "Light, dark, or follow your device.", stack: true) {
                        Segments(options: [("system", "Auto"), ("light", "Light"), ("dark", "Dark")], value: $p.prefs.theme)
                    }
                }

                ReminderSettings()

                section {
                    row("Audio speed", "How fast words are spoken.", stack: true) {
                        HStack {
                            Image(systemName: "tortoise.fill").foregroundStyle(Color.muted)
                            Slider(value: $p.prefs.rate, in: 0.4...1, step: 0.05, onEditingChanged: { editing in
                                if !editing { Speech.shared.speak("你好，很高兴认识你") }
                            })
                            .tint(.accent)
                            Image(systemName: "hare.fill").foregroundStyle(Color.muted)
                        }
                    }
                    divider
                    toggle("Play audio automatically", "Say each exercise's Chinese as it appears (unless hearing it would give the answer away), and the right answer after you answer.",
                           Binding(get: { p.prefs.autoplay ?? true }, set: { p.prefs.autoplay = $0 }))
                    divider
                    // the recorded voice, which the choice below doesn't change
                    row("Bùbù's voice", "Recorded, natural voices: Kore, and Charon for the other speaker in a conversation. Used wherever a word or sentence has a recording.") {
                        Button("Hear it") { Speech.shared.speak("你好") }
                            .font(.nunito(15, .bold)).foregroundStyle(Color.accent)
                    }
                    divider
                    row("Phone voice", "Only for words that don't have a recording yet. For the most natural sound, download an Enhanced or Premium Chinese voice in the iPhone's Settings → Accessibility → Spoken Content → Voices.", stack: true) {
                        HStack {
                            Picker("Voice", selection: Binding(get: { p.prefs.voiceURI ?? "" }, set: { p.prefs.voiceURI = $0.isEmpty ? nil : $0 })) {
                                Text("Best available").tag("")
                                ForEach(Speech.chineseVoices, id: \.identifier) { v in
                                    Text(voiceName(v)).tag(v.identifier)
                                }
                            }
                            .tint(.ink)
                            Spacer()
                            // a sentence with no recording, so it's the phone's voice that's heard
                            Button("Test") { Speech.shared.speak("这是手机的声音，你好") }
                                .font(.nunito(15, .bold)).foregroundStyle(Color.accent)
                        }
                    }
                }


                section {
                    toggle("Embers relight automatically", "Miss a day and an ember is spent for you overnight. Off means you choose each time.", $p.prefs.autoRelight)
                    divider
                    toggle("Sound effects", "Chimes for right and wrong, and the end of a session.", $p.prefs.sound)
                    divider
                    row("Typing answers", "Automatic: pinyin in 起步 1–3, then characters with the Chinese keyboard. Characters always count.", stack: true) {
                        Segments(options: [("auto", "Automatic"), ("pinyin", "Pinyin"), ("hanzi", "Characters")],
                                 value: Binding(get: { p.prefs.typing ?? "auto" }, set: { p.prefs.typing = $0 == "auto" ? nil : $0 }))
                    }
                    divider
                    row("Pinyin", "Over the Chinese in exercises. Auto: over a word until you know it well, then a tap away. Hide when known: only until you've got a word right once.", stack: true) {
                        Segments(options: [(PinyinMode.auto.rawValue, "Auto"), (PinyinMode.always.rawValue, "Always"), (PinyinMode.known.rawValue, "Hide when known")],
                                 value: Binding(get: { p.prefs.pinyin.rawValue }, set: { p.prefs.pinyin = PinyinMode(rawValue: $0) ?? .auto }))
                    }
                    divider
                    toggle("Tone colours", "Colour pinyin and characters by tone: 1st red, 2nd orange, 3rd green, 4th blue.", $p.prefs.toneColours)
                    divider
                    toggle("Stroke checking", "Check each stroke as you write (off = free tracing).", $p.prefs.checkStrokes)
                }

                section {
                    NavigationLink { HelpPage() } label: {
                        row("How it works", "Spaced repetition, the practice modes, and the buttons you'll see.") {
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.muted)
                        }
                    }
                    .buttonStyle(.plain)
                    divider
                    NavigationLink {
                        ScrollView { TonesPrimer().padding(18) }
                            .background(Color.bg.ignoresSafeArea())
                            .navigationTitle("The four tones").navigationBarTitleDisplayMode(.inline)
                    } label: {
                        row("The four tones", "Hear 妈 麻 马 骂 and how each tone moves.") {
                            Image(systemName: "chevron.right").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.muted)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if Tester.isTestBuild {
                    section {
                        row("Unlimited buns", "Tester only: mistakes never cost a bun (as Plus would).") {
                            Toggle("", isOn: Binding(get: { progress.isPlus }, set: { progress.setPlus($0) }))
                                .labelsHidden().tint(.accent)
                        }
                        divider
                        row("Reported audio (\(AudioReports.all.count))", "Clips you flagged in lessons. Copy the list and send it over; they'll be made again.") {
                            HStack(spacing: 14) {
                                Button("Copy") { UIPasteboard.general.string = AudioReports.exportText }
                                    .font(.nunito(15, .bold)).foregroundStyle(Color.accent)
                                Button("Clear") { AudioReports.clear(); reportsTick += 1 }
                                    .font(.nunito(15, .bold)).foregroundStyle(Color.again)
                            }
                            .id(reportsTick)
                        }
                        divider
                        row("Start the stones again", "Tester only: clears every stone, word and streak so the course starts from stone 1. Settings stay.") {
                            Button("Reset") { confirmReset = true }.font(.nunito(15, .bold)).foregroundStyle(Color.again)
                        }
                    }
                }

                section {
                    row("Back up progress", "Save everything to a file, in the same format as the website, so it restores in either. Progress lives only on this phone — \(progress.backupAge).") {
                        ExportButton()
                    }
                    divider
                    row("Restore backup", "Replaces current progress with a saved file, from the app or the website.") {
                        Button("Import") { importing = true }.font(.nunito(15, .bold)).foregroundStyle(Color.accent)
                    }
                    divider
                    row("Reset progress", "Clears every word, lesson and streak. Your settings stay.") {
                        Button("Reset") { confirmReset = true }.font(.nunito(15, .bold)).foregroundStyle(Color.again)
                    }
                }

                Text("步步 Bùbù \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "") · Character breakdowns from Make Me a Hanzi")
                    .font(.nunito(12)).foregroundStyle(Color.muted).frame(maxWidth: .infinity).padding(.top, 4)
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .background(Color.bg.ignoresSafeArea())
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url), let s = Backup.summary(data) else {
                message = "That isn't a progress backup."; return
            }
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
            Text("Every word, lesson, streak and XP goes. This can't be undone, so export a backup first if you might want it.")
        }
        .overlay(alignment: .bottom) {
            if let m = message {
                Text(m).font(.nunito(15, .bold)).foregroundStyle(Color.onAccent)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.ink.opacity(0.9), in: Capsule())
                    .padding(.bottom, 100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task { try? await Task.sleep(for: .seconds(2.4)); withAnimation { message = nil } }
            }
        }
        .animation(.spring(response: 0.3), value: message)
    }

    private func voiceName(_ v: AVSpeechSynthesisVoice) -> String {
        let q = v.quality == .premium ? " (Premium)" : v.quality == .enhanced ? " (Enhanced)" : ""
        let place = v.language == "zh-CN" ? "" : v.language == "zh-TW" ? " · Taiwan" : v.language == "zh-HK" ? " · Hong Kong" : " · \(v.language)"
        return v.name + q + place
    }

    // MARK: building blocks

    private func section<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0, content: c)
            .padding(.horizontal, 14)
            .panel(radius: 18)
    }

    private var divider: some View { Rectangle().fill(Color.line).frame(height: 1) }

    private func row<C: View>(_ label: String, _ desc: String, stack: Bool = false, @ViewBuilder control: () -> C) -> some View {
        Group {
            if stack {
                VStack(alignment: .leading, spacing: 10) {
                    labels(label, desc)
                    control()
                }
            } else {
                HStack(spacing: 12) {
                    labels(label, desc)
                    Spacer(minLength: 0)
                    control()
                }
            }
        }
        .padding(.vertical, 13)
    }

    private func labels(_ label: String, _ desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.nunitoXB(16)).foregroundStyle(Color.ink)
            Text(desc).font(.nunito(13)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func toggle(_ label: String, _ desc: String, _ on: Binding<Bool>) -> some View {
        row(label, desc) { Toggle("", isOn: on).labelsHidden().tint(.accent) }
    }
}

/// How it works (web: #helpModal), written for the app.
struct HelpPage: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                p("**Study** uses spaced repetition: it brings back words you find hard and spaces out ones you know. Get a word right and it comes back less often; miss it and it returns soon, then again at the end of the session.")
                p("Each word climbs a ladder: first you recognise it and hear it, then recall it, read its pinyin and use it in sentences, and once it's solid, write it and say it.")
                h("Practice")
                p("• **Fix your mistakes** asks each missed word the way you missed it.\n• **Review** brings back words that are due.\n• **Weak words** are the ones that keep slipping.\n• **Listening, Writing, Quiz, Tones, Reading and Speaking** each practise one thing.\n• **Vocabulary** lets you pick any words for flashcards, matching or a quiz.")
                h("Buttons you'll see")
                p("• The speaker plays a word; the tortoise (or **½×**) plays it slowly.\n• Tap a dotted word for its meaning, or a character to see how it's built.\n• The pencil opens a writing sheet.\n• The microphone checks what you say.")
                h("Streaks and XP")
                p("Finish a session to light the day's fire. Miss a day and an ember can relight it; you earn embers at 3, 7, 14, 30, 60 and 100 days. Finish one session a day — a lesson, a review, practice or a story — to keep your streak. XP counts toward your level and your daily quests.")
            }
            .padding(20)
        }
        .background(Color.bg.ignoresSafeArea())
        .navigationTitle("How it works").navigationBarTitleDisplayMode(.inline)
    }
    private func h(_ t: String) -> some View { Text(t).font(.nunitoXB(17)).foregroundStyle(Color.ink).padding(.top, 6) }
    private func p(_ t: String) -> some View {
        Text(.init(t)).font(.nunito(15)).foregroundStyle(Color.ink).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
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
