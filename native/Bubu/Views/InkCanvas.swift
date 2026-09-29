import SwiftUI
import UIKit

/// The pen. A UIKit surface draws the stroke under the finger itself, from every coalesced
/// touch plus the predicted ones, as smooth curves (`InkGeometry`), so the ink keeps up at
/// 120 Hz without SwiftUI re-rendering on each sample. Only the finished stroke goes back to
/// SwiftUI, whose answer says how the ink leaves.
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

    var enabled = true
    var lineWidth: CGFloat = 7
    /// The finished stroke's points, in the view's coordinates.
    var onStroke: ([CGPoint]) -> Verdict

    func makeUIView(context: Context) -> InkView {
        let v = InkView(frame: .zero)
        v.onStroke = onStroke
        v.lineWidth = lineWidth
        v.isUserInteractionEnabled = enabled
        v.setColors(context.environment)
        return v
    }

    func updateUIView(_ v: InkView, context: Context) {
        v.onStroke = onStroke
        v.lineWidth = lineWidth
        v.setColors(context.environment)
        if !enabled && v.isUserInteractionEnabled { v.cancelStroke() }
        v.isUserInteractionEnabled = enabled
    }
}

/// A UIControl so that a scroll view around it doesn't take a stroke drawn in it
/// (UIScrollView doesn't cancel a control's touches), backed up by refusing other views'
/// pans that start here, as UISlider does for its thumb.
final class InkView: UIControl {
    var onStroke: (([CGPoint]) -> InkCanvas.Verdict)?
    var lineWidth: CGFloat = 7
    private var inkColor = UIColor.systemTeal.cgColor
    private var wrongColor = UIColor.systemRed.cgColor

    private var points: [CGPoint] = []
    private var live: CAShapeLayer?
    private var touch: UITouch?

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

    // MARK: touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard touch == nil, let t = touches.first else { return }
        touch = t
        points = [t.preciseLocation(in: self)]
        let l = CAShapeLayer()
        l.frame = bounds
        l.contentsScale = traitCollection.displayScale
        l.fillColor = nil
        l.strokeColor = inkColor
        l.lineWidth = lineWidth
        l.lineCap = .round
        l.lineJoin = .round
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.addSublayer(l)
        CATransaction.commit()
        live = l
        render(predicted: [])
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        append(t, event)
        // where the finger is about to be, drawn for this frame only
        let predicted = (event?.predictedTouches(for: t) ?? []).map { $0.preciseLocation(in: self) }
        render(predicted: predicted)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        append(t, event)
        render(predicted: [])
        finish()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touch, touches.contains(t) else { return }
        cancelStroke()
    }

    /// A stroke cut short (the system took the touch, or the box stopped taking strokes): it just goes.
    func cancelStroke() {
        touch = nil
        points = []
        live?.removeFromSuperlayer()
        live = nil
    }

    /// Every sample since the last event, not just the latest one.
    private func append(_ t: UITouch, _ event: UIEvent?) {
        var samples = event?.coalescedTouches(for: t) ?? []
        if samples.isEmpty { samples = [t] }
        for s in samples {
            let p = s.preciseLocation(in: self)
            if p != points.last { points.append(p) }
        }
    }

    private func render(predicted: [CGPoint]) {
        guard let l = live else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        l.path = InkGeometry.path(points + predicted)
        CATransaction.commit()
    }

    private func finish() {
        let pts = points
        touch = nil
        points = []
        guard let l = live else { return }
        live = nil
        switch onStroke?(pts) ?? .dropped {
        case .accepted:
            retire(l, after: 0, over: 0.3)
        case .dropped:
            retire(l, after: 0, over: 0.15)
        case .kept:
            retire(l, after: 0.05, over: 0.12)
        case .rejected:
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            l.strokeColor = wrongColor
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
