import SwiftUI

/// Shape geometry, normalized to a 100×100 box.
/// Used for both the ribbon gallery icons and canvas rasterization.
enum ShapeCmd {
    case move(CGFloat, CGFloat)
    case line(CGFloat, CGFloat)
    case curve(CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat) // c1x c1y c2x c2y x y
    case close
}

struct PaintShape: Identifiable {
    let id: String
    let name: String
    let isOpen: Bool // open path: no fill (line, curve)
    let cmds: [ShapeCmd]

    init(_ id: String, _ name: String, open: Bool = false, _ cmds: [ShapeCmd]) {
        self.id = id
        self.name = name
        self.isOpen = open
        self.cmds = cmds
    }

    /// CGPath scaled into the given rect (doc coordinates).
    func path(in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        let sx = { (u: CGFloat) in rect.origin.x + u / 100 * rect.width }
        let sy = { (v: CGFloat) in rect.origin.y + v / 100 * rect.height }
        for c in cmds {
            switch c {
            case let .move(x, y): p.move(to: CGPoint(x: sx(x), y: sy(y)))
            case let .line(x, y): p.addLine(to: CGPoint(x: sx(x), y: sy(y)))
            case let .curve(c1x, c1y, c2x, c2y, x, y):
                p.addCurve(to: CGPoint(x: sx(x), y: sy(y)),
                           control1: CGPoint(x: sx(c1x), y: sy(c1y)),
                           control2: CGPoint(x: sx(c2x), y: sy(c2y)))
            case .close: p.closeSubpath()
            }
        }
        return p
    }

    /// SwiftUI Path for gallery icons.
    func iconPath(size: CGFloat) -> Path {
        Path(path(in: CGRect(x: 0, y: 0, width: size, height: size)))
    }
}

enum ShapeLibrary {
    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> [ShapeCmd] {
        let kx = 0.5523 * rx, ky = 0.5523 * ry
        return [
            .move(cx + rx, cy),
            .curve(cx + rx, cy + ky, cx + kx, cy + ry, cx, cy + ry),
            .curve(cx - kx, cy + ry, cx - rx, cy + ky, cx - rx, cy),
            .curve(cx - rx, cy - ky, cx - kx, cy - ry, cx, cy - ry),
            .curve(cx + kx, cy - ry, cx + rx, cy - ky, cx + rx, cy),
            .close,
        ]
    }

    private static func poly(_ pts: [(CGFloat, CGFloat)]) -> [ShapeCmd] {
        var cmds: [ShapeCmd] = [.move(pts[0].0, pts[0].1)]
        for p in pts.dropFirst() { cmds.append(.line(p.0, p.1)) }
        cmds.append(.close)
        return cmds
    }

    static let all: [PaintShape] = [
        PaintShape("line", "Line", open: true, [.move(4, 96), .line(96, 4)]),
        PaintShape("curve", "Curve", open: true, [.move(4, 90), .curve(30, -20, 70, 120, 96, 10)]),
        PaintShape("oval", "Oval", ellipse(50, 50, 48, 48)),
        PaintShape("rectangle", "Rectangle", poly([(2, 2), (98, 2), (98, 98), (2, 98)])),
        PaintShape("rounded-rectangle", "Rounded rectangle", [
            .move(24, 2), .line(76, 2),
            .curve(88, 2, 98, 12, 98, 24), .line(98, 76),
            .curve(98, 88, 88, 98, 76, 98), .line(24, 98),
            .curve(12, 98, 2, 88, 2, 76), .line(2, 24),
            .curve(2, 12, 12, 2, 24, 2), .close,
        ]),
        PaintShape("polygon", "Polygon", poly([(38, 2), (98, 22), (78, 98), (8, 84), (2, 34)])),
        PaintShape("triangle", "Triangle", poly([(50, 2), (98, 98), (2, 98)])),
        PaintShape("right-triangle", "Right triangle", poly([(2, 2), (2, 98), (98, 98)])),
        PaintShape("diamond", "Diamond", poly([(50, 2), (98, 50), (50, 98), (2, 50)])),
        PaintShape("pentagon", "Pentagon", poly([(50, 2), (98, 37), (79, 98), (21, 98), (2, 37)])),
        PaintShape("hexagon", "Hexagon", poly([(27, 2), (73, 2), (98, 50), (73, 98), (27, 98), (2, 50)])),
        PaintShape("arrow-right", "Right arrow", poly([(2, 32), (58, 32), (58, 10), (98, 50), (58, 90), (58, 68), (2, 68)])),
        PaintShape("arrow-left", "Left arrow", poly([(98, 32), (42, 32), (42, 10), (2, 50), (42, 90), (42, 68), (98, 68)])),
        PaintShape("arrow-up", "Up arrow", poly([(32, 98), (32, 42), (10, 42), (50, 2), (90, 42), (68, 42), (68, 98)])),
        PaintShape("arrow-down", "Down arrow", poly([(32, 2), (32, 58), (10, 58), (50, 98), (90, 58), (68, 58), (68, 2)])),
        PaintShape("star-4", "Four-point star",
                   poly([(50, 2), (60.6, 39.4), (98, 50), (60.6, 60.6), (50, 98), (39.4, 60.6), (2, 50), (39.4, 39.4)])),
        PaintShape("star-5", "Five-point star", poly([
            (50, 2), (61.2, 35.6), (97.6, 35.6), (68.2, 56.6), (79.4, 90.4),
            (50, 69.6), (20.6, 90.4), (31.8, 56.6), (2.4, 35.6), (38.8, 35.6),
        ])),
        PaintShape("star-6", "Six-point star", poly([
            (50, 2), (63.5, 26.6), (93.3, 26), (77, 50), (93.3, 74), (63.5, 73.4),
            (50, 98), (36.5, 73.4), (6.7, 74), (23, 50), (6.7, 26), (36.5, 26.6),
        ])),
        PaintShape("callout-rounded", "Rounded rectangular callout", [
            .move(16, 2), .line(84, 2),
            .curve(92, 2, 98, 8, 98, 16), .line(98, 56),
            .curve(98, 64, 92, 70, 84, 70), .line(46, 70),
            .line(22, 98), .line(28, 70), .line(16, 70),
            .curve(8, 70, 2, 64, 2, 56), .line(2, 16),
            .curve(2, 8, 8, 2, 16, 2), .close,
        ]),
        PaintShape("callout-oval", "Oval callout", [
            .move(98, 36),
            .curve(98, 55, 76, 70, 50, 70),
            .curve(46, 70, 42, 69.6, 38, 69),
            .line(18, 98), .line(26, 66),
            .curve(11, 60, 2, 49, 2, 36),
            .curve(2, 17, 24, 2, 50, 2),
            .curve(76, 2, 98, 17, 98, 36),
            .close,
        ]),
        PaintShape("callout-cloud", "Cloud callout", [
            .move(30, 26),
            .curve(32, 12, 46, 6, 56, 12),
            .curve(62, 2, 80, 4, 84, 16),
            .curve(96, 16, 102, 30, 94, 38),
            .curve(102, 48, 92, 60, 80, 57),
            .curve(76, 66, 62, 68, 55, 61),
            .curve(48, 68, 34, 66, 31, 56),
            .curve(18, 58, 10, 46, 17, 37),
            .curve(9, 28, 18, 16, 30, 26),
            .close,
        ] + ellipse(26, 76, 7, 5) + ellipse(14, 90, 4.5, 3.5)),
        PaintShape("heart", "Heart", [
            .move(50, 91),
            .curve(20, 65, 4, 47, 4, 29),
            .curve(4, 13, 15, 4, 28, 4),
            .curve(38, 4, 46, 10, 50, 20),
            .curve(54, 10, 62, 4, 72, 4),
            .curve(85, 4, 96, 13, 96, 29),
            .curve(96, 47, 80, 65, 50, 91),
            .close,
        ]),
        PaintShape("lightning", "Lightning", poly([(62, 2), (18, 56), (40, 56), (30, 98), (84, 38), (56, 38)])),
    ]

    static func byId(_ id: String) -> PaintShape {
        all.first { $0.id == id } ?? all[3]
    }
}
