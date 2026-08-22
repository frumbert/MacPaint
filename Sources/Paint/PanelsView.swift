import SwiftUI

// MARK: - Size slider (floating, left)

struct SizePanel: View {
    @EnvironmentObject var model: PaintModel

    var body: some View {
        if let key = model.currentSizeKey {
            VStack(spacing: 8) {
                Circle()
                    .fill(Theme.textPrimary)
                    .frame(width: dotSize(key), height: dotSize(key))
                    .frame(height: 22)
                FluentSlider(
                    value: Binding(
                        get: { Double(model.sizes[key] ?? 8) },
                        set: { model.sizes[key] = CGFloat($0) }
                    ),
                    range: 1...100,
                    step: 1,
                    vertical: true
                )
                .frame(height: 130)
                Image(systemName: "circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 28, height: 28)
                    .help("Size")
            }
            .padding(.vertical, 10)
            .frame(width: 40)
            .background(flyoutBackground)
            .padding(.leading, 14)
        }
    }

    private func dotSize(_ key: String) -> CGFloat {
        let v = model.sizes[key] ?? 8
        return max(3, min(20, v * 0.5 + 2))
    }
}

var flyoutBackground: some View {
    RoundedRectangle(cornerRadius: Theme.radiusLarge)
        .fill(Theme.bgFlyout)
        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).stroke(Theme.strokeSubtle, lineWidth: 1))
        .shadow(color: Theme.flyoutShadow, radius: 12, y: 6)
}

// MARK: - Layers panel

struct LayersPanel: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                HoverButton(tip: "Add layer", width: 30, height: 30, action: { model.addLayer() }) {
                    Image(systemName: "plus").font(.system(size: 13))
                }
                Spacer()
                Text("Layers")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                HoverButton(tip: "Close", width: 30, height: 30, action: { ui.layersPanelOpen = false }) {
                    Image(systemName: "xmark").font(.system(size: 12))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 8) {
                    // topmost layer first
                    ForEach(Array(model.layers.enumerated().reversed()), id: \.element.id) { idx, layer in
                        LayerRow(layer: layer, index: idx)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
            }

            Divider().overlay(Theme.strokeDivider)
            HStack(spacing: 8) {
                Text("Opacity")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                FluentSlider(
                    value: Binding(
                        get: { Double(model.activeLayer.opacity * 100) },
                        set: { model.setActiveLayerOpacity(CGFloat($0) / 100, commitNow: false) }
                    ),
                    range: 0...100, step: 1,
                    onEditingEnd: { model.commit() }
                )
                Text("\(Int(model.activeLayer.opacity * 100))%")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 210)
        .background(flyoutBackground)
        .padding(8)
    }
}

struct LayerRow: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState
    let layer: Layer
    let index: Int
    @State private var hovered = false

    var body: some View {
        // model.canvasRevision read keeps thumbnails fresh
        let _ = model.canvasRevision
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .fill(isActive ? Theme.accent.opacity(0.08) : (hovered ? Theme.bgControlHover : .clear))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge)
                        .stroke(isActive ? Theme.accent : .clear, lineWidth: 2)
                )
            VStack {
                thumb
                    .opacity(layer.visible ? 1 : 0.35)
                    .padding(6)
            }
            HStack {
                if hovered || !layer.visible {
                    smallOverlayButton(layer.visible ? "eye" : "eye.slash") {
                        model.setLayerVisible(index, !layer.visible)
                    }
                }
                Spacer()
                if hovered {
                    smallOverlayButton("ellipsis") {
                        ui.openMenu(layerMenu(), anchorId: "layer-menu-\(layer.id)")
                    }
                    .reportFrame("layer-menu-\(layer.id)")
                }
            }
            .padding(10)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.setActiveLayer(index)
        }
        .onHover { hovered = $0 }
    }

    private var isActive: Bool { model.activeLayerIndex == index }

    private var thumb: some View {
        ZStack {
            CheckerboardView(square: 6)
            if let img = layer.image() {
                Image(decorative: img, scale: 1)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(CGFloat(model.docWidth) / CGFloat(model.docHeight), contentMode: .fit)
            }
        }
        .frame(width: 150, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.strokeControl, lineWidth: 1))
    }

    private func smallOverlayButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textPrimary)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: Theme.radius).fill(Color(hex: 0x202020, alpha: 0.75)))
        }
        .buttonStyle(.plain)
    }

    private func layerMenu() -> [MenuItem] {
        [
            MenuItem(icon: "doc.on.doc", label: "Duplicate layer", action: { model.duplicateLayer(index) }),
            MenuItem(icon: "arrow.down.to.line", label: "Merge down", disabled: index == 0, action: { model.mergeDown(index) }),
            .divider(),
            MenuItem(icon: "arrow.up", label: "Move up", disabled: index == model.layers.count - 1, action: { model.moveLayer(index, dir: 1) }),
            MenuItem(icon: "arrow.down", label: "Move down", disabled: index == 0, action: { model.moveLayer(index, dir: -1) }),
            .divider(),
            MenuItem(icon: layer.visible ? "eye.slash" : "eye", label: layer.visible ? "Hide layer" : "Show layer", action: {
                model.setLayerVisible(index, !layer.visible)
            }),
            MenuItem(icon: "trash", label: "Delete layer", disabled: model.layers.count <= 1, action: { model.deleteLayer(index) }),
        ]
    }
}

struct CheckerboardView: View {
    var square: CGFloat = 8

    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0x3A3A3A)))
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row % 2 == 0 ? 0 : square
                while x < size.width {
                    ctx.fill(Path(CGRect(x: x, y: y, width: square, height: square)), with: .color(Color(hex: 0x4A4A4A)))
                    x += square * 2
                }
                y += square
                row += 1
            }
        }
    }
}

// MARK: - Stickers panel

struct StickersPanel: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    static let stickers = ["😀", "😂", "😍", "😎", "🥳", "😭", "🤔", "😴", "🐱", "🐶", "🦊", "🐼", "🦄", "🐸", "🌵", "🌸", "🌈", "⭐", "🔥", "❤️", "💙", "✨", "🎈", "🎉", "🍕", "🍩", "🍦", "⚽", "🚗", "✈️", "🎸", "🎮"]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Stickers")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, 4)
                Spacer()
                HoverButton(tip: "Close", width: 30, height: 30, action: {
                    ui.stickersPanelOpen = false
                    if model.tool == .sticker { model.setTool(.pencil) }
                }) {
                    Image(systemName: "xmark").font(.system(size: 12))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                    ForEach(Self.stickers, id: \.self) { s in
                        Button {
                            model.stickerChar = s
                            model.setTool(.sticker)
                        } label: {
                            Text(s)
                                .font(.system(size: 24))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: Theme.radius)
                                        .fill(model.stickerChar == s && model.tool == .sticker ? Theme.accent.opacity(0.22) : .clear)
                                )
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
        }
        .frame(width: 210)
        .background(flyoutBackground)
        .padding(8)
    }
}

// MARK: - Text options bar

struct TextOptionsBar: View {
    @EnvironmentObject var model: PaintModel

    static let fonts: [String] = {
        let preferred = ["Helvetica", "Arial", "Verdana", "Tahoma", "Trebuchet MS", "Times New Roman", "Georgia", "Courier New", "Menlo", "Impact", "Comic Sans MS"]
        let available = Set(NSFontManager.shared.availableFontFamilies)
        return preferred.filter { available.contains($0) }
    }()

    var body: some View {
        HStack(spacing: 4) {
            Picker("", selection: Binding(
                get: { model.textStyle.fontName },
                set: { model.textStyle.fontName = $0 }
            )) {
                ForEach(Self.fonts, id: \.self) { f in
                    Text(f).tag(f)
                }
            }
            .labelsHidden()
            .frame(width: 140)

            Stepper(
                value: Binding(
                    get: { model.textStyle.size },
                    set: { model.textStyle.size = min(288, max(8, $0)) }
                ),
                in: 8...288, step: 2
            ) {
                Text("\(Int(model.textStyle.size))")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 30)
            }

            divider
            styleToggle("bold", label: "B", isOn: model.textStyle.bold) { model.textStyle.bold.toggle() }
            styleToggle("italic", label: "I", isOn: model.textStyle.italic) { model.textStyle.italic.toggle() }
            styleToggle("underline", label: "U", isOn: model.textStyle.underline) { model.textStyle.underline.toggle() }
            styleToggle("strike", label: "S", isOn: model.textStyle.strike) { model.textStyle.strike.toggle() }
            divider
            alignBtn(.left, "text.alignleft")
            alignBtn(.center, "text.aligncenter")
            alignBtn(.right, "text.alignright")
            divider
            HoverButton(tip: "Opaque background", active: model.textStyle.opaqueBackground, width: 30, height: 28, action: {
                model.textStyle.opaqueBackground.toggle()
            }) {
                Image(systemName: "textformat.abc.dottedunderline").font(.system(size: 12))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(flyoutBackground)
    }

    private var divider: some View {
        Rectangle().fill(Theme.strokeDivider).frame(width: 1, height: 18).padding(.horizontal, 3)
    }

    private func styleToggle(_ id: String, label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        HoverButton(tip: id.capitalized, active: isOn, width: 30, height: 28, action: action) {
            Text(label)
                .font(.system(size: 13, weight: id == "bold" ? .bold : .regular))
                .italic(id == "italic")
                .underline(id == "underline")
                .strikethrough(id == "strike")
        }
    }

    private func alignBtn(_ a: NSTextAlignment, _ symbol: String) -> some View {
        HoverButton(tip: "Align", active: model.textStyle.align == a, width: 30, height: 28, action: {
            model.textStyle.align = a
        }) {
            Image(systemName: symbol).font(.system(size: 12))
        }
    }
}
