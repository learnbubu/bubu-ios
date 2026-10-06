import CoreGraphics

// Made by tools/art/install_fx.py: where each of Bùbù's parts sits, on panda-idle's
// 420 x 643 canvas, and the burst pieces' shapes (height over width). Don't edit by hand.
enum RigArt {
    static let canvas = CGSize(width: 420, height: 643)
    static let rect: [String: CGRect] = [
        "rig2-pack-side": CGRect(x: 285.0, y: 262.0, width: 135.0, height: 204.3),
        "rig2-body": CGRect(x: 50.0, y: 258.0, width: 316.0, height: 384.7),
        "rig-arm-left-up": CGRect(x: -12.0, y: 168.0, width: 150.0, height: 173.2),
        "rig-arm-right-up": CGRect(x: 278.0, y: 168.0, width: 150.0, height: 173.2),
        "rig-arm-left-down": CGRect(x: -15.0, y: 311.0, width: 94.0, height: 198.8),
        "rig-arm-right-down": CGRect(x: 337.0, y: 311.0, width: 94.0, height: 198.8),
        "rig-head": CGRect(x: 32.0, y: 4.0, width: 352.0, height: 286.8),
        "rig-mouth-smile": CGRect(x: 174.0, y: 188.0, width: 68.0, height: 44.9),
        "rig-mouth-open": CGRect(x: 179.0, y: 212.0, width: 58.0, height: 37.7),
        "rig-glint-open-L": CGRect(x: 120.0, y: 166.0, width: 32.0, height: 16.9),
        "rig-glint-open-R": CGRect(x: 263.0, y: 167.0, width: 32.0, height: 16.9),
        "rig-glint-blink-L": CGRect(x: 120.0, y: 170.0, width: 32.0, height: 12.8),
        "rig-glint-blink-R": CGRect(x: 263.0, y: 171.0, width: 32.0, height: 12.8),
        "rig-glint-wow-L": CGRect(x: 103.0, y: 147.0, width: 51.0, height: 44.9),
        "rig-glint-wow-R": CGRect(x: 261.0, y: 147.0, width: 51.0, height: 44.9),
    ]
    static let aspect: [String: CGFloat] = [
        "fx-firecracker": 3.2558,
        "fx-firecracker-knot-nocord": 1.4857,
        "fx-pop-1": 0.9187,
        "fx-pop-2": 0.9962,
        "fx-pop-3": 1.1823,
        "fx-seal": 1.0029,
    ]
}
