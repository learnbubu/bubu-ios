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
    private var pending: (key: String, box: CGRect)?

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
        // (under the tests the page isn't loaded at all: it's never ready, and the done screen keeps its usual splash)
        if !Launch.underTests, let url = Bundle.main.url(forResource: "moments-player", withExtension: "html") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    /// Loads the page (call early: decoding the pictures takes a moment).
    func warm() {}

    func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
        DispatchQueue.main.async {
            self.ready = true
            if let p = self.pending { self.pending = nil; self.play(p.key, in: p.box) }
        }
    }

    /// Plays a moment with its sticker in `box` (in the web view's points).
    func play(_ key: String, in box: CGRect) {
        guard ready else { pending = (key, box); return }
        web.evaluateJavaScript("bubuPlay(\(Self.js(key)), \(Self.js(box))); 0", completionHandler: nil)
    }

    /// The sticker's box moved (the layout settled): it plays on, from there.
    func move(to box: CGRect) {
        if pending != nil { pending?.box = box; return }
        web.evaluateJavaScript("bubuMove(\(Self.js(box))); 0", completionHandler: nil)
    }

    func stop() {
        pending = nil
        web.evaluateJavaScript("window.bubuStop && bubuStop(); 0", completionHandler: nil)
    }

    private static func js(_ s: String) -> String { "\"" + s.filter { $0.isLetter || $0.isNumber } + "\"" }
    private static func js(_ b: CGRect) -> String {
        String(format: "{x:%.1f,y:%.1f,size:%.1f}", b.minX, b.minY, b.width)
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
