import SwiftUI

/// "What to study": which skills a session mixes, and which lessons Home's practice
/// draws on (web: #studyPanel, renderFocuses).
struct StudyChoicePage: View {
    @Environment(ProgressStore.self) private var progress
    private let course = Course.shared

    static let focuses: [(key: String, icon: String, name: String, desc: String)] = [
        ("recognize", "eye", "Read characters", "See 汉字, recall the meaning"),
        ("recall", "character.cursor.ibeam", "Recall from English", "English → produce the 汉字"),
        ("pinyin", "character.textbox", "Pinyin", "Pick the correct pinyin — tones matter"),
        ("listen", "headphones", "Listen", "Hear it, then pick what it means"),
        ("write", "pencil", "Write it", "Draw the character stroke by stroke"),
        ("sentence", "square.stack.3d.up", "Build sentences", "Tap word tiles to assemble a sentence"),
        ("speak", "mic", "Speak it", "Say the word aloud and get it checked"),
    ]
    static let presets: [(name: String, keys: [String])] = [
        ("Everything", ["recognize", "recall", "pinyin", "listen", "write", "sentence", "speak"]),
        ("Reading", ["recognize", "recall", "pinyin"]),
        ("Writing", ["write", "recognize"]),
        ("Speaking", ["speak", "pinyin", "listen"]),
    ]

    var body: some View {
        let on = progress.selectedFocuses
        let chosen = progress.selectedLessons
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.presets, id: \.name) { p in
                            let active = Set(p.keys) == on
                            Button { setFocuses(Set(p.keys)) } label: {
                                Text(p.name).font(.nunito(14, .bold)).foregroundStyle(active ? Color.onAccent : Color.ink)
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(active ? Color.accent : Color.bg, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listRowBackground(Color.panel)
                ForEach(Self.focuses, id: \.key) { f in
                    Toggle(isOn: Binding(get: { on.contains(f.key) }, set: { v in
                        var s = on
                        if v { s.insert(f.key) } else {
                            guard s.count > 1 else { Moments.shared.toast("Keep at least one skill switched on."); return }
                            s.remove(f.key)
                        }
                        setFocuses(s)
                    })) {
                        HStack(spacing: 12) {
                            Image(systemName: f.icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(Color.accent).frame(width: 26)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.name).font(.nunito(15.5, .bold)).foregroundStyle(Color.ink)
                                Text(f.desc).font(.nunito(12.5)).foregroundStyle(Color.muted)
                            }
                        }
                    }
                    .tint(.accent)
                    .listRowBackground(Color.panel)
                }
            } header: {
                Text("What to practise").font(.nunitoXB(13)).foregroundStyle(Color.muted).textCase(nil)
            } footer: {
                Text("Study mixes whatever's on.").font(.nunito(12.5)).foregroundStyle(Color.muted)
            }

            Section {
                ForEach(course.lessons, id: \.id) { l in
                    let cards = course.cards(in: l.id)
                    let due = cards.filter { (progress.srs[$0.id]?.due).map { $0 <= progress.now() } ?? false }.count
                    let mastered = cards.filter { progress.isMastered($0.id) }.count
                    Button { toggle(l.id) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: chosen.contains(l.id) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20)).foregroundStyle(chosen.contains(l.id) ? Color.accent : Color.line)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(l.title).font(.nunito(13.5, .semibold)).foregroundStyle(Color.ink).lineLimit(1)
                                Bar(value: cards.isEmpty ? 0 : Double(mastered) / Double(cards.count), height: 4, fill: .good)
                            }
                            Text(due > 0 ? "\(due) due" : "\(cards.count)").font(.nunito(12, .bold))
                                .foregroundStyle(due > 0 ? Color.gold : Color.muted).frame(minWidth: 40, alignment: .trailing)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.panel)
                }
            } header: {
                HStack {
                    Text("Lessons").font(.nunitoXB(13)).foregroundStyle(Color.muted).textCase(nil)
                    Spacer()
                    Button(chosen.count == course.lessons.count ? "select none" : "select all") {
                        progress.prefs.lessons = chosen.count == course.lessons.count ? [] : course.lessons.map(\.id)
                        // an empty choice means all, so "none" keeps just the current lesson
                        if progress.prefs.lessons?.isEmpty == true, let cur = progress.currentLessonId { progress.prefs.lessons = [cur] }
                    }
                    .font(.nunitoXB(13)).foregroundStyle(Color.accent).textCase(nil)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("What to study")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setFocuses(_ s: Set<String>) {
        progress.prefs.focuses = StudySession.allDirs.filter(s.contains)
    }

    private func toggle(_ id: String) {
        var s = progress.selectedLessons
        if s.contains(id) {
            guard s.count > 1 else { Moments.shared.toast("Keep at least one lesson chosen."); return }
            s.remove(id)
        } else { s.insert(id) }
        progress.prefs.lessons = course.lessons.map(\.id).filter(s.contains)
    }
}
