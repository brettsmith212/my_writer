import SwiftUI

/// MyWriter's own tab strip, in the top row beside the window buttons: quiet
/// text tabs that match the page. Shown only when a window has two or more tabs.
/// Drag a tab sideways to reorder; the others slide out of its way.
struct TabStrip: View {
    let window: () -> NSWindow?
    let export: () -> Void
    @ObservedObject private var model = TabsModel.shared
    @State private var frames: [ObjectIdentifier: CGRect] = [:]
    @State private var drag: Drag?

    private static let spacing: CGFloat = 2

    private struct Drag {
        let id: ObjectIdentifier
        let from: Int
        let start: [ObjectIdentifier: CGRect]
        let order: [ObjectIdentifier]
        var dx: CGFloat = 0
        var to: Int
        /// Set as the tab settles into its new place, after release.
        var settling = false
    }

    private var tabs: [TabInfo] {
        _ = model.tick
        guard let window = window(), let group = window.tabGroup, group.windows.count > 1 else { return [] }
        return group.windows.map(TabInfo.init)
    }

    var body: some View {
        let tabs = tabs
        if !tabs.isEmpty {
            HStack(spacing: Self.spacing) {
                ForEach(Array(tabs.enumerated()), id: \.element.id) { index, tab in
                    TabItem(
                        title: tab.title,
                        fileURL: tab.fileURL,
                        selected: tab.window === window(),
                        window: { tab.window },
                        export: export,
                        select: { WindowTabs.select(tab.window) },
                        close: { tab.window.performClose(nil) },
                        dragChanged: { dragChanged(tab.id, index: index, dx: $0.width, tabs: tabs) },
                        dragEnded: { dragEnded(tabs: tabs) }
                    )
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: TabFramesKey.self, value: [tab.id: proxy.frame(in: .named("tabstrip"))])
                    })
                    .offset(x: offset(for: tab.id, index: index))
                    .zIndex(drag?.id == tab.id ? 1 : 0)
                }
                Button { WindowTabs.newTab() } label: {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle(size: 22))
                .pointingHandOnHover()
                .help("New tab (⌘T)")
            }
            .coordinateSpace(name: "tabstrip")
            .onPreferenceChange(TabFramesKey.self) { frames = $0 }
            .transition(.opacity)
        }
    }

    /// Where a tab is drawn while one is being dragged: the dragged tab
    /// follows the pointer; the tabs it has passed shift over by its width.
    private func offset(for id: ObjectIdentifier, index: Int) -> CGFloat {
        guard let drag, let dragged = drag.start[drag.id] else { return 0 }
        if id == drag.id {
            guard drag.settling else { return drag.dx }
            return slotX(drag) - dragged.minX
        }
        let shift = dragged.width + Self.spacing
        if drag.from < drag.to, index > drag.from, index <= drag.to { return -shift }
        if drag.to < drag.from, index >= drag.to, index < drag.from { return shift }
        return 0
    }

    /// Where the dragged tab's left edge lands at its new position.
    private func slotX(_ drag: Drag) -> CGFloat {
        guard let dragged = drag.start[drag.id] else { return 0 }
        let target = drag.start[drag.order[drag.to]] ?? dragged
        return drag.to > drag.from ? target.maxX - dragged.width : target.minX
    }

    private func dragChanged(_ id: ObjectIdentifier, index: Int, dx: CGFloat, tabs: [TabInfo]) {
        if drag == nil || drag?.id != id {
            drag = Drag(id: id, from: index, start: frames, order: tabs.map(\.id), to: index)
        }
        guard var current = drag, !current.settling, let dragged = current.start[id] else { return }
        current.dx = dx
        // The new position: how many of the other tabs' centers the dragged
        // tab's center has passed.
        let center = dragged.midX + dx
        let others = current.order.filter { $0 != id }
        let to = others.filter { (current.start[$0]?.midX ?? 0) < center }.count
        if to != current.to {
            current.to = to
            withAnimation(.easeOut(duration: 0.16)) { drag = current }
        } else {
            drag = current
        }
    }

    private func dragEnded(tabs: [TabInfo]) {
        guard var current = drag else { return }
        let window = tabs.first { $0.id == current.id }?.window
        current.settling = true
        withAnimation(.easeOut(duration: 0.14)) { drag = current }
        // Once settled, make the move for real, without animation: the strip
        // is already drawn in its new order.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let window, current.to != current.from { WindowTabs.move(window, to: current.to) }
                drag = nil
            }
        }
    }
}

struct TabInfo: Identifiable {
    let window: NSWindow
    var id: ObjectIdentifier { ObjectIdentifier(window) }
    var title: String { window.title.isEmpty ? "Untitled" : window.title }
    var fileURL: URL? { (window.windowController?.document as? NSDocument)?.fileURL }
}

struct TabFramesKey: PreferenceKey {
    static let defaultValue: [ObjectIdentifier: CGRect] = [:]
    static func reduce(value: inout [ObjectIdentifier: CGRect], nextValue: () -> [ObjectIdentifier: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

private struct TabItem: View {
    let title: String
    let fileURL: URL?
    let selected: Bool
    let window: () -> NSWindow?
    let export: () -> Void
    let select: () -> Void
    let close: () -> Void
    let dragChanged: (CGSize) -> Void
    let dragEnded: () -> Void
    @State private var hovering = false
    @State private var showDetails = false

    /// Long names keep their start and end: "The Case for Wri…Slowly.md".
    static func shortened(_ title: String, limit: Int = 28) -> String {
        guard title.count > limit else { return title }
        let head = title.prefix(limit / 2)
        let tail = title.suffix(limit / 2 - 1)
        return "\(head)…\(tail)"
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(Self.shortened(title))
                .font(.system(size: 11.5, weight: selected ? .semibold : .medium))
                .foregroundStyle(selected ? Color.ink : Color.inkSecondary)
                .lineLimit(1)
                .fixedSize()
                .allowsHitTesting(false)
            Button(action: close) {
                Image(systemName: "xmark").font(.system(size: 7.5, weight: .bold))
            }
            .buttonStyle(IconButtonStyle(size: 15))
            .opacity(hovering ? 1 : 0)
            .help("Close tab (⌘W)")
        }
        .padding(.leading, 11)
        .padding(.trailing, 4)
        .frame(height: 24)
        .background(
            Capsule().fill(selected ? Color.ink.opacity(0.07) : hovering ? Color.ink.opacity(0.04) : .clear)
        )
        // Clicks and drags are read by an AppKit view: in the title bar,
        // SwiftUI's own drag would move the whole window instead.
        .background(
            MouseArea(
                click: { if selected { if fileURL != nil { showDetails.toggle() } } else { select() } },
                dragChanged: dragChanged,
                dragEnded: dragEnded
            )
            .clipShape(Capsule())
        )
        .onHover { hovering = $0 }
        .pointingHandOnHover()
        .help(selected ? (fileURL == nil ? title : "Show where this file lives") : title)
        .popover(isPresented: $showDetails, arrowEdge: .bottom) {
            if let fileURL {
                FileDetails(fileURL: fileURL, window: window, close: { showDetails = false }, export: export)
            }
        }
        .animation(.easeOut(duration: 0.12), value: hovering)
    }
}

/// Reads clicks and drags with AppKit, and never lets a drag move the window.
/// A press that moves more than a few points is a drag; otherwise a click.
struct MouseArea: NSViewRepresentable {
    var click: () -> Void
    var dragChanged: (CGSize) -> Void
    var dragEnded: () -> Void

    func makeNSView(context: Context) -> Surface { Surface() }

    func updateNSView(_ view: Surface, context: Context) {
        view.click = click
        view.dragChanged = dragChanged
        view.dragEnded = dragEnded
    }

    final class Surface: NSView {
        var click: () -> Void = {}
        var dragChanged: (CGSize) -> Void = { _ in }
        var dragEnded: () -> Void = {}
        private var start: NSPoint?
        private var dragging = false

        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            start = event.locationInWindow
            dragging = false
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start else { return }
            // Window coordinates run bottom-up; SwiftUI's run top-down.
            let delta = CGSize(width: event.locationInWindow.x - start.x, height: start.y - event.locationInWindow.y)
            if !dragging, hypot(delta.width, delta.height) > 4 { dragging = true }
            if dragging { dragChanged(delta) }
        }

        override func mouseUp(with event: NSEvent) {
            if dragging { dragEnded() } else if start != nil { click() }
            start = nil
            dragging = false
        }
    }
}
