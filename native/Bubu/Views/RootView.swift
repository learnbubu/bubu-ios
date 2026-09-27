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

    /// Open a session, if there was one to start.
    func start(_ s: StudySession?) { if let s { lesson = nil; study = s } }

    /// A practice tile on Home (web: runMode).
    func practice(_ mode: String, _ p: ProgressStore) {
        switch mode {
        case "listen": start(StudySession.listening(p))
        case "write": start(StudySession.writing(p))
        default: Moments.shared.toast("Coming in the next build.")
        }
    }

    init() {
        switch Launch.screen {
        case "path", "lesson": tab = .learn
        case "profile": tab = .profile
        case "settings": tab = .settings
        default: tab = .home
        }
        if Launch.screen == "lesson" { lesson = Course.shared.lessons.first }
    }
}

struct RootView: View {
    @State private var router = Router()
    @Environment(ProgressStore.self) private var progress
    @Environment(\.scenePhase) private var scenePhase

    /// Screens the cloud screenshot run asks for with `-screen`.
    private func debugScreens() {
        #if DEBUG
        if Launch.screen == "char" { router.tab = .learn; CharNav.shared.open("好"); return }
        guard let screen = Launch.screen, ["study", "quiz", "sentence", "speak", "write", "done", "char"].contains(screen) else { return }
        let first = Course.shared.lessons[0].id
        let s = StudySession(lessonId: first, progress: progress)
        switch screen {
        case "quiz": s.debugShow(dir: "recognize")
        case "sentence": s.debugShow(dir: "sentence")
        case "speak": s.debugShow(dir: "speak")
        case "write": s.debugShow(dir: "write")
        case "done": s.debugFinish()
        default: break
        }
        router.study = s
        #endif
    }

    var body: some View {
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Home", systemImage: "house") }.tag(Router.Tab.home)
            PathView()
                .tabItem { Label("Learn", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(Router.Tab.learn)
            ComingSoon(title: "Profile", icon: "person.crop.circle")
                .tabItem { Label("Profile", systemImage: "person") }.tag(Router.Tab.profile)
            SettingsView()
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
        .environment(router)
        .onAppear { debugScreens() }
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
