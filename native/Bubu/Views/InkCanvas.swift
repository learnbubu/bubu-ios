import SwiftUI
import UIKit

/// The pen. A UIKit surface draws the stroke under the finger itself, from every coalesced
/// touch plus the predicted ones, as a brush (`InkGeometry.brushPath`: a filled outline
/// around a smoothed centre line, wider when slower, tapered at both ends), so the ink keeps
/// up at 120 Hz without SwiftUI re-rendering on each sample. Only the finished stroke goes
/// back to SwiftUI, whose answer says how the ink leaves.
struct InkCanvas: UIViewRepresentable {
    enum Verdict {
        /// Right: the ink fades as the real stroke draws in beneath it.
        case accepted
        /// Wrong: the ink flashes red and goes.
        case rejected
        /// Kept by SwiftUI (free writing), which now draws it: the ink hands over.
        case kept
        /// Nothing to judge (a tap): the ink just goes.
        case dropped
    }

    /// A finished stroke: the touch points (for checking) and the brush outline as drawn.
    struct Stroke {
        let points: [CGPoint]
        let outline: CGPath
    }

    var enabled = true
    var brush: InkGeometry.Brush = .standard
    /// The finished stroke, in the view's coordinates.
    var onStroke: (Stroke) -> Verdict

    func makeUIView(context: Context) -> InkView {
        let v = InkView(frame: .zero)
        v.onStroke = onStroke
        v.brush = brush
        v.isUserInteractionEnabled = enabled
        v.writing = enabled
        v.setColors(context.environment)
        return v
    }

    func updateUIView(_ v: InkView, context: Context) {
        v.onStroke = onStroke
        v.brush = brush
        v.setColors(context.environment)
        if !enabled && v.isUserInteractionEnabled { v.cancelStroke() }
        v.isUserInteractionEnabled = enabled
        v.writing = enabled
    }
}

/// A UIControl so that a scroll view around it doesn't take a stroke drawn in it
/// (UIScrollView doesn't cancel a control's touches), backed up by refusing other views'
/// pans that start here, as UISlider does for its thumb, and by pausing the enclosing
/// scroll views' pans while a stroke is down. While it takes strokes, the scroll views
/// around it don't hold touches back (`delaysContentTouches`), so a stroke starts the
/// moment the finger lands rather than ~150 ms later.
final class InkView: UIControl {
    var onStroke: ((InkCanvas.Stroke) -> InkCanvas.Verdict)?
    var brush = InkGeometry.Brush.standard
    /// Taking strokes: the enclosing scroll views stop delaying touches meanwhile.
    var writing = false { didSet { if writing != oldValue { updateScrollHold() } } }
    private var inkColor = UIColor.systemTeal.cgColor
    private var wrongColor = UIColor.systemRed.cgColor

    private var samples: [InkGeometry.Sample] = []
    private var live: CAShapeLayer?
    private var touch: UITouch?
    /// The scroll views around the box while writing, and the pans paused for this stroke.
    private var holding: [UIScrollView] = []
    private var pausedPans: [UIGestureRecognizer] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isMultipleTouchEnabled = false
        isExclusiveTouch = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The theme's accent and "again" red, for the current light or dark mode.
    func setColors(_ env: EnvironmentValues) {
        inkColor = Color.accent.resolve(in: env).cgColor
        wrongColor = Color.again.resolve(in: env).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for l in layer.sublayers ?? [] { l.frame = bounds }
        CATransaction.commit()
    }

    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        if g.view !== self && g is UIPanGestureRecognizer { return false }
        return super.gestureRecognizerShouldBegin(g)
    }

    // MARK: the scroll views around the box

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { cancelStroke() }
        updateScrollHold()
    }

    /// Hold the enclosing scroll views' touch delay off while this box is on screen and
    /// taking strokes; give it back otherwise. Dragging outside the box still scrolls.
    private func updateScrollHold() {
        let want = writing && window != nil
        if want && holding.isEmpty {
            var found: [UIScrollView] = []
            var v = superview
            while let s = v {
                if let sv = s as? UIScrollView { found.append(sv) }
                v = s.superview
            }
            holding = found
            for s in holding { ScrollHold.take(s) }
        } else if !want && !holding.isEmpty {
            resumeScrolling()
            for s in holding { ScrollHold.release(s) }
            holding = []
        }
    }

    /// A stroke is down: the scroll views around it can't start scrolling under it.
    private func pauseScrolling() {
        resumeScrolling()
        for s in holding where s.panGestureRecognizer.isEnabled {
            s.panGestureRecognizer.isEnabled = false
            pausedPans.append(s.panGestureRecognizer)
        }
    }

    private func resumeScrolling() {
        for g in pausedPans { g.isEnabled = true }
        pausedPans = []
    }

    // MARK: touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touch == nil, let t = touches.first else { return }
        touch = t
        samples = [sample(t)]
        let l = CAShapeLayer()
        l.frame = bounds
        l.contentsScale = traitCollection.displayScale
        l.fillColor = inkColor
        l.fillRule = .nonZero
        l.strokeColor = nil
        l.lineWidth = 0
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.addSublayer(l)
        CATransaction.commit()
        live = l
        pauseScrolling()
        render(predicted: [], lifted: false)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        append(t, event)
        // where the finger is about to be, drawn for this frame only
        let predicted = (event?.predictedTouches(for: t) ?? []).map { sample($0) }
        render(predicted: predicted, lifted: false)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        append(t, event)
        // the lift: the end tapers
        render(predicted: [], lifted: true)
        resumeScrolling()
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        cancelStroke()
    }

    /// A stroke cut short (the system took the touch, or the box stopped taking strokes): it just goes.
    func cancelStroke() {
        touch = nil
        samples = []
        live?.removeFromSuperlayer()
        live = nil
        resumeScrolling()
    }

    private func sample(_ t: UITouch) -> InkGeometry.Sample {
        InkGeometry.Sample(point: t.preciseLocation(in: self), time: t.timestamp, force: pressure(t))
    }

    /// The pressure, 0...1, where the touch really reports one (a Pencil, or a 3D Touch
    /// screen); a finger on a current iPhone doesn't, and the brush goes by speed instead.
    private func pressure(_ t: UITouch) -> CGFloat? {
        guard t.maximumPossibleForce > 0, t.force > 0,
              t.type == .pencil || traitCollection.forceTouchCapability == .available else { return nil }
        return min(1, t.force / t.maximumPossibleForce * 2)
    }

    /// Every sample since the last event, not just the latest one.
    private func append(_ t: UITouch, _ event: UIEvent?) {
        var touches = event?.coalescedTouches(for: t) ?? []
        if touches.isEmpty { touches = [t] }
        for s in touches {
            let x = sample(s)
            if x.point != samples.last?.point { samples.append(x) }
        }
    }

    private func render(predicted: [InkGeometry.Sample], lifted: Bool) {
        guard let l = live else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        l.path = InkGeometry.brushPath(samples + predicted, brush: brush, lifted: lifted)
        CATransaction.commit()
    }

    private func finish() {
        let pts = samples.map(\.point)
        touch = nil
        samples = []
        guard let l = live else { return }
        live = nil
        let stroke = InkCanvas.Stroke(points: pts, outline: l.path ?? CGPath(rect: .zero, transform: nil))
        switch onStroke?(stroke) ?? .dropped {
        case .accepted:
            retire(l, after: 0, over: 0.3)
        case .dropped:
            retire(l, after: 0, over: 0.15)
        case .kept:
            retire(l, after: 0.05, over: 0.12)
        case .rejected:
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            l.fillColor = wrongColor
            CATransaction.commit()
            retire(l, after: 0.25, over: 0.25)
        }
    }

    /// Fade a finished stroke's ink out and drop its layer; a new stroke can start meanwhile.
    private func retire(_ l: CAShapeLayer, after delay: CFTimeInterval, over duration: CFTimeInterval) {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1.0
        fade.toValue = 0.0
        if delay > 0 { fade.beginTime = CACurrentMediaTime() + delay }
        fade.duration = duration
        fade.fillMode = .backwards
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        l.opacity = 0
        l.add(fade, forKey: "fade")
        CATransaction.commit()
        let gone: Double = delay + duration + 0.05
        DispatchQueue.main.asyncAfter(deadline: .now() + gone) { [weak l] in
            l?.removeFromSuperlayer()
        }
    }
}

/// Scroll views holding their touch delay off for the writing boxes inside them, counted
/// (a writing sheet has sixteen boxes in one scroll view); the last box to go gives back
/// the scroll view's own setting.
enum ScrollHold {
    private static var holds: [ObjectIdentifier: (count: Int, delays: Bool)] = [:]

    static func take(_ s: UIScrollView) {
        let id = ObjectIdentifier(s)
        if let h = holds[id] {
            holds[id] = (count: h.count + 1, delays: h.delays)
        } else {
            holds[id] = (count: 1, delays: s.delaysContentTouches)
            s.delaysContentTouches = false
        }
    }

    static func release(_ s: UIScrollView) {
        let id = ObjectIdentifier(s)
        guard let h = holds[id] else { return }
        if h.count <= 1 {
            holds[id] = nil
            s.delaysContentTouches = h.delays
        } else {
            holds[id] = (count: h.count - 1, delays: h.delays)
        }
    }
}
