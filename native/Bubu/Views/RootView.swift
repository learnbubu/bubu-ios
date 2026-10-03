import SwiftUI
import Observation

/// Where the app is: the selected tab and the lesson sheet, if one is open.
/// The sheet lives here so it can cover the tab bar, as the web's does.
@Observable
final class Router {
    enum Tab: String { case home, learn, profile, settings }
    var tab: Tab
    var lesson: Lesson?
    var study: StudySession?
    var homePath: [Page] = []
    var learnPath: [Page] = []
    var profilePath: [Page] = []

    /// Slide a page in on the tab you're on (Settings has none: it goes to Home's).
    func push(_ p: Page) {
        switch tab {
        case .learn: learnPath.append(p)
        case .profile: profilePath.append(p)
        default: tab = .home; homePath.append(p)
        }
    }

    /// Open a session, if there was one to start.
    func start(_ s: StudySession?) { if let s { lesson = nil; study = s } }

    /// A practice tile on Home (web: runMode).
    func practice(_ mode: String, _ p: ProgressStore) {
        switch mode {
        case "listen": start(StudySession.listening(p))
        case "write": start(StudySession.writing(p))
        case "quiz": start(StudySession.quiz(p, cards: p.activeCards, scope: p.selectedLessons))
        case "chars": push(.chars)
        case "read": push(.readings)
        case "tones": push(.tones)
        case "speak": push(.converse)
        case "pick": push(.pick)
        default: Moments.shared.toast("Coming in the next build.")
        }
    }

    init() {
        switch Launch.screen {
        case "path", "pathstep", "pathpractice", "practice", "lesson", "hud", "shop", "pocket": tab = .learn
        case "profile": tab = .profile
        case "settings", "account": tab = .settings
        default: tab = .home
        }
        if Launch.screen == "lesson" { lesson = Course.shared.lessons.first }
        if Launch.screen == "practice" { lesson = Course.shared.lessons.first { $0.isPractice } }
    }
}

struct RootView: View {
    @State private var router = Router()
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase
    @State private var showWelcome = Launch.screen == "welcome"
    @State private var startLevel: String?

    /// Straight into learning once onboarding has gone: the first lesson, or a
    /// placement test up to the end of book 1 or 2.
    private func startAfterOnboarding() {
        guard let level = startLevel else { return }
        startLevel = nil
        let books = Course.shared.chapters.map(\.unit).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let end = { (u: String) in Course.shared.chapters.last { $0.unit == u }?.lessons.last }
        let target = level == "a" ? end(books[0]) : level == "b" ? end(books[1]) : nil
        if let t = target { router.start(StudySession.placement(progress, to: t, label: "Placement test")) }
        else if let cur = progress.currentLessonId ?? Course.shared.lessons.last?.id { router.start(StudySession.lesson(cur, progress)) }
    }

    /// Screens the cloud screenshot run asks for with `-screen`.
    private static var debugShown = false
    private func debugScreens() {
        #if DEBUG
        // once: onAppear can run twice at launch, and a second session presented over the first
        // left the first exercise answered but not shown (the Mac's lldb check of 3 Oct 2026)
        guard !Self.debugShown else { return }
        Self.debugShown = true
        if Launch.screen == "avatar" { router.tab = .profile; router.profilePath = [.avatar]; return }
        if Launch.screen == "tones" { router.homePath = [.tones]; return }
        if Launch.screen == "guide" { router.tab = .learn; router.learnPath = [.guide(1)]; return }
        if Launch.screen == "story", let r = Course.shared.data.readings.first { router.tab = .home; router.homePath = [.story(r.id)]; return }
        if Launch.screen == "chars" { router.tab = .home; router.homePath = [.chars]; return }
        if Launch.screen == "char" { router.tab = .learn; CharNav.shared.open("好"); return }
        // the rewards: the shop, and a red pocket opened (it opens itself for this)
        if Launch.screen == "shop" { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Moments.shared.show(.shop) }; return }
        if Launch.screen == "pocket" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Moments.shared.show(.pocket(.init(kind: .red, reward: 30, title: "Lesson complete!", sub: "Bùbù has something for you.")))
            }
            return
        }
        guard let screen = Launch.screen, ["study", "meet", "tip", "practicerun", "quiz", "sentence", "sentencedrag", "gap", "hear", "type", "picture", "inarow", "speak", "write", "done", "donefinal", "donenext", "char", "buns"].contains(screen) else { return }
        if screen == "practicerun", let pr = Course.shared.lessons.first(where: { $0.isPractice }) {
            router.tab = .learn
            router.study = StudySession.lesson(pr.id, progress)
            return
        }
        let first = Course.shared.lessons[0].id
        // "buns": a new lesson with none left, which asks for more on the first Continue
        let s = StudySession(lessonId: first, progress: progress)
        switch screen {
        case "quiz": s.debugShow(dir: "recognize")
        case "sentence", "sentencedrag": s.debugShow(dir: "sentence")
        case "gap", "hear", "type", "picture": s.debugShow(dir: screen)
        case "inarow": s.debugShow(dir: "recognize"); s.debugCombo(4)
        case "speak": s.debugShow(dir: "speak")
        case "write": s.debugShow(dir: "write")
        case "done", "donefinal", "donenext": s.debugFinish()
        default: break
        }
        router.study = s
        #endif
    }

    var body: some View {
        TabView(selection: $router.tab) {
            NavigationStack(path: $router.homePath) {
                HomeView().toolbar(.hidden, for: .navigationBar).pageDestinations()
            }
            .tabItem { Label("Home", systemImage: "house") }.tag(Router.Tab.home)
            NavigationStack(path: $router.learnPath) {
                PathView().toolbar(.hidden, for: .navigationBar).pageDestinations()
            }
            .tabItem { Label("Learn", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(Router.Tab.learn)
            NavigationStack(path: $router.profilePath) {
                ProfileView().toolbar(.hidden, for: .navigationBar).pageDestinations()
            }
            .tabItem { Label("Profile", systemImage: "person") }.tag(Router.Tab.profile)
            NavigationStack { SettingsView().toolbar(.hidden, for: .navigationBar) }
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(Router.Tab.settings)
        }
        .sensoryFeedback(.selection, trigger: router.tab)
        .overlay {
            if let lesson = router.lesson {
                LessonSheet(lesson: lesson) { withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { router.lesson = nil } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: router.lesson?.id)
        .charSheetHost()
        .momentsHost()
        .fullScreenCover(item: $router.study) { s in
            StudyView(session: s) { router.study = nil }
                .environment(progress)
                .charSheetHost()
                .momentsHost(study: true)
                .preferredColorScheme(progress.prefs.colorScheme)
        }
        .preferredColorScheme(progress.prefs.colorScheme)
        .reminderHost()
        .environment(router)
        .onAppear {
            Moments.shared.launch = { router.start($0) }
            debugScreens()
            // the path's planted scenery is the slow part of laying it out: planted in the
            // background at launch, so Learn opens without a hitch
            let w = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 0
            if w > 0 { DispatchQueue.global(qos: .utility).async { PathModel.warm(Course.shared, width: w) } }
        }
        .fullScreenCover(isPresented: Binding(get: { (!progress.onboarded && Launch.screen == nil) || showWelcome },
                                              set: { if !$0 { showWelcome = false } }),
                         onDismiss: startAfterOnboarding) {
            OnboardingView { level in
                startLevel = level
                progress.markOnboarded(); showWelcome = false
                router.tab = .learn
            }
            .environment(progress)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // after a missed day, the fire is relit (or its loss shown) when you come back
            if phase == .active { DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { progress.protectStreak() } }
        }
    }
}

struct ComingSoon: View {
    let title: String
    let icon: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(Color.accent)
            Text(title).font(.nunitoXB(24)).foregroundStyle(Color.ink)
            Text("Coming in a later build").font(.nunito(15)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bg.ignoresSafeArea())
    }
}
