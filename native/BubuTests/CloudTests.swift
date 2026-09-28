import XCTest
@testable import Bubu

/// The cloud merge, the payload in the web's shape, the session's expiry and the
/// sync over a fake network (nothing here touches the real one).
final class CloudMergeTests: XCTestCase {
    private let S = CloudMerge.srsKey, D = CloudMerge.doneKey, A = CloudMerge.activityKey, PR = CloudMerge.prefsKey

    private func obj(_ s: String?) -> Any? { s.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8), options: .fragmentsAllowed) } }
    private func text(_ o: Any) -> String { CloudMerge.text(o) }
    private func activity(_ m: [String: String]) -> [String: Any] { obj(m[A]) as? [String: Any] ?? [:] }

    func testAlwaysAllFourKeysAsText() {
        let m = CloudMerge.merge(local: [:], remote: [:])
        XCTAssertEqual(Set(m.keys), Set([S, D, A, PR]))
        XCTAssertEqual(obj(m[S]) as? [String: Int], [:])
        XCTAssertEqual((obj(m[D]) as? [Any])?.count, 0)
        XCTAssertEqual(obj(m[PR]) as? [String: Int], [:])
        // an empty activity still gets the web's defaults: one ember, nothing else
        let a = activity(m)
        XCTAssertEqual(a["embers"] as? Int, 1)
        XCTAssertEqual(a["plus"] as? Bool, false)
        XCTAssertEqual(a["pocketDay"] as? String, "")
        XCTAssertNil(a["buns"]); XCTAssertNil(a["quests"])      // undefined: left out, as JSON.stringify does
    }

    func testSRSMoreRecentOrMoreReviewedWins() {
        let local: [String: Any] = [S: text([
            "newer": ["last": 200, "reps": 1],
            "older": ["last": 100, "reps": 9],
            "moreReps": ["reps": 3, "due": 1],
            "sameRepsLaterDue": ["reps": 2, "due": 50],
            "sameRepsEarlierDue": ["reps": 2, "due": 10],
            "onlyLocal": ["reps": 1],
            "lastVsNone": ["last": 5],
        ])]
        let remote: [String: Any] = [S: text([
            "newer": ["last": 100, "reps": 5],
            "older": ["last": 150, "reps": 1],
            "moreReps": ["reps": 2, "due": 99],
            "sameRepsLaterDue": ["reps": 2, "due": 40],
            "sameRepsEarlierDue": ["reps": 2, "due": 20],
            "onlyRemote": ["reps": 4],
            "lastVsNone": ["reps": 8],
        ])]
        let s = obj(CloudMerge.merge(local: local, remote: remote)[S]) as! [String: [String: Any]]
        XCTAssertEqual(s["newer"]?["reps"] as? Int, 1)              // local, reviewed later
        XCTAssertEqual(s["older"]?["reps"] as? Int, 1)              // remote, reviewed later
        XCTAssertEqual(s["moreReps"]?["reps"] as? Int, 3)           // no dates: more reps
        XCTAssertEqual(s["sameRepsLaterDue"]?["due"] as? Int, 50)   // same reps: later due
        XCTAssertEqual(s["sameRepsEarlierDue"]?["due"] as? Int, 20)
        XCTAssertNotNil(s["onlyLocal"]); XCTAssertNotNil(s["onlyRemote"])
        XCTAssertEqual(s["lastVsNone"]?["last"] as? Int, 5)         // one side has a date: dates decide
    }

    func testDoneIsAUnionInOrder() {
        let m = CloudMerge.merge(local: [D: text(["L1", "L2"])], remote: [D: text(["L2", "L3"])])
        XCTAssertEqual(obj(m[D]) as? [String], ["L1", "L2", "L3"])
        // a value that isn't a list counts as none
        let m2 = CloudMerge.merge(local: [D: text(["a": 1])], remote: [D: text(["L9"])])
        XCTAssertEqual(obj(m2[D]) as? [String], ["L9"])
    }

    func testActivityRules() {
        let local: [String: Any] = [A: text([
            "days": ["2026-09-01": 5, "2026-09-02": 1],
            "xpDays": ["2026-09-01": 30],
            "relit": ["2026-08-30": true],
            "lit": ["2026-09-01": true],
            "embers": 0,
            "emberFor": ["3": "2026-09-01", "7": "2026-09-05"],
            "best": 4, "chests": 2, "boostUntil": 1000, "levelSeen": 3,
            "questMonths": ["2026-09": 4],
            "coinsIn": ["2026-09-01": 30, "2026-09-02": 20],
            "coinsOut": ["2026-09-02": 350],
            "buns": ["n": 2, "at": 10, "t": 500],
            "pocketDay": "2026-09-02",
            "plus": false,
            "celebrated": "2026-09-02",
            "achv": ["first": "2026-09-01"],
        ] as [String: Any])]
        let remote: [String: Any] = [A: text([
            "days": ["2026-09-01": 3, "2026-09-03": 7],
            "xpDays": ["2026-09-01": 40, "2026-09-03": 12],
            "relit": ["2026-08-20": true],
            "lit": ["2026-09-03": true],
            "embers": 2,
            "emberFor": ["3": "2026-08-01", "14": "2026-09-03"],
            "best": 9, "chests": 1, "boostUntil": 5000, "levelSeen": 2,
            "questMonths": ["2026-09": 6, "2026-08": 3],
            "coinsIn": ["2026-09-01": 25, "2026-09-03": 35],
            "coinsOut": ["2026-09-02": 200, "2026-09-03": 250],
            "buns": ["n": 5, "at": 20, "t": 900],
            "pocketDay": "2026-09-03",
            "plus": true,
            "celebrated": "2026-09-03",
            "readsDone": ["s1": "2026-09-03"],
        ] as [String: Any])]
        let a = activity(CloudMerge.merge(local: local, remote: remote))
        XCTAssertEqual(a["days"] as? [String: Int], ["2026-09-01": 5, "2026-09-02": 1, "2026-09-03": 7])
        XCTAssertEqual(a["xpDays"] as? [String: Int], ["2026-09-01": 40, "2026-09-03": 12])
        XCTAssertEqual(a["relit"] as? [String: Bool], ["2026-08-30": true, "2026-08-20": true])
        XCTAssertEqual(a["lit"] as? [String: Bool], ["2026-09-01": true, "2026-09-03": true])
        XCTAssertEqual(a["embers"] as? Int, 2)
        XCTAssertEqual(a["emberFor"] as? [String: String], ["3": "2026-09-01", "7": "2026-09-05", "14": "2026-09-03"])
        XCTAssertEqual(a["best"] as? Int, 9)
        XCTAssertEqual(a["chests"] as? Int, 2)
        XCTAssertEqual(a["boostUntil"] as? Int, 5000)
        XCTAssertEqual(a["levelSeen"] as? Int, 3)
        XCTAssertEqual(a["questMonths"] as? [String: Int], ["2026-09": 6, "2026-08": 3])
        XCTAssertEqual(a["coinsIn"] as? [String: Int], ["2026-09-01": 30, "2026-09-02": 20, "2026-09-03": 35])
        XCTAssertEqual(a["coinsOut"] as? [String: Int], ["2026-09-02": 350, "2026-09-03": 250])
        XCTAssertEqual((a["buns"] as? [String: Int])?["n"], 5)          // the newer change
        XCTAssertEqual(a["pocketDay"] as? String, "2026-09-03")
        XCTAssertEqual(a["plus"] as? Bool, true)
        // anything else: this device's, with the remote's filling gaps
        XCTAssertEqual(a["celebrated"] as? String, "2026-09-02")
        XCTAssertEqual(a["achv"] as? [String: String], ["first": "2026-09-01"])
        XCTAssertEqual(a["readsDone"] as? [String: String], ["s1": "2026-09-03"])
    }

    func testEmbersMissingCountsAsOne() {
        let a = activity(CloudMerge.merge(local: [A: text(["days": [:]])], remote: [A: text(["embers": 0])]))
        XCTAssertEqual(a["embers"] as? Int, 1)
    }

    func testBunsTieGoesToThisDevice() {
        let a = activity(CloudMerge.merge(local: [A: text(["buns": ["n": 1, "at": 0, "t": 7]])],
                                          remote: [A: text(["buns": ["n": 4, "at": 0, "t": 7]])]))
        XCTAssertEqual((a["buns"] as? [String: Int])?["n"], 1)
        // only the remote has buns: the remote's
        let b = activity(CloudMerge.merge(local: [A: text(["days": [:]])], remote: [A: text(["buns": ["n": 3, "at": 0, "t": 1]])]))
        XCTAssertEqual((b["buns"] as? [String: Int])?["n"], 3)
    }

    func testQuests() {
        func q(_ date: String, _ done: [String]) -> [String: Any] {
            ["date": date, "ids": ["xp30", "combo5", "listen5"], "done": Dictionary(uniqueKeysWithValues: done.map { ($0, true) }), "chest": false]
        }
        func pick(_ l: Any?, _ r: Any?) -> [String: Any]? {
            var la: [String: Any] = ["days": [String: Any]()], ra = la
            la["quests"] = l; ra["quests"] = r
            return activity(CloudMerge.merge(local: [A: text(la)], remote: [A: text(ra)]))["quests"] as? [String: Any]
        }
        // same day: whichever claimed more
        XCTAssertEqual((pick(q("2026-09-02", ["xp30"]), q("2026-09-02", ["xp30", "combo5"]))?["done"] as? [String: Bool])?.count, 2)
        XCTAssertEqual((pick(q("2026-09-02", ["xp30"]), q("2026-09-02", ["combo5"]))?["done"] as? [String: Bool]), ["xp30": true])
        // different days: the later day
        XCTAssertEqual(pick(q("2026-09-01", ["xp30", "combo5"]), q("2026-09-02", []))?["date"] as? String, "2026-09-02")
        XCTAssertEqual(pick(q("2026-09-03", []), q("2026-09-02", ["xp30"]))?["date"] as? String, "2026-09-03")
        // only one side has them
        XCTAssertEqual(pick(nil, q("2026-09-02", []))?["date"] as? String, "2026-09-02")
        XCTAssertEqual(pick(q("2026-09-02", []), nil)?["date"] as? String, "2026-09-02")
    }

    func testPrefsThisDeviceWinsRemoteFillsGaps() {
        let m = CloudMerge.merge(local: [PR: text(["theme": "dark", "rate": 0.7])],
                                 remote: [PR: text(["theme": "light", "dailyGoal": 30, "name": "Dom"])])
        let p = obj(m[PR]) as! [String: Any]
        XCTAssertEqual(p["theme"] as? String, "dark")
        XCTAssertEqual(p["rate"] as? Double, 0.7)
        XCTAssertEqual(p["dailyGoal"] as? Int, 30)
        XCTAssertEqual(p["name"] as? String, "Dom")
    }

    /// The row can hold parsed objects as well as JSON text; bad text counts as nothing.
    func testParsedObjectsAndBadText() {
        let m = CloudMerge.merge(local: [D: "not json", A: "{oops"],
                                 remote: [D: ["L1"], A: ["days": ["2026-09-01": 2]]])
        XCTAssertEqual(obj(m[D]) as? [String], ["L1"])
        XCTAssertEqual(activity(m)["days"] as? [String: Int], ["2026-09-01": 2])
    }

    /// Merging with itself changes nothing, and merging twice gives the same as once.
    func testMergeIsStable() {
        let remote: [String: Any] = [A: text(["days": ["2026-09-01": 3], "coinsIn": ["2026-09-01": 20]]), D: text(["L1"])]
        let local: [String: Any] = [A: text(["days": ["2026-09-02": 1]]), D: text(["L2"])]
        let once = CloudMerge.merge(local: local, remote: remote)
        let twice = CloudMerge.merge(local: once, remote: once)
        XCTAssertEqual(activity(once) as NSDictionary, activity(twice) as NSDictionary)
        XCTAssertEqual(obj(once[D]) as? [String], obj(twice[D]) as? [String])
    }
}

final class CloudPayloadTests: XCTestCase {
    private func store() -> ProgressStore {
        ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }

    /// The payload is the web's: the four localStorage keys, each holding JSON text.
    func testLocalPayloadHasTheWebShape() throws {
        let p = store()
        let fresh = CloudPayload.local(p)
        XCTAssertNil(fresh[CloudMerge.prefsKey], "a fresh install lets the account's settings win")
        p.markDone(Course.shared.lessons[0].id)
        p.review(Course.shared.cards[0].id, .good)
        p.name = "Dom"
        p.setHook("好", "a story")
        p.addCoins(25)
        let d = CloudPayload.local(p)
        XCTAssertEqual(Set(d.keys), Set(CloudMerge.keys))
        for (_, v) in d { XCTAssertNotNil(try? JSONSerialization.jsonObject(with: Data(v.utf8))) }
        let a = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(d[CloudMerge.activityKey]!.utf8)) as? [String: Any])
        XCTAssertNotNil(a["days"])
        XCTAssertNil(a["relit"], "empty records aren't sent")
        XCTAssertEqual((a["coinsIn"] as? [String: Int])?.values.first, 25)
        let prefs = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(d[CloudMerge.prefsKey]!.utf8)) as? [String: Any])
        XCTAssertEqual(prefs["name"] as? String, "Dom")
        XCTAssertEqual(prefs["hooks"] as? [String: String], ["好": "a story"])
    }

    /// Encoded here, merged with an empty cloud, decoded on another phone: all of it arrives.
    func testRoundTrip() {
        let a = store()
        a.markDone(Course.shared.lessons[0].id)
        a.review(Course.shared.cards[0].id, .good)
        a.earnXP(12)
        a.lightFire()
        a.addCoins(30)
        a.spendCoins(10)
        a.setBuns(3)
        a.name = "Dom"
        a.prefs.dailyGoal = 30
        let merged = CloudMerge.merge(local: CloudPayload.local(a), remote: [:])

        let b = store()
        XCTAssertTrue(CloudPayload.apply(merged, to: b))
        XCTAssertEqual(b.srs, a.srs)
        XCTAssertEqual(b.done, a.done)
        XCTAssertEqual(b.xpToday, 12)
        XCTAssertEqual(b.streak, 1)
        XCTAssertEqual(b.coins, a.coins)
        XCTAssertEqual(b.bunState.n, 3)
        XCTAssertEqual(b.name, "Dom")
        XCTAssertEqual(b.prefs.dailyGoal, 30)
        // and once applied, applying the same again changes nothing
        let again = CloudMerge.merge(local: CloudPayload.local(b), remote: merged)
        XCTAssertFalse(CloudPayload.apply(again, to: b))
    }

    /// A row written by the website comes into the app.
    func testWebRowDecodes() {
        let card = Course.shared.cards[0].id, lesson = Course.shared.lessons[0].id
        let row: [String: Any] = [
            CloudMerge.srsKey: "{\"\(card)\":{\"ease\":2.4,\"interval\":3,\"due\":1790000000000,\"reps\":1,\"S\":3.17,\"D\":5.3,\"last\":1789740800000,\"known\":true}}",
            CloudMerge.doneKey: "[\"\(lesson)\"]",
            CloudMerge.prefsKey: "{\"theme\":\"dark\",\"dailyGoal\":50,\"name\":\"Web\",\"somethingNew\":1}",
            CloudMerge.activityKey: "{\"days\":{\"2026-09-20\":4},\"xpDays\":{\"2026-09-20\":22},\"lit\":{\"2026-09-20\":true},\"embers\":2,\"coinsIn\":{\"2026-09-20\":30},\"coinsOut\":{\"2026-09-20\":10},\"buns\":{\"n\":2,\"at\":1789740800000,\"t\":1789740800000},\"pocketDay\":\"2026-09-20\",\"plus\":false,\"chests\":1,\"levelSeen\":2}",
        ]
        let p = store()
        XCTAssertTrue(CloudPayload.apply(CloudMerge.merge(local: CloudPayload.local(p), remote: row), to: p))
        XCTAssertEqual(p.srs[card]?.reps, 1)
        XCTAssertTrue(p.isDone(lesson))
        XCTAssertEqual(p.prefs.theme, "dark")
        XCTAssertEqual(p.prefs.dailyGoal, 50)
        XCTAssertEqual(p.name, "Web")
        XCTAssertEqual(p.activity.xpDays["2026-09-20"], 22)
        XCTAssertEqual(p.embers, 2)
        XCTAssertEqual(p.coins, ProgressStore.coinsStart + 20)
        XCTAssertEqual(p.activity.buns?.n, 2)
        XCTAssertEqual(p.activity.pocketDay, "2026-09-20")
        XCTAssertEqual(p.activity.chests, 1)
    }
}

final class CloudSessionTests: XCTestCase {
    func testExpiryFromExpiresAt() throws {
        let s = try XCTUnwrap(CloudSession(json: ["access_token": "a", "refresh_token": "r", "expires_at": 10_000, "expires_in": 3600,
                                                  "user": ["id": "u1", "email": "x@y.z"]]))
        XCTAssertEqual(s.expiresAt, 10_000)
        XCTAssertEqual(s.userId, "u1"); XCTAssertEqual(s.email, "x@y.z")
        XCTAssertFalse(s.needsRefresh(now: Date(timeIntervalSince1970: 9_000)))
        XCTAssertTrue(s.needsRefresh(now: Date(timeIntervalSince1970: 9_950)), "within a minute of expiry")
        XCTAssertTrue(s.needsRefresh(now: Date(timeIntervalSince1970: 20_000)))
    }

    func testExpiryFromExpiresIn() throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let s = try XCTUnwrap(CloudSession(json: ["access_token": "a", "refresh_token": "r", "expires_in": 3600, "user": ["id": "u"]], now: now))
        XCTAssertEqual(s.expiresAt, 4_600)
    }

    func testNoSessionWithoutAccessToken() {
        // a sign-up waiting for email confirmation returns a user and no session
        XCTAssertNil(CloudSession(json: ["id": "u", "email": "x@y.z"]))
        XCTAssertNil(CloudSession(json: ["access_token": "", "user": ["id": "u"]]))
    }

    func testNoRefreshTokenNeverRefreshes() {
        let s = CloudSession(accessToken: "a", refreshToken: "", expiresAt: 0, userId: "u", email: "")
        XCTAssertFalse(s.needsRefresh(now: Date()))
    }

    func testSessionSurvivesEncoding() throws {
        let s = CloudSession(accessToken: "a", refreshToken: "r", expiresAt: 12, userId: "u", email: "e")
        XCTAssertEqual(try JSONDecoder().decode(CloudSession.self, from: JSONEncoder().encode(s)), s)
    }
}

/// A token response as Supabase sends it.
func tokenJSON(_ access: String, expiresAt: Double = 4_000_000_000) -> [String: Any] {
    ["access_token": access, "refresh_token": "r-" + access, "expires_at": expiresAt, "user": ["id": "u1", "email": "a@b.c"]]
}

/// A network that answers from a script and remembers what was asked.
final class FakeTransport: CloudTransport {
    var offline = false
    var requests: [URLRequest] = []
    var handler: (URLRequest) -> (Int, Any) = { _ in (200, [String: Any]()) }
    func send(_ request: URLRequest) async throws -> HTTPResult {
        requests.append(request)
        if offline { throw URLError(.notConnectedToInternet) }
        let (status, body) = handler(request)
        return HTTPResult(status: status, data: (try? JSONSerialization.data(withJSONObject: body, options: .fragmentsAllowed)) ?? Data())
    }
}

@MainActor
final class CloudSyncTests: XCTestCase {
    private func store() -> ProgressStore {
        ProgressStore(course: Course.shared, url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json"))
    }
    private func defaults() -> UserDefaults {
        let name = "cloud-test-\(UUID().uuidString)"
        return UserDefaults(suiteName: name)!
    }
    private func cloud(_ t: FakeTransport, session: CloudSession? = nil) -> (Cloud, ProgressStore, MemoryVault) {
        let v = MemoryVault(session)
        let c = Cloud(transport: t, vault: v, defaults: defaults())
        c.debounceSeconds = 1000
        let p = store()
        c.attach(p)
        return (c, p, v)
    }

    func testSignInStoresSessionPullsMergesAndPushes() async throws {
        let t = FakeTransport()
        let lesson = Course.shared.lessons[1].id
        t.handler = { r in
            let u = r.url!.absoluteString
            if u.contains("grant_type=password") { return (200, tokenJSON("tok1")) }
            if r.httpMethod == "GET" { return (200, [["data": [CloudMerge.doneKey: "[\"\(lesson)\"]"]]]) }
            return (201, [String: Any]())
        }
        let (c, p, v) = cloud(t)
        try await c.signIn(email: "a@b.c", password: "secret1")
        XCTAssertTrue(c.signedIn)
        XCTAssertEqual(v.session?.accessToken, "tok1")
        XCTAssertTrue(p.isDone(lesson), "the cloud's progress was merged in")
        XCTAssertGreaterThan(c.lastSynced, 0)

        XCTAssertEqual(t.requests.count, 3)
        for r in t.requests { XCTAssertEqual(r.value(forHTTPHeaderField: "apikey"), CloudConfig.anonKey) }
        XCTAssertNil(t.requests[0].value(forHTTPHeaderField: "Authorization"))
        let get = t.requests[1]
        XCTAssertEqual(get.url?.absoluteString, CloudConfig.url.absoluteString + "/rest/v1/progress?user_id=eq.u1&select=data")
        XCTAssertEqual(get.value(forHTTPHeaderField: "Authorization"), "Bearer tok1")
        let put = t.requests[2]
        XCTAssertEqual(put.httpMethod, "POST")
        XCTAssertEqual(put.url?.path, "/rest/v1/progress")
        XCTAssertEqual(put.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: put.httpBody!) as? [[String: Any]])
        XCTAssertEqual(body.first?["user_id"] as? String, "u1")
        XCTAssertNotNil(body.first?["updated_at"] as? String)
        let data = try XCTUnwrap(body.first?["data"] as? [String: String])
        XCTAssertEqual(Set(data.keys), Set(CloudMerge.keys))
    }

    func testSignInErrorShowsServerMessage() async {
        let t = FakeTransport()
        t.handler = { _ in (400, ["error": "invalid_grant", "error_description": "Invalid login credentials"]) }
        let (c, _, _) = cloud(t)
        do { try await c.signIn(email: "a@b.c", password: "wrong12"); XCTFail() }
        catch { XCTAssertEqual(error.localizedDescription, "Invalid login credentials") }
        XCTAssertFalse(c.signedIn)
    }

    func testSignUpNeedingConfirmationDoesNotSignIn() async throws {
        let t = FakeTransport()
        t.handler = { _ in (200, ["id": "u1", "email": "a@b.c"]) }
        let (c, _, _) = cloud(t)
        let inNow = try await c.signUp(email: "a@b.c", password: "secret1")
        XCTAssertFalse(inNow)
        XCTAssertFalse(c.signedIn)
        XCTAssertEqual(t.requests.first?.url?.path, "/auth/v1/signup")
    }

    func testA401RefreshesAndReplays() async {
        let t = FakeTransport()
        var gets = 0
        t.handler = { r in
            let u = r.url!.absoluteString
            if u.contains("grant_type=refresh_token") { return (200, tokenJSON("tok2")) }
            if r.httpMethod == "GET" {
                gets += 1
                return r.value(forHTTPHeaderField: "Authorization") == "Bearer tok1" ? (401, ["message": "JWT expired"]) : (200, [Any]())
            }
            return (201, [String: Any]())
        }
        let s = CloudSession(accessToken: "tok1", refreshToken: "r1", expiresAt: 4_000_000_000, userId: "u1", email: "a@b.c")
        let (c, _, v) = cloud(t, session: s)
        let r = await c.sync()
        if case .failure(let e) = r { XCTFail("\(e)") }
        XCTAssertEqual(gets, 2)
        XCTAssertEqual(v.session?.accessToken, "tok2")
        let refresh = t.requests.first { $0.url!.absoluteString.contains("refresh_token") }!
        XCTAssertEqual((try? JSONSerialization.jsonObject(with: refresh.httpBody!) as? [String: String])?["refresh_token"], "r1")
    }

    func testAnExpiredTokenIsRefreshedFirst() async {
        let t = FakeTransport()
        t.handler = { r in
            if r.url!.absoluteString.contains("refresh_token") { return (200, tokenJSON("fresh")) }
            return r.httpMethod == "GET" ? (200, [Any]()) : (201, [String: Any]())
        }
        let s = CloudSession(accessToken: "stale", refreshToken: "r1", expiresAt: 0, userId: "u1", email: "a@b.c")
        let (c, _, _) = cloud(t, session: s)
        await c.sync()
        XCTAssertTrue(t.requests[0].url!.absoluteString.contains("grant_type=refresh_token"))
        XCTAssertEqual(t.requests[1].value(forHTTPHeaderField: "Authorization"), "Bearer fresh")
    }

    func testADeadRefreshTokenSignsOutButKeepsProgress() async {
        let t = FakeTransport()
        t.handler = { r in
            if r.url!.absoluteString.contains("refresh_token") { return (400, ["error": "invalid_grant"]) }
            return (401, [String: Any]())
        }
        let s = CloudSession(accessToken: "tok1", refreshToken: "r1", expiresAt: 4_000_000_000, userId: "u1", email: "a@b.c")
        let (c, p, v) = cloud(t, session: s)
        p.markDone(Course.shared.lessons[0].id)
        await c.sync()
        XCTAssertFalse(c.signedIn)
        XCTAssertNil(v.session)
        XCTAssertTrue(p.isDone(Course.shared.lessons[0].id))
    }

    func testOfflineKeepsTheSessionAndWaits() async {
        let t = FakeTransport()
        t.offline = true
        let s = CloudSession(accessToken: "tok1", refreshToken: "r1", expiresAt: 0, userId: "u1", email: "a@b.c")
        let (c, _, v) = cloud(t, session: s)
        let r = await c.sync()
        guard case .failure(let e) = r else { return XCTFail() }
        XCTAssertEqual(e, .offline)
        XCTAssertTrue(c.signedIn, "a network error never ends the session")
        XCTAssertNotNil(v.session)
        XCTAssertTrue(c.pending)
        XCTAssertEqual(c.lastSynced, 0)
    }

    func testSignOutForgetsTheSessionNotTheProgress() {
        let s = CloudSession(accessToken: "tok1", refreshToken: "r1", expiresAt: 4_000_000_000, userId: "u1", email: "a@b.c")
        let (c, p, v) = cloud(FakeTransport(), session: s)
        p.markDone(Course.shared.lessons[0].id)
        c.signOut()
        XCTAssertFalse(c.signedIn); XCTAssertNil(v.session)
        XCTAssertTrue(p.isDone(Course.shared.lessons[0].id))
    }

    func testDeleteRemovesTheCloudRowAndSignsOut() async throws {
        let t = FakeTransport()
        t.handler = { _ in (204, [String: Any]()) }
        let s = CloudSession(accessToken: "tok1", refreshToken: "r1", expiresAt: 4_000_000_000, userId: "u1", email: "a@b.c")
        let (c, _, _) = cloud(t, session: s)
        try await c.deleteCloudData()
        XCTAssertEqual(t.requests.last?.httpMethod, "DELETE")
        XCTAssertEqual(t.requests.last?.url?.absoluteString, CloudConfig.url.absoluteString + "/rest/v1/progress?user_id=eq.u1")
        XCTAssertFalse(c.signedIn)
    }
}
