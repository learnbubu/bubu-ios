import SwiftUI
import WebKit

/// The done screen's sticker moments, played by the effects studio's own code: `moments-player.html`
/// (built by the studio's `player.js`, with the layers, masks, bend weights and timings saved there),
/// in one transparent web view that's loaded once, a little after launch, and reused.
final class MomentPlayer: NSObject, WKScriptMessageHandler {
    static let shared = MomentPlayer()

    let web: WKWebView
    /// the page has its pictures decoded and can play
    private(set) var ready = false
    /// the page is loaded at all (not under the tests)
    var loaded: Bool { web.url != nil }
    static let readyNote = Notification.Name("bubuMomentPlayerReady")
    /// a moment's first frame is on screen (a still picture standing in for it can go)
    static let playingNote = Notification.Name("bubuMomentPlaying")
    private var pending: (key: String, box: CGRect)?
    /// counts plays, so a late fallback belongs to the play that set it
    private var plays = 0

    override init() {
        let cfg = WKWebViewConfiguration()
        let uc = WKUserContentController()
        cfg.userContentController = uc
        web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: cfg)
        super.init()
        uc.add(self, name: "bubu")
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        web.scrollView.isScrollEnabled = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.isUserInteractionEnabled = false
        // unseen until a moment has drawn its first frame (nothing of the page shows while it loads)
        web.alpha = 0
        // (under the tests the page isn't loaded at all: it's never ready, and the done screen keeps its usual splash)
        if !Launch.underTests, let url = Bundle.main.url(forResource: "moments-player", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    /// Loads the page (call early: decoding the pictures takes a moment).
    func warm() {}

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        if (m.body as? String) == "playing" {
            DispatchQueue.main.async {
                self.web.alpha = 1
                NotificationCenter.default.post(name: Self.playingNote, object: nil)
            }
            return
        }
        DispatchQueue.main.async {
            self.ready = true
            NotificationCenter.default.post(name: Self.readyNote, object: nil)
            if let p = self.pending { self.pending = nil; self.play(p.key, in: p.box) }
        }
    }

    /// Plays a moment with its sticker in `box` (in the web view's points).
    func play(_ key: String, in box: CGRect) {
        guard ready else { pending = (key, box); return }
        web.evaluateJavaScript("bubuPlay(\(Self.js(key)), \(Self.js(box))); 0", completionHandler: nil)
        // (if the page's "playing" never comes, it's shown anyway: a moment must never go unseen)
        plays += 1
        let n = plays
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self, self.plays == n, self.pending == nil else { return }
            self.web.alpha = 1
        }
    }

    /// The sticker's box moved (the layout settled): it plays on, from there.
    func move(to box: CGRect) {
        if pending != nil { pending?.box = box; return }
        web.evaluateJavaScript("bubuMove(\(Self.js(box))); 0", completionHandler: nil)
    }

    func stop() {
        plays += 1
        pending = nil
        web.alpha = 0
        web.evaluateJavaScript("window.bubuStop && bubuStop(); 0", completionHandler: nil)
    }

    private static func js(_ s: String) -> String { "\"" + s.filter { $0.isLetter || $0.isNumber } + "\"" }
    private static func js(_ b: CGRect) -> String {
        String(format: "{x:%.1f,y:%.1f,size:%.1f}", b.minX, b.minY, b.width)
    }
}

/// A square where a moment plays (the player's layer must be on screen, over it: `MomentStage`).
/// The still picture shows until the moment's first frame is drawn, and if it never is.
struct StickerMoment: View {
    let key: String
    let still: String
    var side: CGFloat = 220
    /// room round the still (none when it's the moment's own first frame, framed as the sticker)
    var stillInset: CGFloat = 0.12
    @State private var ready = MomentPlayer.shared.ready
    @State private var drawn = false
    @State private var box: CGRect = .zero
    @State private var started = false

    var body: some View {
        Color.clear
            .frame(width: side, height: side)
            .overlay { Image(still).resizable().scaledToFit().padding(side * stillInset).opacity(drawn ? 0 : 1) }
            .background(GeometryReader { g in
                Color.clear
                    .onAppear { box = g.frame(in: .global); place() }
                    .onChange(of: g.frame(in: .global)) { _, f in box = f; place() }
            })
            .onReceive(NotificationCenter.default.publisher(for: MomentPlayer.readyNote)) { _ in ready = true; place() }
            .onReceive(NotificationCenter.default.publisher(for: MomentPlayer.playingNote)) { _ in
                guard started else { return }
                withAnimation(.easeOut(duration: 0.25)) { drawn = true }
            }
            .onDisappear { started = false }
    }

    private func place() {
        guard ready, box.width > 20 else { return }
        // (the player's layer covers the whole window, so its origin is the screen's)
        let b = box
        if started { MomentPlayer.shared.move(to: b) } else { started = true; MomentPlayer.shared.play(key, in: b) }
    }
}

/// Where the player's web view sits: a full-screen layer over the done screen that lets touches through.
struct MomentStage: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        v.isUserInteractionEnabled = false
        let w = MomentPlayer.shared.web
        w.removeFromSuperview()
        w.frame = v.bounds
        w.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.addSubview(w)
        return v
    }
    func updateUIView(_ v: UIView, context: Context) {}
    static func dismantleUIView(_ v: UIView, coordinator: ()) { MomentPlayer.shared.stop() }
}
