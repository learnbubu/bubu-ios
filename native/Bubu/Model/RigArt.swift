import CoreGraphics

// Made by tools/art/install_fx.py: where each of Bùbù's parts sits, on panda-idle's
// 420 x 643 canvas, and the burst pieces' shapes (height over width). Don't edit by hand.
enum RigArt {
    static let canvas = CGSize(width: 420, height: 643)
    static let rect: [String: CGRect] = [
        "rig2-pack-side": CGRect(x: 285.0, y: 262.0, width: 135.0, height: 204.3),
        "rig2-body": CGRect(x: 50.0, y: 258.0, width: 316.0, height: 384.7),
        "rig4-torso-arms": CGRect(x: -4.0, y: 252.0, width: 424.0, height: 396.4),
        "rig4-torso-armL": CGRect(x: 0.0, y: 252.0, width: 419.0, height: 391.0),
        "rig5-head-sad": CGRect(x: 32.3, y: 3.5, width: 352.0, height: 286.8),
        "rig5-head-wince": CGRect(x: 32.3, y: 3.5, width: 352.0, height: 287.6),
        "rig5-head-grin": CGRect(x: 32.3, y: 2.7, width: 352.0, height: 286.8),
        "rig5-head-think": CGRect(x: 32.3, y: 3.5, width: 352.0, height: 286.8),
        "rig5-head-wow": CGRect(x: 32.3, y: 2.6, width: 352.9, height: 288.4),
        "rig5-head-proud": CGRect(x: 32.3, y: 2.7, width: 352.0, height: 286.8),
        "rig5-torso-cheer-fists": CGRect(x: 17.2, y: 252.4, width: 383.2, height: 388.9),
        "rig5-torso-scratch": CGRect(x: 3.9, y: 206.4, width: 416.4, height: 436.8),
        "rig5-torso-hips": CGRect(x: -21.0, y: 252.4, width: 458.9, height: 393.3),
        "rig5-fx-sweat": CGRect(x: 338.0, y: 70.0, width: 46.0, height: 65.6),
        "rig5-fx-sparkles": CGRect(x: -30.0, y: -20.0, width: 120.0, height: 144.4),
        "rig5-fx-question": CGRect(x: 345.0, y: -30.0, width: 70.0, height: 114.5),
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
