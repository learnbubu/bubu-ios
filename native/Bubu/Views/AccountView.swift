import SwiftUI

/// Settings' Account section (web: #acctBox): sign in with the website's account to
/// back up progress and share it with the website and other devices.
struct AccountSection: View {
    @State private var cloud: Cloud = {
        #if DEBUG
        if Launch.screen == "account" { return Cloud.demo() }
        #endif
        return Cloud.shared
    }()
    @State private var email = ""
    @State private var password = ""
    @State private var busy = false
    @State private var note: (text: String, ok: Bool)?
    @State private var confirmDelete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Account").font(.nunitoXB(16)).foregroundStyle(Color.ink)
                Spacer()
                Text(cloud.signedIn ? cloud.email : "Not signed in")
                    .font(.nunito(13)).foregroundStyle(Color.muted).lineLimit(1).truncationMode(.middle)
            }
            if cloud.signedIn { signedIn } else { signedOut }
            if let n = note {
                Text(n.text).font(.nunito(13, .bold)).foregroundStyle(n.ok ? Color.good : Color.again)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 14)
        .panel(radius: 18)
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { Task { await deleteAccount() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This erases the progress saved in the cloud for \(cloud.email) and signs you out. Progress on this phone stays.\n\nSign out on the website and any other device first, or they'll upload their progress again.\n\nThe sign-in itself (your email and password) can't be removed from the app yet.")
        }
    }

    // MARK: signed out

    private var signedOut: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sign in to back up your progress and use it on the website or another device. It's the same account as the website.")
                .font(.nunito(13)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
            field { TextField("you@example.com", text: $email).keyboardType(.emailAddress).textContentType(.username) }
            field { SecureField("Password", text: $password).textContentType(.password) }
            HStack(spacing: 8) {
                Button(busy ? "Signing in…" : "Sign in") { Task { await go(signUp: false) } }.buttonStyle(WideButton())
                Button("Create account") { Task { await go(signUp: true) } }.buttonStyle(WideButton(ghost: true))
            }
            .disabled(busy)
        }
    }

    private func field<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        c().font(.nunito(16)).textInputAutocapitalization(.never).autocorrectionDisabled()
            .padding(11).background(Color.bg, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.line))
    }

    private func go(signUp: Bool) async {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty, !password.isEmpty else { return note = ("Enter an email and password.", false) }
        guard password.count >= 6 else { return note = ("Password needs at least 6 characters.", false) }
        busy = true; note = (signUp ? "Creating account…" : "Signing in…", true)
        defer { busy = false }
        do {
            if signUp {
                let inNow = try await cloud.signUp(email: e, password: password)
                password = ""
                note = inNow ? ("Account created. Progress synced.", true) : ("Check your email to confirm, then sign in.", true)
            } else {
                try await cloud.signIn(email: e, password: password)
                password = ""
                note = ("Signed in. Progress synced.", true)
            }
        } catch {
            note = (error.localizedDescription, false)
        }
    }

    // MARK: signed in

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.periodic(from: .now, by: 30)) { t in
                Text(syncLine(t.date)).font(.nunito(13)).foregroundStyle(Color.muted)
            }
            HStack(spacing: 8) {
                Button(cloud.syncing ? "Syncing…" : "Sync now") {
                    Task {
                        switch await cloud.sync(manual: true) {
                        case .success: note = ("Synced.", true)
                        case .failure(let e): note = (e == .offline ? "Couldn't sync. It'll try again when you're online." : e.localizedDescription, false)
                        }
                    }
                }
                .buttonStyle(WideButton())
                .disabled(cloud.syncing)
                Button("Sign out") {
                    cloud.signOut()
                    note = ("Signed out. Your progress stays on this phone.", true)
                }
                .buttonStyle(WideButton(ghost: true))
            }
            Button("Delete account…") { confirmDelete = true }
                .font(.nunito(14, .bold)).foregroundStyle(Color.again)
                .padding(.top, 2)
        }
    }

    private func syncLine(_ now: Date) -> String {
        if cloud.syncing { return "Syncing…" }
        guard cloud.lastSynced > 0 else { return cloud.pending ? "Not synced yet. It'll sync when you're online." : "Not synced yet." }
        let mins = max(0, Int((now.timeIntervalSince1970 * 1000 - cloud.lastSynced) / 60000))
        let ago = mins == 0 ? "just now" : mins < 60 ? "\(mins) min ago"
            : mins < 1440 ? "\(mins / 60) h ago" : "\(mins / 1440) day\(mins / 1440 == 1 ? "" : "s") ago"
        return "Last synced \(ago)." + (cloud.pending ? " Changes waiting to sync." : "")
    }

    private func deleteAccount() async {
        do {
            try await cloud.deleteCloudData()
            note = ("Your cloud progress is deleted and you're signed out. Progress on this phone stays.", true)
        } catch {
            note = (error.localizedDescription, false)
        }
    }
}

#if DEBUG
extension Cloud {
    /// For the `-screen account` screenshot: signed in, synced a few minutes ago, no network.
    static func demo() -> Cloud {
        let d = UserDefaults(suiteName: "cloud-demo")!
        d.set(Date().timeIntervalSince1970 * 1000 - 4 * 60_000, forKey: syncedKey)
        let s = CloudSession(accessToken: "demo", refreshToken: "", expiresAt: .greatestFiniteMagnitude,
                             userId: "demo", email: "learner@example.com")
        return Cloud(transport: OfflineTransport(), vault: MemoryVault(s), defaults: d)
    }
}

/// A network that's never there.
struct OfflineTransport: CloudTransport {
    func send(_ request: URLRequest) async throws -> HTTPResult { throw URLError(.notConnectedToInternet) }
}
#endif
