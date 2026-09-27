import SwiftUI

@main
struct BubuApp: App {
    @State private var progress = ProgressStore(course: Course.shared)

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(progress)
                .tint(.accent)
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
}
