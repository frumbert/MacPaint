import SwiftUI

// MARK: - Menu model

struct MenuItem: Identifiable {
    enum Kind { case action, divider, header }
    let id = UUID()
    var kind: Kind = .action
    var icon: String?          // SF Symbol name
    var iconView: AnyView?     // custom icon
    var label = ""
    var shortcut: String?
    var checked = false
    var disabled = false
    var submenu: [MenuItem]?
    var action: (() -> Void)?

    static func divider() -> MenuItem { MenuItem(kind: .divider) }
    static func header(_ t: String) -> MenuItem { MenuItem(kind: .header, label: t) }
}

struct ActiveMenu {
    var items: [MenuItem]
    var anchor: CGRect       // global coords
    var alignRight = false
}

enum DialogKind {
    case resizeSkew
    case imageProperties
    case editColors
    case about
    case unsaved
}

struct Toast: Identifiable {
    let id = UUID()
    let text: String
}

// MARK: - UI state

@MainActor
final class UIState: ObservableObject {
    @Published var activeMenu: ActiveMenu?
    @Published var activeSubmenu: ActiveMenu?
    @Published var dialog: DialogKind?
    @Published var toasts: [Toast] = []
    @Published var layersPanelOpen = false
    @Published var stickersPanelOpen = false
    @Published var textBarVisible = false

    var pendingUnsavedAction: (() -> Void)?

    /// Continuously captured button frames (global space), keyed by control id.
    var frames: [String: CGRect] = [:]

    func openMenu(_ items: [MenuItem], anchorId: String, alignRight: Bool = false) {
        guard let f = frames[anchorId] else { return }
        activeSubmenu = nil
        activeMenu = ActiveMenu(items: items, anchor: f, alignRight: alignRight)
    }

    func closeMenus() {
        activeMenu = nil
        activeSubmenu = nil
        // menu-item frames use per-open UUID keys; drop them so the dict
        // doesn't grow across a long session
        frames = frames.filter { !$0.key.hasPrefix("menuitem-") && !$0.key.hasPrefix("layer-menu-") }
    }

    func toast(_ text: String) {
        let t = Toast(text: text)
        toasts.append(t)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            self?.toasts.removeAll { $0.id == t.id }
        }
    }

    func confirmUnsaved(model: PaintModel, _ proceed: @escaping () -> Void) {
        if !model.dirty {
            proceed()
            return
        }
        pendingUnsavedAction = proceed
        dialog = .unsaved
    }
}

// MARK: - Frame capture

struct FrameReporter: ViewModifier {
    @EnvironmentObject var ui: UIState
    let id: String

    func body(content: Content) -> some View {
        content.background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { ui.frames[id] = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, f in ui.frames[id] = f }
            }
        )
    }
}

extension View {
    func reportFrame(_ id: String) -> some View {
        modifier(FrameReporter(id: id))
    }
}

// MARK: - Popup rendering

struct PopupLayer: View {
    @EnvironmentObject var ui: UIState

    var body: some View {
        GeometryReader { geo in
            if let menu = ui.activeMenu {
                // click-away catcher
                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { ui.closeMenus() }

                PopupMenuView(items: menu.items, level: 0)
                    .fixedSize()
                    .modifier(PopupPositioner(anchor: menu.anchor, container: geo.frame(in: .global), alignRight: menu.alignRight, side: false))

                if let sub = ui.activeSubmenu {
                    PopupMenuView(items: sub.items, level: 1)
                        .fixedSize()
                        .modifier(PopupPositioner(anchor: sub.anchor, container: geo.frame(in: .global), alignRight: false, side: true))
                }
            }
        }
    }
}

/// Positions a popup below (or beside, for submenus) its anchor, clamped to the window.
struct PopupPositioner: ViewModifier {
    let anchor: CGRect
    let container: CGRect
    let alignRight: Bool
    let side: Bool
    @State private var size: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { g in
                    Color.clear.onAppear { size = g.size }
                        .onChange(of: g.size) { _, s in size = s }
                }
            )
            .offset(x: clampedX, y: clampedY)
    }

    private var clampedX: CGFloat {
        var x: CGFloat
        if side {
            x = anchor.maxX - container.minX - 4
            if x + size.width > container.width - 8 {
                x = anchor.minX - container.minX - size.width + 4
            }
        } else {
            x = (alignRight ? anchor.maxX - size.width : anchor.minX) - container.minX
        }
        return min(max(8, x), max(8, container.width - size.width - 8))
    }

    private var clampedY: CGFloat {
        var y: CGFloat
        if side {
            y = anchor.minY - container.minY - 6
        } else {
            y = anchor.maxY - container.minY + 4
        }
        return min(max(8, y), max(8, container.height - size.height - 8))
    }
}

struct PopupMenuView: View {
    @EnvironmentObject var ui: UIState
    let items: [MenuItem]
    let level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(items) { item in
                switch item.kind {
                case .divider:
                    Rectangle()
                        .fill(Theme.strokeDivider)
                        .frame(height: 1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                case .header:
                    Text(item.label)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textDisabled)
                        .padding(.horizontal, 10)
                        .padding(.top, 6)
                        .padding(.bottom, 2)
                case .action:
                    PopupItemRow(item: item, level: level)
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: Theme.radiusLarge)
                .fill(Theme.bgFlyout)
                .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).stroke(Theme.strokeSubtle, lineWidth: 1))
                .shadow(color: Theme.flyoutShadow, radius: 12, y: 6)
        )
        .frame(minWidth: 140)
    }
}

struct PopupItemRow: View {
    @EnvironmentObject var ui: UIState
    let item: MenuItem
    let level: Int
    @State private var hovered = false

    var body: some View {
        Button {
            guard !item.disabled, item.submenu == nil else { return }
            ui.closeMenus()
            item.action?()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .opacity(item.checked ? 1 : 0)
                    .frame(width: 12)
                Group {
                    if let iv = item.iconView {
                        iv
                    } else if let icon = item.icon {
                        Image(systemName: icon)
                            .font(.system(size: 13))
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 18, height: 16)
                Text(item.label)
                    .font(.system(size: 13))
                    .lineLimit(1)
                Spacer(minLength: 20)
                if let sc = item.shortcut {
                    Text(sc)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textDisabled)
                }
                if item.submenu != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .foregroundStyle(item.disabled ? Theme.textDisabled : Theme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(hovered && !item.disabled ? Theme.bgControlHover : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .reportFrame("menuitem-\(item.id)")
        .onHover { h in
            hovered = h
            guard h else { return }
            if let sub = item.submenu, !item.disabled {
                if let f = ui.frames["menuitem-\(item.id)"] {
                    ui.activeSubmenu = ActiveMenu(items: sub, anchor: f)
                }
            } else if level == 0 {
                ui.activeSubmenu = nil
            }
        }
    }
}

// MARK: - Toasts

struct ToastLayer: View {
    @EnvironmentObject var ui: UIState

    var body: some View {
        VStack {
            Spacer()
            ForEach(ui.toasts) { t in
                Text(t.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: Theme.radiusLarge)
                            .fill(Theme.bgFlyout)
                            .overlay(RoundedRectangle(cornerRadius: Theme.radiusLarge).stroke(Theme.strokeSubtle, lineWidth: 1))
                            .shadow(color: Theme.flyoutShadow, radius: 10, y: 4)
                    )
            }
            .padding(.bottom, 8)
        }
        .padding(.bottom, 40)
        .allowsHitTesting(false)
        .animation(.easeOut(duration: 0.15), value: ui.toasts.count)
    }
}
