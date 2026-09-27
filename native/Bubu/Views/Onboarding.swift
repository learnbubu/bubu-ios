import SwiftUI
import UniformTypeIdentifiers

/// The first run: the welcome, then the web's three slides (web: the auth gate's
/// splash, then runOnboarding). Ends in the first lesson, or a placement test.
struct OnboardingView: View {
    var finish: (_ level: String) -> Void
    @Environment(ProgressStore.self) private var progress
    @State private var started = false
    @State private var page = 0
    @State private var level = "new"
    @State private var importing = false
    @State private var message: String?

    var body: some View {
        ZStack {
            Color.bg.ignoresSafeArea()
            if !started { welcome.transition(.opacity) } else { slides.transition(.move(edge: .trailing).combined(with: .opacity)) }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.9), value: started)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: url), Backup.restore(data, into: progress) {
                progress.markOnboarded()
            } else {
                message = "That isn't a progress backup."
            }
        }
    }

    // MARK: the welcome

    private var welcome: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("步步").font(.hanzi(76, .heavy)).foregroundStyle(Color.ink)
                Text("Bùbù").font(.nunitoXB(40)).foregroundStyle(Color.ink)
                Text("Learn Chinese,\nstep by step.").font(.nunito(22)).foregroundStyle(Color.muted).multilineTextAlignment(.center).padding(.top, 8)
            }
            .padding(.top, 50)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .background(alignment: .bottom) {
            Image("welcome").resizable().scaledToFit().frame(maxWidth: .infinity).ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 12) {
                Button { withAnimation { started = true } } label: {
                    Label("Get started", systemImage: "arrow.right").labelStyle(TrailingIcon())
                        .font(.nunitoXB(19)).foregroundStyle(Color.onAccent)
                        .frame(maxWidth: .infinity).padding(.vertical, 18)
                        .background(Color.accent, in: Capsule())
                        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
                }
                .buttonStyle(PressDown(depth: 2))
                Button { importing = true } label: {
                    (Text("Coming from the website? ").foregroundColor(.ink) + Text("Restore a backup").foregroundColor(.accent).bold())
                        .font(.nunito(15)).padding(.horizontal, 16).padding(.vertical, 10)
                        .background(Color.bg.opacity(0.85), in: Capsule())
                }
                .buttonStyle(.plain)
                if let m = message { Text(m).font(.nunito(13, .bold)).foregroundStyle(Color.again) }
            }
            .padding(.horizontal, 22).padding(.bottom, 16)
        }
    }

    // MARK: the slides

    private var slides: some View {
        VStack(spacing: 18) {
            TabView(selection: $page) {
                slide {
                    Image("sheet-waving").resizable().scaledToFit().frame(height: 190)
                    Text("欢迎！Welcome").font(.nunitoXB(26)).foregroundStyle(Color.ink)
                    Text("I'm your study buddy. Let's learn beginner Mandarin together — a little every day.")
                        .font(.nunito(16.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                }
                .tag(0)
                slide {
                    Text("How much Chinese do you know?").font(.nunitoXB(24)).foregroundStyle(Color.ink).multilineTextAlignment(.center)
                    Text("We'll start you in the right place.").font(.nunito(16)).foregroundStyle(Color.muted)
                    choice("new", "I'm new to Chinese", "Start with the first lesson", on: level == "new") { level = "new" }
                    choice("a", "I know some basics", "I could get through 起步 1: greetings, numbers, jobs", on: level == "a") { level = "a" }
                    choice("b", "I'm past the basics", "起步 1 and 2: times, dates, measure words", on: level == "b") { level = "b" }
                    Text("A short test unlocks the lessons you already know.").font(.nunito(13)).foregroundStyle(Color.muted)
                }
                .tag(1)
                slide {
                    Text("Pick your pace").font(.nunitoXB(24)).foregroundStyle(Color.ink)
                    Text("Any finished session keeps your streak alive. This is the daily XP target on top, for a bonus.")
                        .font(.nunito(15.5)).foregroundStyle(Color.muted).multilineTextAlignment(.center)
                    ForEach([(10, "Casual", "10 XP · one short session"), (20, "Regular", "20 XP · a session and a few words"),
                             (30, "Serious", "30 XP · a lesson a day"), (50, "Intense", "50 XP · two lessons")], id: \.0) { g in
                        choice("\(g.0)", g.1, g.2, on: progress.prefs.dailyGoal == g.0) { progress.prefs.dailyGoal = g.0 }
                    }
                    Text("You can change this any time in Settings.").font(.nunito(13)).foregroundStyle(Color.muted)
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.spring(response: 0.4, dampingFraction: 0.9), value: page)

            HStack(spacing: 7) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == page ? Color.accent : Color.line).frame(width: i == page ? 22 : 8, height: 8)
                }
            }
            .animation(.spring(response: 0.3), value: page)

            VStack(spacing: 8) {
                Button(page < 2 ? "Next" : level == "new" ? "Start my first lesson" : "Take the test") {
                    if page < 2 { page += 1 } else { finish(level) }
                }
                .buttonStyle(WideButton())
                if page > 0 {
                    Button("Back") { page -= 1 }.buttonStyle(WideButton(ghost: true))
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 12)
        }
        .sensoryFeedback(.selection, trigger: page)
    }

    private func slide<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        ScrollView {
            VStack(spacing: 12) { c() }.padding(.horizontal, 22).padding(.top, 30)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func choice(_ id: String, _ title: String, _ sub: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.nunitoXB(16.5)).foregroundStyle(Color.ink)
                Text(sub).font(.nunito(13.5)).foregroundStyle(Color.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(15)
            .background(on ? Color.accentSoft : Color.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(on ? Color.accent : Color.line, lineWidth: on ? 2 : 1))
        }
        .buttonStyle(PressDown(depth: 1))
        .sensoryFeedback(.selection, trigger: on)
    }
}

private struct TrailingIcon: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) { configuration.title; configuration.icon }
    }
}
