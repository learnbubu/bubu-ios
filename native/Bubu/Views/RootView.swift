import SwiftUI

struct RootView: View {
    enum Tab: String { case home, learn, profile, settings }
    @State private var tab: Tab = {
        switch Launch.screen {
        case "path", "lesson": return .learn
        case "profile": return .profile
        case "settings": return .settings
        default: return .home
        }
    }()

    var body: some View {
        TabView(selection: $tab) {
            HomeView(openLearn: { tab = .learn })
                .tabItem { Label("Home", systemImage: "house") }.tag(Tab.home)
            PathView()
                .tabItem { Label("Learn", systemImage: "point.topleft.down.to.point.bottomright.curvepath") }.tag(Tab.learn)
            ComingSoon(title: "Profile", icon: "person.crop.circle")
                .tabItem { Label("Profile", systemImage: "person") }.tag(Tab.profile)
            ComingSoon(title: "Settings", icon: "gearshape")
                .tabItem { Label("Settings", systemImage: "gearshape") }.tag(Tab.settings)
        }
        .sensoryFeedback(.selection, trigger: tab)
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
