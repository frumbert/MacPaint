import SwiftUI

// MARK: - Dialog scaffold

struct DialogLayer: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        if let kind = ui.dialog {
            ZStack {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture { ui.dialog = nil }
                Group {
                    switch kind {
                    case .resizeSkew: ResizeSkewDialog()
                    case .imageProperties: ImagePropertiesDialog()
                    case .editColors: EditColorsDialog()
                    case .about: AboutDialog()
                    case .unsaved: UnsavedDialog()
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: Theme.radiusLarge)
                        .fill(Theme.bgFlyout)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).stroke(Theme.strokeSubtle, lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
                )
            }
            .transition(.opacity)
        }
    }
}

struct DialogButton: View {
    var label: String
    var primary = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: primary ? .semibold : .regular))
                .foregroundStyle(primary ? Color(hex: 0x003A5C) : Theme.textPrimary)
                .frame(minWidth: 84)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .fill(primary ? (hovered ? Color(hex: 0x47B5EE) : Theme.accent) : (hovered ? Theme.bgControlHover : Theme.bgControl))
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(primary ? .clear : Theme.strokeControl, lineWidth: 1))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}

struct DialogField: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 82, alignment: .leading)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(width: 90)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .fill(Theme.bgControl)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.strokeControl, lineWidth: 1))
                )
        }
    }
}

// MARK: - Resize and skew

struct ResizeSkewDialog: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    @State private var usePixels = false
    @State private var hText = "100"
    @State private var vText = "100"
    @State private var keepAspect = true
    @State private var skewH = "0"
    @State private var skewV = "0"

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Resize and skew")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("Resize").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 18) {
                    radio("Percentage", selected: !usePixels) { switchUnit(pixels: false) }
                    radio("Pixels", selected: usePixels) { switchUnit(pixels: true) }
                }
                DialogField(label: "Horizontal", text: Binding(
                    get: { hText },
                    set: { hText = $0; if keepAspect { syncAspect(fromH: true) } }
                ))
                DialogField(label: "Vertical", text: Binding(
                    get: { vText },
                    set: { vText = $0; if keepAspect { syncAspect(fromH: false) } }
                ))
                Toggle(isOn: $keepAspect) {
                    Text("Maintain aspect ratio").font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                }
                .toggleStyle(.checkbox)
                .padding(.top, 2)

                Text("Skew (Degrees)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.textSecondary).padding(.top, 8)
                DialogField(label: "Horizontal", text: $skewH)
                DialogField(label: "Vertical", text: $skewV)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 8) {
                Spacer()
                DialogButton(label: "OK", primary: true) { apply() }
                DialogButton(label: "Cancel") { ui.dialog = nil }
            }
            .padding(20)
        }
        .frame(width: 380)
    }

    private func radio(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Theme.accentDim : Theme.textSecondary)
                Text(label).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    private func switchUnit(pixels: Bool) {
        usePixels = pixels
        if pixels {
            hText = "\(model.docWidth)"
            vText = "\(model.docHeight)"
        } else {
            hText = "100"
            vText = "100"
        }
    }

    private func syncAspect(fromH: Bool) {
        guard keepAspect else { return }
        if usePixels {
            let w = Double(model.docWidth), h = Double(model.docHeight)
            if fromH, let v = Double(hText) {
                vText = "\(max(1, Int((v * h / w).rounded())))"
            } else if let v = Double(vText) {
                hText = "\(max(1, Int((v * w / h).rounded())))"
            }
        } else {
            if fromH { vText = hText } else { hText = vText }
        }
    }

    private func apply() {
        ui.dialog = nil
        let hv = Double(hText) ?? (usePixels ? Double(model.docWidth) : 100)
        let vv = Double(vText) ?? (usePixels ? Double(model.docHeight) : 100)
        // clamp before Int conversion — huge/garbage input must not trap
        func clampPx(_ v: Double) -> Int {
            guard v.isFinite else { return 1 }
            return Int(min(Double(PaintModel.maxCanvasDimension), max(1, v)))
        }
        let newW = clampPx(usePixels ? hv : Double(model.docWidth) * hv / 100)
        let newH = clampPx(usePixels ? vv : Double(model.docHeight) * vv / 100)
        if newW != model.docWidth || newH != model.docHeight {
            model.resizeCanvas(width: newW, height: newH, stretch: true)
        }
        let sh = min(89, max(-89, Double(skewH) ?? 0))
        let sv = min(89, max(-89, Double(skewV) ?? 0))
        if sh != 0 || sv != 0 {
            model.skew(hDeg: CGFloat(sh), vDeg: CGFloat(sv))
        }
    }
}

// MARK: - Image properties

struct ImagePropertiesDialog: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    @State private var wText = ""
    @State private var hText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Image properties")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                infoRow("Last saved", model.currentFileURL != nil ? "On disk" : "Not available")
                infoRow("Size on disk", model.fileSizeText.replacingOccurrences(of: "Size: ", with: ""))
                Text("Canvas size (pixels)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.top, 8)
                DialogField(label: "Width", text: $wText)
                DialogField(label: "Height", text: $hText)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 8) {
                DialogButton(label: "Default") {
                    wText = "\(PaintModel.defaultWidth)"
                    hText = "\(PaintModel.defaultHeight)"
                }
                Spacer()
                DialogButton(label: "OK", primary: true) {
                    ui.dialog = nil
                    if let w = Int(wText), let h = Int(hText), w >= 1, h >= 1,
                       w != model.docWidth || h != model.docHeight {
                        model.resizeCanvas(width: w, height: h, stretch: false)
                    }
                }
                DialogButton(label: "Cancel") { ui.dialog = nil }
            }
            .padding(20)
        }
        .frame(width: 380)
        .onAppear {
            wText = "\(model.docWidth)"
            hText = "\(model.docHeight)"
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(label).font(.system(size: 13)).foregroundStyle(Theme.textSecondary).frame(width: 82, alignment: .leading)
            Text(value.isEmpty ? "Unknown" : value).font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
        }
    }
}

// MARK: - Edit colors

struct EditColorsDialog: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    @State private var hue: Double = 210
    @State private var sat: Double = 1
    @State private var val: Double = 0.8
    @State private var hexText = ""
    @State private var rText = ""
    @State private var gText = ""
    @State private var bText = ""

    private var currentRGB: RGB { RGB.fromHSV(h: hue, s: sat, v: val) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Edit colors")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 16)

            HStack(alignment: .top, spacing: 16) {
                VStack(spacing: 10) {
                    svSquare
                    hueBar
                }
                VStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .fill(currentRGB.color)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.strokeControl, lineWidth: 1))
                        .frame(height: 44)
                    colorField("Hex", $hexText) { parseHex() }
                    colorField("Red", $rText) { parseRGBFields() }
                    colorField("Green", $gText) { parseRGBFields() }
                    colorField("Blue", $bText) { parseRGBFields() }
                }
                .frame(width: 150)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            HStack(spacing: 8) {
                Spacer()
                DialogButton(label: "OK", primary: true) {
                    applyPendingFieldEdits()
                    model.addCustomColor(currentRGB)
                    ui.dialog = nil
                }
                DialogButton(label: "Cancel") { ui.dialog = nil }
            }
            .padding(20)
        }
        .frame(width: 460)
        .onAppear {
            let c = model.activeColor
            let hsv = c.hsv
            hue = hsv.h; sat = hsv.s; val = hsv.v
            syncFields()
        }
    }

    private var svSquare: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Rectangle().fill(Color(hue: hue / 360, saturation: 1, brightness: 1))
                LinearGradient(colors: [.white, .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .background(Circle().stroke(.black.opacity(0.6), lineWidth: 3.5))
                    .frame(width: 14, height: 14)
                    .offset(x: CGFloat(sat) * geo.size.width - 7, y: CGFloat(1 - val) * geo.size.height - 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    sat = Double(min(max(0, g.location.x / geo.size.width), 1))
                    val = 1 - Double(min(max(0, g.location.y / geo.size.height), 1))
                    syncFields()
                }
            )
        }
        .frame(width: 232, height: 168)
    }

    private var hueBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                LinearGradient(
                    colors: (0...6).map { Color(hue: Double($0) / 6, saturation: 1, brightness: 1) },
                    startPoint: .leading, endPoint: .trailing
                )
                .clipShape(Capsule())
                Circle()
                    .stroke(.white, lineWidth: 2)
                    .background(Circle().stroke(.black.opacity(0.6), lineWidth: 3.5))
                    .frame(width: 14, height: 14)
                    .offset(x: CGFloat(hue / 360) * geo.size.width - 7)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { g in
                    hue = Double(min(max(0, g.location.x / geo.size.width), 1)) * 360
                    syncFields()
                }
            )
        }
        .frame(width: 232, height: 14)
    }

    private func colorField(_ label: String, _ text: Binding<String>, onCommit: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.system(size: 12)).foregroundStyle(Theme.textSecondary).frame(width: 40, alignment: .leading)
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .fill(Theme.bgControl)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.strokeControl, lineWidth: 1))
                )
                .onSubmit(onCommit)
        }
    }

    private func syncFields() {
        let c = currentRGB
        hexText = c.hexString
        rText = "\(c.r)"
        gText = "\(c.g)"
        bText = "\(c.b)"
    }

    private func parseHex() {
        var h = hexText.trimmingCharacters(in: .whitespaces)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, UInt32(h, radix: 16) != nil else { return }
        let c = RGB(hex: h)
        let hsv = c.hsv
        hue = hsv.h; sat = hsv.s; val = hsv.v
        syncFields()
    }

    private func parseRGBFields() {
        let r = UInt8(min(255, max(0, Int(rText) ?? 0)))
        let g = UInt8(min(255, max(0, Int(gText) ?? 0)))
        let b = UInt8(min(255, max(0, Int(bText) ?? 0)))
        let hsv = RGB(r, g, b).hsv
        hue = hsv.h; sat = hsv.s; val = hsv.v
        syncFields()
    }

    /// Values typed into the fields count on OK even without pressing Enter.
    private func applyPendingFieldEdits() {
        let cur = currentRGB
        let typedHex = hexText.trimmingCharacters(in: .whitespaces).uppercased()
        let normalized = typedHex.hasPrefix("#") ? typedHex : "#" + typedHex
        if normalized != cur.hexString, normalized.count == 7 {
            parseHex()
            return
        }
        if rText != "\(cur.r)" || gText != "\(cur.g)" || bText != "\(cur.b)" {
            parseRGBFields()
        }
    }
}

// MARK: - About

struct AboutDialog: View {
    @EnvironmentObject var ui: UIState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                PaintAppIcon().frame(width: 28, height: 28)
                Text("About Paint").font(.system(size: 18, weight: .semibold))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            VStack(alignment: .leading, spacing: 8) {
                Text("Paint — a native macOS replica of the Windows 11 Paint app.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Text("100% local. Built with Swift, SwiftUI and CoreGraphics.\nNot affiliated with Microsoft.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textDisabled)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            HStack {
                Spacer()
                DialogButton(label: "OK", primary: true) { ui.dialog = nil }
            }
            .padding(20)
        }
        .frame(width: 400)
    }
}

// MARK: - Unsaved changes

struct UnsavedDialog: View {
    @EnvironmentObject var model: PaintModel
    @EnvironmentObject var ui: UIState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Paint")
                .font(.system(size: 18, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.top, 16)
            Text("Do you want to save changes to \(model.fileName)?")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            HStack(spacing: 8) {
                Spacer()
                DialogButton(label: "Save", primary: true) {
                    let proceed = ui.pendingUnsavedAction
                    ui.dialog = nil
                    ui.pendingUnsavedAction = nil
                    // run the pending action only once the save actually completed
                    FileOps.save(model: model, ui: ui, onSaved: { proceed?() })
                }
                DialogButton(label: "Don't save") {
                    let proceed = ui.pendingUnsavedAction
                    ui.dialog = nil
                    ui.pendingUnsavedAction = nil
                    proceed?()
                }
                DialogButton(label: "Cancel") {
                    ui.dialog = nil
                    ui.pendingUnsavedAction = nil
                }
            }
            .padding(20)
        }
        .frame(width: 420)
    }
}
