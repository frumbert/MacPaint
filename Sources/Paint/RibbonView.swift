import SwiftUI

// MARK: - Ribbon

struct RibbonView: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .center, spacing: 0) {
                SelectionGroup()
                sep
                ImageGroup()
                sep
                ToolsGroup()
                sep
                BrushesGroup()
                sep
                StickersGroup()
                sep
                ShapesGroup()
                sep
                ColorGroup()
                sep
                LayersGroup()
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .frame(height: 84)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .fill(Theme.bgToolbar)
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).stroke(Theme.strokeSubtle, lineWidth: 1))
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
        .background(Theme.bgWindow)
    }

    private var sep: some View {
        Rectangle()
            .fill(Theme.strokeDivider)
            .frame(width: 1, height: 58)
    }
}

// MARK: - Group scaffold

struct RibbonGroup<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 2)
            content()
            Spacer(minLength: 2)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 8)
        .frame(minWidth: 58)
    }
}

/// 44×44 tool button with optional dropdown chevron.
struct BigToolButton<Content: View>: View {
    var tip: String
    var active = false
    var chevronId: String?
    var chevronAction: (() -> Void)?
    let action: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(spacing: 0) {
            HoverButton(tip: tip, active: active, width: 44, height: 44, accentUnderline: true, action: action) {
                content().font(.system(size: 19))
            }
            if let cid = chevronId {
                HoverButton(tip: tip, width: 16, height: 44, action: { chevronAction?() }) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .reportFrame(cid)
            }
        }
    }
}

struct MiniButton: View {
    var tip: String
    var symbol: String
    var disabled = false
    var active = false
    let action: () -> Void

    var body: some View {
        HoverButton(tip: tip, disabled: disabled, active: active, width: 30, height: 22, accentUnderline: active, action: action) {
            Image(systemName: symbol).font(.system(size: 12))
        }
    }
}

// MARK: - Selection

struct SelectionGroup: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        RibbonGroup(label: "Selection") {
            BigToolButton(
                tip: "Select",
                active: model.tool == .select,
                chevronId: "sel-chevron",
                chevronAction: { ui.openMenu(selectionMenu(), anchorId: "sel-chevron") },
                action: { model.setTool(.select) }
            ) {
                ZStack {
                    Image(systemName: "square.dashed")
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 9))
                        .offset(x: 7, y: 8)
                }
            }
        }
    }

    private func selectionMenu() -> [MenuItem] {
        [
            .header("Selection tools"),
            MenuItem(icon: "square.dashed", label: "Rectangle", checked: model.selectMode == .rect, action: {
                model.selectMode = .rect
                model.setTool(.select)
            }),
            MenuItem(icon: "lasso", label: "Free-form", checked: model.selectMode == .free, action: {
                model.selectMode = .free
                model.setTool(.select)
            }),
            .divider(),
            MenuItem(icon: "rectangle.dashed", label: "Select all", shortcut: "Ctrl+A", action: { model.selectAll() }),
            MenuItem(icon: "rectangle.on.rectangle.slash", label: "Invert selection", disabled: model.selection == nil, action: {
                model.dropSelection() // keep any floating pixels
                model.setSelection(Selection(rect: CGRect(x: 0, y: 0, width: model.docWidth, height: model.docHeight), floating: nil, freePath: nil))
            }),
            MenuItem(icon: "trash", label: "Delete", shortcut: "Del", disabled: model.selection == nil, action: { model.deleteSelection() }),
            .divider(),
            MenuItem(icon: "checkerboard.rectangle", label: "Transparent selection", checked: model.transparentSelection, action: {
                model.transparentSelection.toggle()
            }),
        ]
    }
}

// MARK: - Image

struct ImageGroup: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        RibbonGroup(label: "Image") {
            Grid(horizontalSpacing: 2, verticalSpacing: 1) {
                GridRow {
                    MiniButton(tip: "Crop", symbol: "crop", disabled: model.selection == nil) { model.cropToSelection() }
                    MiniButton(tip: "Resize and skew (Ctrl+W)", symbol: "arrow.up.left.and.arrow.down.right") { ui.dialog = .resizeSkew }
                    MiniButton(tip: "Rotate left 90°", symbol: "rotate.left") { model.rotate(-90) }
                }
                GridRow {
                    MiniButton(tip: "Rotate right 90°", symbol: "rotate.right") { model.rotate(90) }
                    MiniButton(tip: "Flip horizontal", symbol: "arrow.left.and.right.righttriangle.left.righttriangle.right") { model.flip(horizontal: true) }
                    MiniButton(tip: "Flip vertical", symbol: "arrow.up.and.down.righttriangle.up.righttriangle.down") { model.flip(horizontal: false) }
                }
            }
        }
    }
}

// MARK: - Tools

struct ToolsGroup: View {
    @EnvironmentObject var model: PaintModel

    var body: some View {
        RibbonGroup(label: "Tools") {
            Grid(horizontalSpacing: 2, verticalSpacing: 1) {
                GridRow {
                    toolBtn("Pencil", "pencil", .pencil)
                    toolBtn("Fill with color", "drop.fill", .fill)
                    toolBtn("Text", "textformat", .text)
                }
                GridRow {
                    toolBtn("Eraser", "eraser", .eraser)
                    toolBtn("Color picker", "eyedropper", .picker)
                    toolBtn("Magnifier", "magnifyingglass", .magnifier)
                }
            }
        }
    }

    private func toolBtn(_ tip: String, _ symbol: String, _ tool: Tool) -> some View {
        MiniButton(tip: tip, symbol: symbol, active: model.tool == tool) {
            model.setTool(tool)
        }
    }
}

// MARK: - Brushes

struct BrushesGroup: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    static let brushIcons: [BrushType: String] = [
        .brush: "paintbrush",
        .calligraphy1: "paintbrush.pointed",
        .calligraphy2: "pencil.tip",
        .airbrush: "aqi.medium",
        .oil: "paintbrush.fill",
        .crayon: "pencil.and.outline",
        .marker: "highlighter",
        .pencil: "pencil",
        .watercolour: "drop",
    ]

    var body: some View {
        RibbonGroup(label: "Brushes") {
            BigToolButton(
                tip: "Brushes",
                active: model.tool == .brush,
                chevronId: "brush-chevron",
                chevronAction: { ui.openMenu(brushMenu(), anchorId: "brush-chevron") },
                action: { model.setTool(.brush) }
            ) {
                Image(systemName: "paintbrush")
            }
        }
    }

    private func brushMenu() -> [MenuItem] {
        BrushType.allCases.map { b in
            MenuItem(
                icon: Self.brushIcons[b] ?? "paintbrush",
                label: b.displayName,
                checked: model.tool == .brush && model.brushType == b,
                action: {
                    model.brushType = b
                    model.setTool(.brush)
                }
            )
        }
    }
}

// MARK: - Stickers

struct StickersGroup: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        RibbonGroup(label: "Stickers") {
            BigToolButton(
                tip: "Stickers",
                active: model.tool == .sticker,
                action: {
                    ui.layersPanelOpen = false
                    ui.stickersPanelOpen = true
                    model.setTool(.sticker)
                }
            ) {
                Image(systemName: "face.smiling")
            }
        }
    }
}

// MARK: - Shapes

struct ShapesGroup: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState
    @State private var scrollOffset = 0

    var body: some View {
        RibbonGroup(label: "Shapes") {
            HStack(spacing: 6) {
                HStack(spacing: 2) {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHGrid(rows: [GridItem(.fixed(26), spacing: 2), GridItem(.fixed(26), spacing: 2)], spacing: 2) {
                                ForEach(ShapeLibrary.all) { shape in
                                    ShapeButton(shape: shape)
                                        .id(shape.id)
                                }
                            }
                        }
                        .frame(width: 254, height: 54)
                        .scrollDisabled(false)
                        .overlay(alignment: .trailing) { EmptyView() }
                        .background(Color.clear)
                        .onChange(of: scrollOffset) { _, v in
                            let idx = min(max(0, v * 8), ShapeLibrary.all.count - 1)
                            withAnimation(.easeOut(duration: 0.15)) {
                                proxy.scrollTo(ShapeLibrary.all[idx].id, anchor: v == 0 ? .leading : .trailing)
                            }
                        }
                    }
                    VStack(spacing: 2) {
                        HoverButton(tip: "Scroll back", width: 16, height: 26, action: { scrollOffset = max(0, scrollOffset - 1) }) {
                            Image(systemName: "chevron.up").font(.system(size: 8, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                        }
                        HoverButton(tip: "Scroll forward", width: 16, height: 26, action: { scrollOffset = min(2, scrollOffset + 1) }) {
                            Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    dropButton(id: "outline-dd", tip: "Shape outline", symbol: "square", menu: styleMenu(outline: true))
                    dropButton(id: "fill-dd", tip: "Shape fill", symbol: "square.inset.filled", menu: styleMenu(outline: false))
                }
            }
        }
    }

    private func dropButton(id: String, tip: String, symbol: String, menu: [MenuItem]) -> some View {
        HoverButton(tip: tip, height: 26, action: { ui.openMenu(menu, anchorId: id) }) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 13))
                Image(systemName: "chevron.down").font(.system(size: 7, weight: .semibold)).foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, 4)
        }
        .reportFrame(id)
    }

    private func styleMenu(outline: Bool) -> [MenuItem] {
        FillStyle.allCases.map { s in
            MenuItem(
                icon: s == .none ? "slash.circle" : "square.fill",
                label: s.displayName(outline: outline),
                checked: (outline ? model.outlineStyle : model.fillStyle) == s,
                action: {
                    if outline { model.outlineStyle = s } else { model.fillStyle = s }
                }
            )
        }
    }
}

struct ShapeButton: View {
    @EnvironmentObject var model: PaintModel
    let shape: PaintShape
    @State private var hovered = false

    var body: some View {
        Button {
            model.shapeId = shape.id
            model.setTool(.shape)
        } label: {
            shape.iconPath(size: 17)
                .stroke(Theme.textPrimary, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .frame(width: 17, height: 17)
                .padding(4)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .fill(isActive ? Color.white.opacity(0.12) : (hovered ? Theme.bgControlHover : .clear))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(isActive ? Theme.accent : .clear, lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(shape.name)
    }

    private var isActive: Bool {
        model.tool == .shape && model.shapeId == shape.id
    }
}

// MARK: - Color

struct ColorGroup: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        RibbonGroup(label: "Color") {
            HStack(spacing: 10) {
                // wells
                ZStack(alignment: .topLeading) {
                    well(2)
                        .offset(x: 20, y: 22)
                    well(1)
                }
                .frame(width: 48, height: 50)

                // palette
                VStack(spacing: 3) {
                    paletteGrid(Theme.palette.prefix(10))
                    paletteGrid(Theme.palette.suffix(10))
                    customRow
                }

                Button {
                    ui.dialog = .editColors
                } label: {
                    Circle()
                        .fill(
                            AngularGradient(colors: [
                                Color(hex: 0xF6402C), Color(hex: 0xFFB300), Color(hex: 0xEEFF41),
                                Color(hex: 0x00C853), Color(hex: 0x00B0FF), Color(hex: 0xD500F9), Color(hex: 0xF6402C),
                            ], center: .center)
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.14), lineWidth: 1))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .help("Edit colors")
            }
        }
    }

    private func well(_ n: Int) -> some View {
        let color = n == 1 ? model.color1 : model.color2
        let selected = model.activeWell == n
        let outer: CGFloat = n == 1 ? 34 : 26
        let inner: CGFloat = n == 1 ? 26 : 20
        return Button {
            model.activeWell = n
        } label: {
            ZStack {
                Circle()
                    .stroke(selected ? Theme.accent : .clear, lineWidth: 2)
                    .frame(width: outer, height: outer)
                Circle()
                    .fill(color.color)
                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                    .frame(width: inner, height: inner)
            }
            .frame(width: outer, height: outer)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(n == 1 ? "Foreground color" : "Background color")
    }

    private func paletteGrid<S: Sequence>(_ colors: S) -> some View where S.Element == String {
        HStack(spacing: 3) {
            ForEach(Array(colors), id: \.self) { hex in
                SwatchButton(rgb: RGB(hex: hex), name: Theme.paletteNames[hex] ?? hex)
            }
        }
    }

    private var customRow: some View {
        HStack(spacing: 3) {
            ForEach(0..<10, id: \.self) { i in
                if i < model.customColors.count {
                    SwatchButton(rgb: model.customColors[i], name: model.customColors[i].hexString)
                } else {
                    Button { ui.dialog = .editColors } label: {
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                            .frame(width: 13, height: 13)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .frame(width: 15, height: 15)
                    .help("Custom color")
                }
            }
        }
    }
}

struct SwatchButton: View {
    @EnvironmentObject var model: PaintModel
    let rgb: RGB
    let name: String
    @State private var hovered = false

    var body: some View {
        Button {
            model.setColor(well: model.activeWell, rgb)
        } label: {
            Circle()
                .fill(rgb.color)
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .overlay(
                    Circle().stroke(isSelected ? Theme.accent : .clear, lineWidth: 2).padding(-2)
                )
                .frame(width: 15, height: 15)
                .scaleEffect(hovered ? 1.15 : 1)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help(name)
    }

    private var isSelected: Bool {
        (model.activeWell == 1 ? model.color1 : model.color2) == rgb
    }
}

// MARK: - Layers

struct LayersGroup: View {
    @EnvironmentObject var ui: UIState

    var body: some View {
        RibbonGroup(label: "Layers") {
            BigToolButton(
                tip: "Layers",
                active: ui.layersPanelOpen,
                action: {
                    ui.stickersPanelOpen = false
                    ui.layersPanelOpen.toggle()
                }
            ) {
                Image(systemName: "square.3.layers.3d.down.right")
            }
        }
    }
}
