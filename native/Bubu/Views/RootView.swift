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

    /// Screens the cloud screenshot run asks for with `-screen`.
    private func debugScreens() {
        #if DEBUG
        guard let screen = Launch.screen, ["study", "quiz", "sentence", "done"].contains(screen) else { return }
        let first = Course.shared.lessons[0].id
        let s = StudySession(lessonId: first, progress: progress)
        switch screen {
        case "quiz": s.debugShow(dir: "recognize")
        case "sentence": s.debugShow(dir: "sentence")
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
            ComingSoon(title: "Settings", icon: "gearshape")
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
        .fullScreenCover(item: $router.study) { s in
            StudyView(session: s) { router.study = nil }
                .environment(progress)
        }
        .environment(router)
        .onAppear { debugScreens() }
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
