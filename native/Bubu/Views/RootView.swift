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
    /// The Classroom's slide-over (see CoverHost): the room open over everything, its pages, and a session started
    /// from it, slid in from the side too
    var cover: Page?
    var coverPath: [Page] = []
    var coverStudy: StudySession?
    static let slide = Animation.spring(response: 0.38, dampingFraction: 0.92)

    /// Slide one of the Classroom's rooms in over everything.
    func open(_ p: Page) { coverPath = []; withAnimation(Self.slide) { cover = p } }
    /// Back a page in the slide-over, or out of it.
    func coverBack() {
        if !coverPath.isEmpty { coverPath.removeLast() } else { withAnimation(Self.slide) { cover = nil } }
    }
    /// A session slid in from the side, as the Classroom's rooms are.
    func slideIn(_ s: StudySession?) { if let s { lesson = nil; withAnimation(Self.slide) { coverStudy = s } } }
    var homePath: [Page] = []
    var learnPath: [Page] = []
    var profilePath: [Page] = []

    /// Slide a page in on the tab you're on (Settings has none: it goes to Home's).
    func push(_ p: Page) {
        if cover != nil { coverPath.append(p); return }
        switch tab {
        case .learn: learnPath.append(p)
        case .profile: profilePath.append(p)
        default: tab = .home; homePath.append(p)
        }
    }

    /// Open a session, if there was one to start.
    func start(_ s: StudySession?) {
        guard let s else { return }
        // (from the Classroom's slide-over: slid in from the side as well)
        if cover != nil { slideIn(s) } else { lesson = nil; study = s }
    }

    /// Asks the path to show the current stone (bumped each time: the path scrolls to it).
    var showCurrent = 0
    /// The path, at the stone you're on: to start from there (Home's Start lesson; the owner, 22 Oct 2026).
    func toPath() { learnPath = []; tab = .learn; showCurrent += 1 }

    /// A practice tile on Home (web: runMode).
    func practice(_ mode: String, _ p: ProgressStore) {
        switch mode {
        // (every one from the side, over the tab bar: the owner, 26 Oct 2026)
        case "listen": slideIn(StudySession.listening(p))
        case "write": slideIn(StudySession.writing(p))
        case "quiz":
            let words = Array(p.learnedCards.prefix(60))
            slideIn(StudySession.quiz(p, cards: words, scope: Set(words.map(\.lessonId))))
        case "chars": open(.chars)
        case "read": open(.readings)
        case "tones": open(.tones)
        case "speak": open(.converse)
        case "pick": open(.pick)
        case "vocab": open(.vocab)
        default: Moments.shared.toast("Coming in the next build.")
        }
    }

    init() {
        switch Launch.screen {
        case "path", "pathstep", "pathpractice", "practice", "lesson", "hud", "shop", "pocket", "hongbaobig": tab = .learn
        case "profile", "dress": tab = .profile
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
        if Launch.screen == "tones" { router.tab = .home; router.homePath = [.classroom]; router.cover = .tones; return }
        if Launch.screen == "guide" { router.tab = .learn; router.learnPath = [.guide(1)]; return }
        if Launch.screen == "story", let r = Course.shared.data.readings.first { router.tab = .home; router.homePath = [.story(r.id)]; return }
        if Launch.screen == "chars" { router.tab = .home; router.homePath = [.classroom]; router.cover = .chars; return }
        if Launch.screen == "char" { router.tab = .learn; CharNav.shared.open("好"); return }
        // the rewards: the shop, and a red pocket opened (it opens itself for this)
        if Launch.screen == "shop" { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { Moments.shared.show(.shop) }; return }
        // the Streak saved moment (Studio's: an ember flies round the spare lantern and lights it)
        if Launch.screen == "relit" { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { Moments.shared.show(.relit(streak: 5, left: 1)) }; return }
        // the hongbao, a milestone's: the big heap
        if Launch.screen == "hongbaobig" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Moments.shared.show(.pocket(.init(kind: .red, reward: 150, title: "", sub: "A 30-day streak! That's a milestone.", milestone: true)))
            }
            return
        }
        if Launch.screen == "pocket" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Moments.shared.show(.pocket(.init(kind: .red, reward: 15, title: "Lesson complete!", sub: "For finishing today's lesson.")))
            }
            return
        }
        guard let screen = Launch.screen, ["study", "meet", "tip", "practicerun", "quiz", "sentence", "sentencedrag", "gap", "hear", "type", "picture", "build", "inarow", "speak", "write", "done", "donefinal", "donenext", "donemoment", "char", "buns", "pairs", "sentencegood", "donecombo", "levelheld", "burst"].contains(screen) else { return }
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
        case "sentence", "sentencedrag", "sentencegood": s.debugShow(dir: "sentence")
        case "pairs": s.debugMatch()
        case "donecombo": s.debugFinishBoosted()
        case "levelheld", "burst": s.debugShow(dir: "recognize")
        case "gap", "hear", "type", "picture", "build": s.debugShow(dir: screen)
        case "inarow": s.debugShow(dir: "recognize"); s.debugCombo(4)
        case "speak": s.debugShow(dir: "speak")
        case "write": s.debugShow(dir: "write")
        case "done", "donefinal", "donenext": s.debugFinish()
        case "donemoment":
            // once the moment player has loaded (a few seconds from a cold launch), as after a real lesson
            s.debugFinishWithMoment()
            func whenReady(_ n: Int) {
                if MomentPlayer.shared.ready || n > 60 { router.study = s; return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { whenReady(n + 1) }
            }
            whenReady(0)
            return
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
            .tabItem { tabIcon(.home) }.tag(Router.Tab.home)
            NavigationStack(path: $router.learnPath) {
                PathView().toolbar(.hidden, for: .navigationBar).pageDestinations()
            }
            .tabItem { tabIcon(.learn) }.tag(Router.Tab.learn)
            NavigationStack(path: $router.profilePath) {
                ProfileView().toolbar(.hidden, for: .navigationBar).pageDestinations()
            }
            .tabItem { tabIcon(.profile) }.tag(Router.Tab.profile)
            NavigationStack { SettingsView().toolbar(.hidden, for: .navigationBar) }
                .tabItem { tabIcon(.settings) }.tag(Router.Tab.settings)
        }
        .sensoryFeedback(.selection, trigger: router.tab)
        // the done screen's moment player: loaded just after launch, so it's ready by a lesson's end, and soon for
        // the Streak saved moment a relit day shows on opening (it was 2 s in: the Mac, 20 Oct 2026)
        // (not under the tests: the web view kept the test host busy, ~28 min a run instead of ~4: the Mac, 0.1.60)
        .task { guard !Launch.underTests else { return }; try? await Task.sleep(for: .milliseconds(500)); MomentPlayer.shared.warm() }
        // the Classroom's rooms and their sessions, slid in from the side over everything (see CoverHost)
        .overlay {
            ZStack {
                if let p = router.cover {
                    CoverHost(root: p).transition(.move(edge: .trailing)).zIndex(1)
                }
                if let s = router.coverStudy {
                    StudyView(session: s) { withAnimation(Router.slide) { router.coverStudy = nil } }
                        .momentsHost(study: true)
                        .background(Color.bg.ignoresSafeArea())
                        .transition(.move(edge: .trailing)).zIndex(2)
                }
            }
        }
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

extension RootView {
    /// A tab's icon, the studio's drawn ones: in colour on the tab you're on, grey and faded on the others;
    /// no words under them (the owner, 13 Oct 2026).
    func tabIcon(_ t: Router.Tab) -> Image {
        let name = "tab2-\(t.rawValue)" + (router.tab == t ? "" : "-off")
        return Image(uiImage: Self.icon(name))
    }

    /// Drawn at 30 points tall, kept in its own colours (a tab bar otherwise tints it as a template).
    static func icon(_ name: String) -> UIImage {
        if let c = iconCache[name] { return c }
        guard let im = UIImage(named: name) else { return UIImage() }
        let h: CGFloat = 30, size = CGSize(width: h * im.size.width / im.size.height, height: h)
        let out = UIGraphicsImageRenderer(size: size).image { _ in im.draw(in: CGRect(origin: .zero, size: size)) }.withRenderingMode(.alwaysOriginal)
        iconCache[name] = out
        return out
    }
}
private var iconCache: [String: UIImage] = [:]

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
