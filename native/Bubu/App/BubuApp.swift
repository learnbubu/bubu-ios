import SwiftUI

@main
struct BubuApp: App {
    @State private var progress: ProgressStore = {
        #if DEBUG
        // the reward screenshots each start from a store of their own
        if let s = Launch.screen, Launch.rewardScreens.contains(s) { return ProgressStore.debugRewards(s) }
        if let s = Launch.screen, Launch.stepScreens.contains(s) { return ProgressStore.debugSteps(s) }
        #endif
        return ProgressStore(course: Course.shared)
    }()

    // reminder taps are handled from the first moment, even on a cold launch
    init() { Reminders.shared.install() }
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(progress)
                .tint(.accent)
        }
        // signed in: pull and merge on launch and whenever the app comes to the front
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active, Launch.screen == nil else { return }
            Cloud.shared.attach(progress)
            Task { await Cloud.shared.sync() }
        }
    }
}

/// Launch arguments used by the cloud screenshot run: `-screen path`, `-screen lesson`, …
enum Launch {
    static var screen: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-screen"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }
    /// `-plus`, in debug builds only: run as a Bùbù Plus member (there's no purchase yet).
    static var plus: Bool { ProcessInfo.processInfo.arguments.contains("-plus") }
    static let rewardScreens: Set<String> = ["hud", "buns", "shop", "pocket"]
    /// the lesson-step screenshots: the path with a step badge, and the done screens
    static let stepScreens: Set<String> = ["pathstep", "donefinal", "donenext"]
}
