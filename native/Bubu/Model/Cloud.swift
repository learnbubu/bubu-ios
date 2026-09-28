import Foundation
import Network
import Observation
import Security

/// Sign-in and cloud sync with the website's Supabase project, over the same REST
/// endpoints and headers the web uses (app.js "ACCOUNT + CLOUD SYNC"), so one
/// account shows the same progress on both.
///
/// Local-first, like the web: the progress file stays the source of truth and
/// everything works offline; signing in only adds a cloud copy that is merged
/// (never overwritten) with this phone's.
enum CloudConfig {
    static let url = URL(string: "https://cthoynfsgpqgthxpmngm.supabase.co")!
    /// The PUBLIC anon key, designed to be embedded in a client (row-level security
    /// protects the data). Never the service_role key.
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0aG95bmZzZ3BxZ3RoeHBtbmdtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ2MDM3NDksImV4cCI6MjEwMDE3OTc0OX0.nj0EP_CL5wA61D9ebjTKIDwMLj3ou_2LtEVSN1Rsn1E"
}

// MARK: - the session

/// A signed-in session. Only what's needed is kept (in the Keychain), never logged.
struct CloudSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double          // seconds since 1970
    var userId: String
    var email: String

    /// From Supabase's token response; nil if it has no access token (e.g. a
    /// sign-up waiting for email confirmation).
    init?(json: [String: Any], now: Date = Date()) {
        guard let at = json["access_token"] as? String, !at.isEmpty,
              let user = json["user"] as? [String: Any], let id = user["id"] as? String else { return nil }
        accessToken = at
        refreshToken = json["refresh_token"] as? String ?? ""
        if let e = json["expires_at"] as? NSNumber { expiresAt = e.doubleValue }
        else { expiresAt = now.timeIntervalSince1970 + ((json["expires_in"] as? NSNumber)?.doubleValue ?? 3600) }
        userId = id
        email = user["email"] as? String ?? ""
    }
    init(accessToken: String, refreshToken: String, expiresAt: Double, userId: String, email: String) {
        self.accessToken = accessToken; self.refreshToken = refreshToken
        self.expiresAt = expiresAt; self.userId = userId; self.email = email
    }

    /// Refresh a minute early, so a request never goes out with a token about to lapse.
    static let leeway: Double = 60
    func needsRefresh(now: Date = Date()) -> Bool {
        !refreshToken.isEmpty && now.timeIntervalSince1970 >= expiresAt - Self.leeway
    }
}

/// Where the session is kept between launches.
protocol SessionVault {
    func load() -> CloudSession?
    func save(_ s: CloudSession?)
}

/// The Keychain, this device only.
struct KeychainVault: SessionVault {
    var service = "com.bubu.cloud"
    var account = "session"
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }
    func load() -> CloudSession? {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return try? JSONDecoder().decode(CloudSession.self, from: d)
    }
    func save(_ s: CloudSession?) {
        SecItemDelete(query as CFDictionary)
        guard let s, let d = try? JSONEncoder().encode(s) else { return }
        var q = query
        q[kSecValueData as String] = d
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}

/// For tests and previews.
final class MemoryVault: SessionVault {
    var session: CloudSession?
    init(_ s: CloudSession? = nil) { session = s }
    func load() -> CloudSession? { session }
    func save(_ s: CloudSession?) { session = s }
}

// MARK: - the network, behind a protocol

struct HTTPResult { var status: Int; var data: Data }

protocol CloudTransport {
    /// Throws only when the request couldn't be made at all (offline, timed out).
    func send(_ request: URLRequest) async throws -> HTTPResult
}

struct URLSessionTransport: CloudTransport {
    func send(_ request: URLRequest) async throws -> HTTPResult {
        let (data, resp) = try await URLSession.shared.data(for: request)
        return HTTPResult(status: (resp as? HTTPURLResponse)?.statusCode ?? 0, data: data)
    }
}

enum CloudError: LocalizedError, Equatable {
    case offline
    case server(String)
    var errorDescription: String? {
        switch self {
        case .offline: return "You're offline. Connect to the internet and try again."
        case .server(let m): return m
        }
    }
}

// MARK: - the payload, in the web's shape

/// The progress row's `data`: `{ "<localStorage key>": "<json text>" }` for srs, prefs,
/// done and activity, the same four keys (and format) as the web's localPayload and backups.
enum CloudPayload {
    /// This phone's progress as the web would hold it in localStorage. Like the web,
    /// only what has been set is written: settings are left out on a fresh install
    /// (so the account's win), and empty activity records aren't sent to overwrite
    /// the account's.
    static func local(_ p: ProgressStore) -> [String: String] {
        var d: [String: String] = [:]
        d[CloudMerge.srsKey] = encode(p.srs)
        d[CloudMerge.doneKey] = encode(p.done.sorted())
        let fresh = p.srs.isEmpty && p.done.isEmpty && p.activity.xpDays.isEmpty
        var prefs: [String: Any] = fresh ? [:] : p.prefsJSON()
        if !p.name.isEmpty { prefs["name"] = p.name }
        if !p.hooks.isEmpty { prefs["hooks"] = p.hooks }
        if !prefs.isEmpty { d[CloudMerge.prefsKey] = CloudMerge.text(prefs) }
        if let data = try? JSONEncoder().encode(p.activity),
           var a = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for (k, v) in a where k != "days" {
                if let o = v as? [String: Any], o.isEmpty { a[k] = nil }
                if let o = v as? [Any], o.isEmpty { a[k] = nil }
            }
            d[CloudMerge.activityKey] = CloudMerge.text(a)
        }
        return d
    }

    private static func encode<T: Encodable>(_ v: T) -> String {
        (try? JSONEncoder().encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    struct Decoded: Equatable {
        var srs: [String: SRSRecord]
        var done: Set<String>
        var activity: Activity
        var prefs: Prefs
        var name: String
        var hooks: [String: String]
    }

    /// A merged payload as the app's own records. Word records decode one by one, so
    /// a single odd record can't sink the rest; the old edition's ids move over.
    static func decode(_ merged: [String: String], fallbackName: String = "") -> Decoded {
        let obj = { (k: String) -> Any? in CloudMerge.P(merged[k]) }
        var srs: [String: SRSRecord] = [:]
        for (id, v) in obj(CloudMerge.srsKey) as? [String: Any] ?? [:] {
            if let d = try? JSONSerialization.data(withJSONObject: v), let r = try? JSONDecoder().decode(SRSRecord.self, from: d) { srs[id] = r }
        }
        let done = Set((obj(CloudMerge.doneKey) as? [Any] ?? []).compactMap { $0 as? String })
        let prefsObj = obj(CloudMerge.prefsKey) as? [String: Any] ?? [:]
        let prefs = (try? JSONSerialization.data(withJSONObject: prefsObj)).flatMap { try? JSONDecoder().decode(Prefs.self, from: $0) } ?? Prefs()
        let activity = merged[CloudMerge.activityKey].flatMap { try? JSONDecoder().decode(Activity.self, from: Data($0.utf8)) } ?? Activity()
        return Decoded(srs: srs, done: done, activity: activity, prefs: prefs,
                       name: prefsObj["name"] as? String ?? fallbackName, hooks: prefsObj["hooks"] as? [String: String] ?? [:])
    }

    /// Put a merged payload into the store. False if nothing changed (so nothing is saved).
    @discardableResult
    static func apply(_ merged: [String: String], to p: ProgressStore) -> Bool {
        var d = decode(merged, fallbackName: p.name)
        _ = Backup.migrate(&d.srs)
        let lessonIds = Set(Course.shared.lessons.map(\.id))
        Backup.migrateDone(&d.done, srs: d.srs)            // old lesson ids finish their stones (web: migrateOldDone)
        if let chosen = d.prefs.lessons, chosen.contains(where: { !lessonIds.contains($0) }) { d.prefs.lessons = nil }
        let now = Decoded(srs: p.srs, done: p.done, activity: p.activity, prefs: p.prefs, name: p.name, hooks: p.hooks)
        guard d != now else { return false }
        p.replaceAll(srs: d.srs, done: d.done, activity: d.activity, name: d.name, hooks: d.hooks, prefs: d.prefs)
        return true
    }
}

// MARK: - the service

@MainActor
@Observable
final class Cloud {
    static let shared = Cloud()

    private(set) var session: CloudSession?
    private(set) var syncing = false
    private(set) var lastSynced: Double = 0           // ms, 0 = never
    /// A sync is waiting for the network or a retry.
    private(set) var pending = false

    var signedIn: Bool { session != nil }
    var email: String { session?.email ?? "" }

    @ObservationIgnored private let transport: CloudTransport
    @ObservationIgnored private let vault: SessionVault
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored var now: () -> Date = Date.init
    @ObservationIgnored private weak var store: ProgressStore?
    @ObservationIgnored private var applying = false
    @ObservationIgnored private var again = false
    @ObservationIgnored private var debounce: Task<Void, Never>?
    @ObservationIgnored private var retry: Task<Void, Never>?
    @ObservationIgnored private var retryDelay: Double = 0
    @ObservationIgnored private var monitor: NWPathMonitor?
    @ObservationIgnored private var online = true
    /// Seconds to wait after a change before pushing (the web waits 4).
    @ObservationIgnored var debounceSeconds: Double = 4

    static let syncedKey = "cloud.lastSync"

    init(transport: CloudTransport = URLSessionTransport(), vault: SessionVault = KeychainVault(),
         defaults: UserDefaults = .standard) {
        self.transport = transport; self.vault = vault; self.defaults = defaults
        session = vault.load()
        lastSynced = defaults.double(forKey: Self.syncedKey)
    }

    /// Connect to the progress store: its saves queue a sync, and the network coming
    /// back runs one that was waiting.
    func attach(_ p: ProgressStore) {
        store = p
        // straight away when on the main thread, so a save made while applying a merge is recognised
        p.didSave = { [weak self] in
            if Thread.isMainThread { MainActor.assumeIsolated { self?.storeDidSave() } }
            else { Task { @MainActor in self?.storeDidSave() } }
        }
        guard monitor == nil else { return }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let was = self.online
                self.online = path.status == .satisfied
                if self.online && !was && self.pending { await self.sync() }
            }
        }
        m.start(queue: .global(qos: .utility))
        monitor = m
    }

    /// The store saved: push once the changes stop (web: queueSync).
    func storeDidSave() {
        guard signedIn, !applying else { return }
        pending = true
        debounce?.cancel()
        let wait = debounceSeconds
        debounce = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    // MARK: requests

    private func request(_ path: String, method: String = "GET", body: Any? = nil,
                         headers: [String: String] = [:], auth: Bool) -> URLRequest {
        var r = URLRequest(url: URL(string: CloudConfig.url.absoluteString + path)!)
        r.httpMethod = method
        r.timeoutInterval = 20
        r.setValue(CloudConfig.anonKey, forHTTPHeaderField: "apikey")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (k, v) in headers { r.setValue(v, forHTTPHeaderField: k) }
        if auth, let s = session { r.setValue("Bearer \(s.accessToken)", forHTTPHeaderField: "Authorization") }
        if let body { r.httpBody = try? JSONSerialization.data(withJSONObject: body) }
        return r
    }

    private func json(_ d: Data) -> [String: Any] { (try? JSONSerialization.jsonObject(with: d) as? [String: Any]) ?? [:] }

    private func setSession(_ s: CloudSession?) {
        session = s
        vault.save(s)
    }

    enum Refresh { case ok, dead, transient }

    /// Swap the refresh token for a new session. Only a definite rejection (400/401)
    /// ends the session, never a network error or a 5xx, as on the web.
    func refresh() async -> Refresh {
        guard let s = session, !s.refreshToken.isEmpty else { return .transient }
        let r: HTTPResult
        do {
            r = try await transport.send(request("/auth/v1/token?grant_type=refresh_token", method: "POST",
                                                 body: ["refresh_token": s.refreshToken], auth: false))
        } catch { return .transient }
        if (200..<300).contains(r.status), let n = CloudSession(json: json(r.data), now: now()) {
            setSession(n); return .ok
        }
        if r.status == 400 || r.status == 401 { endSession(); return .dead }
        return .transient
    }

    /// A signed-in request: the token is refreshed first if it's about to lapse, and
    /// once more on a 401, then the request replayed (web: sbAuthed).
    func authed(_ path: String, method: String = "GET", body: Any? = nil, headers: [String: String] = [:]) async throws -> HTTPResult {
        if let s = session, s.needsRefresh(now: now()) { _ = await refresh() }
        guard session != nil else { throw CloudError.server("Signed out.") }
        let r: HTTPResult
        do { r = try await transport.send(request(path, method: method, body: body, headers: headers, auth: true)) }
        catch { throw CloudError.offline }
        guard r.status == 401 else { return r }
        guard await refresh() == .ok else { return r }
        do { return try await transport.send(request(path, method: method, body: body, headers: headers, auth: true)) }
        catch { throw CloudError.offline }
    }

    // MARK: signing in and out

    static func message(_ j: [String: Any], _ fallback: String, signIn: Bool) -> String {
        let order = signIn ? ["error_description", "msg", "message"] : ["msg", "error_description", "message"]
        return order.lazy.compactMap { j[$0] as? String }.first ?? fallback
    }

    /// Create an account. True when signed straight in; false when Supabase wants the
    /// email confirmed first.
    func signUp(email: String, password: String) async throws -> Bool {
        let r: HTTPResult
        do { r = try await transport.send(request("/auth/v1/signup", method: "POST", body: ["email": email, "password": password], auth: false)) }
        catch { throw CloudError.offline }
        let j = json(r.data)
        guard (200..<300).contains(r.status) else { throw CloudError.server(Self.message(j, "Sign-up failed", signIn: false)) }
        guard let s = CloudSession(json: j, now: now()) else { return false }
        setSession(s)
        await sync()
        return true
    }

    func signIn(email: String, password: String) async throws {
        let r: HTTPResult
        do { r = try await transport.send(request("/auth/v1/token?grant_type=password", method: "POST", body: ["email": email, "password": password], auth: false)) }
        catch { throw CloudError.offline }
        let j = json(r.data)
        guard (200..<300).contains(r.status), let s = CloudSession(json: j, now: now()) else {
            throw CloudError.server(Self.message(j, "Sign-in failed", signIn: true))
        }
        setSession(s)
        await sync()                              // pull anything already in the cloud
    }

    /// Progress on this phone is deliberately left alone: signing out never wipes it.
    func signOut() { endSession() }

    private func endSession() {
        debounce?.cancel(); retry?.cancel()
        setSession(nil)
        pending = false
        lastSynced = 0
        defaults.removeObject(forKey: Self.syncedKey)
    }

    /// Erase this account's progress row in the cloud, then sign out. Progress on this
    /// phone stays. (Removing the sign-in itself needs a server function the project
    /// doesn't have yet; see ROADMAP.md.)
    func deleteCloudData() async throws {
        guard let uid = session?.userId else { return }
        let r = try await authed("/rest/v1/progress?user_id=eq.\(uid)", method: "DELETE")
        guard (200..<300).contains(r.status) else { throw CloudError.server("The cloud copy couldn't be deleted. Try again later.") }
        // then the sign-in itself (the project's delete_user() function removes the caller)
        let d = try await authed("/rest/v1/rpc/delete_user", method: "POST", body: [String: Any]())
        guard (200..<300).contains(d.status) else { throw CloudError.server("Your progress is deleted, but the account couldn't be. Try again later.") }
        endSession()
    }

    // MARK: sync

    /// Pull, merge, apply, push (web: cloudSync). Quiet when it fails: it's retried
    /// later, and only a sync the learner asked for reports an error.
    @discardableResult
    func sync(manual: Bool = false) async -> Result<Void, CloudError> {
        guard let s = session else { return .success(()) }
        guard let store else { return .success(()) }
        if syncing { again = true; return .success(()) }
        syncing = true
        defer { syncing = false }
        do {
            let get = try await authed("/rest/v1/progress?user_id=eq.\(s.userId)&select=data")
            guard (200..<300).contains(get.status) else { throw CloudError.server("Couldn't sync. It'll try again later.") }
            let rows = (try? JSONSerialization.jsonObject(with: get.data) as? [[String: Any]]) ?? []
            let remote = rows.first?["data"] as? [String: Any] ?? [:]
            let merged = CloudMerge.merge(local: CloudPayload.local(store), remote: remote)

            applying = true
            CloudPayload.apply(merged, to: store)
            applying = false

            guard let uid = session?.userId else { return .success(()) }
            let row: [String: Any] = ["user_id": uid, "data": merged,
                                      "updated_at": ISO8601DateFormatter().string(from: now())]
            let put = try await authed("/rest/v1/progress", method: "POST", body: [row],
                                       headers: ["Prefer": "resolution=merge-duplicates"])
            guard (200..<300).contains(put.status) else { throw CloudError.server("Couldn't sync. It'll try again later.") }

            lastSynced = now().timeIntervalSince1970 * 1000
            defaults.set(lastSynced, forKey: Self.syncedKey)
            pending = false
            retryDelay = 0
            retry?.cancel()
            if again { again = false; Task { await self.sync() } }
            return .success(())
        } catch {
            applying = false
            again = false
            if session != nil { pending = true; scheduleRetry() }
            return .failure(error as? CloudError ?? .offline)
        }
    }

    /// Try again later, waiting longer each time (30 s up to 15 min); the network
    /// coming back or the app coming to the front tries sooner.
    private func scheduleRetry() {
        retryDelay = min(max(30, retryDelay * 2), 900)
        retry?.cancel()
        let wait = retryDelay
        retry = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }
}
