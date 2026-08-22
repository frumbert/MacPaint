import SwiftUI

/// Windows 11 Paint dark-theme palette (Fluent).
enum Theme {
    static let bgWindow = Color(hex: 0x202020)
    static let bgToolbar = Color(hex: 0x2B2B2B)
    static let bgWorkspace = Color(hex: 0x414141)
    static let bgFlyout = Color(hex: 0x2C2C2C)
    static let bgControl = Color.white.opacity(0.06)
    static let bgControlHover = Color.white.opacity(0.09)
    static let bgControlActive = Color.white.opacity(0.04)

    static let strokeSubtle = Color.white.opacity(0.07)
    static let strokeControl = Color.white.opacity(0.093)
    static let strokeDivider = Color.white.opacity(0.085)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.786)
    static let textDisabled = Color.white.opacity(0.36)

    static let accent = Color(hex: 0x4CC2FF)
    static let accentDim = Color(hex: 0x0078D4)
    static let closeRed = Color(hex: 0xC42B1C)

    static let radius: CGFloat = 4
    static let radiusLarge: CGFloat = 8

    static let flyoutShadow = Color.black.opacity(0.4)

    /// Classic MS Paint 20-color palette.
    static let palette: [String] = [
        "#000000", "#7F7F7F", "#880015", "#ED1C24", "#FF7F27",
        "#FFF200", "#22B14C", "#00A2E8", "#3F48CC", "#A349A4",
        "#FFFFFF", "#C3C3C3", "#B97A57", "#FFAEC9", "#FFC90E",
        "#EFE4B0", "#B5E61D", "#99D9EA", "#7092BE", "#C8BFE7",
    ]

    static let paletteNames: [String: String] = [
        "#000000": "Black", "#7F7F7F": "Gray", "#880015": "Dark red", "#ED1C24": "Red",
        "#FF7F27": "Orange", "#FFF200": "Yellow", "#22B14C": "Green", "#00A2E8": "Turquoise",
        "#3F48CC": "Indigo", "#A349A4": "Purple", "#FFFFFF": "White", "#C3C3C3": "Light gray",
        "#B97A57": "Brown", "#FFAEC9": "Rose", "#FFC90E": "Gold", "#EFE4B0": "Light yellow",
        "#B5E61D": "Lime", "#99D9EA": "Light turquoise", "#7092BE": "Blue-gray", "#C8BFE7": "Lavender",
    ]
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// RGB color value used by the engine (doc-space drawing).
struct RGB: Equatable, Hashable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
        self.r = r; self.g = g; self.b = b
    }

    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        let v = UInt32(h, radix: 16) ?? 0
        self.init(UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF))
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }

    var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    var nsColor: NSColor {
        NSColor(srgbRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    var color: Color {
        Color(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: 1)
    }

    static let black = RGB(0, 0, 0)
    static let white = RGB(255, 255, 255)

    /// HSV conversion helpers for the Edit colors dialog.
    var hsv: (h: Double, s: Double, v: Double) {
        let rf = Double(r) / 255, gf = Double(g) / 255, bf = Double(b) / 255
        let mx = max(rf, gf, bf), mn = min(rf, gf, bf)
        let d = mx - mn
        var h: Double = 0
        if d > 0 {
            if mx == rf { h = ((gf - bf) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == gf { h = (bf - rf) / d + 2 }
            else { h = (rf - gf) / d + 4 }
            h *= 60
            if h < 0 { h += 360 }
        }
        return (h, mx == 0 ? 0 : d / mx, mx)
    }

    static func fromHSV(h: Double, s: Double, v: Double) -> RGB {
        let c = v * s
        let x = c * (1 - abs((h / 60).truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (rf, gf, bf): (Double, Double, Double)
        switch h {
        case ..<60: (rf, gf, bf) = (c, x, 0)
        case ..<120: (rf, gf, bf) = (x, c, 0)
        case ..<180: (rf, gf, bf) = (0, c, x)
        case ..<240: (rf, gf, bf) = (0, x, c)
        case ..<300: (rf, gf, bf) = (x, 0, c)
        default: (rf, gf, bf) = (c, 0, x)
        }
        return RGB(UInt8(((rf + m) * 255).rounded()), UInt8(((gf + m) * 255).rounded()), UInt8(((bf + m) * 255).rounded()))
    }
}
