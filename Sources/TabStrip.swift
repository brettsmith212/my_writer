import SwiftUI

/// MyWriter's own tab strip, in the top row beside the window buttons: quiet
/// text tabs that match the page. Shown only when a window has two or more tabs.
struct TabStrip: View {
    let window: () -> NSWindow?
    let export: () -> Void
    @ObservedObject private var model = TabsModel.shared

    private struct Tab: Identifiable {
        let window: NSWindow
        var id: ObjectIdentifier { ObjectIdentifier(window) }
        var title: String { window.title.isEmpty ? "Untitled" : window.title }
        var fileURL: URL? { (window.windowController?.document as? NSDocument)?.fileURL }
    }

    private var tabs: [Tab] {
        _ = model.tick
        guard let window = window(), let group = window.tabGroup, group.windows.count > 1 else { return [] }
        return group.windows.map(Tab.init)
    }

    var body: some View {
        let tabs = tabs
        if !tabs.isEmpty {
            HStack(spacing: 2) {
                ForEach(tabs) { tab in
                    TabItem(
                        title: tab.title,
                        fileURL: tab.fileURL,
                        selected: tab.window === window(),
                        window: { tab.window },
                        export: export,
                        select: { tab.window.makeKeyAndOrderFront(nil) },
                        close: { tab.window.performClose(nil) }
                    )
                }
                Button { WindowTabs.newTab() } label: {
                    Image(systemName: "plus").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(IconButtonStyle(size: 22))
                .pointingHandOnHover()
                .help("New tab (⌘T)")
            }
            .transition(.opacity)
        }
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
        .contentShape(Capsule())
        .onTapGesture {
            if selected { if fileURL != nil { showDetails.toggle() } } else { select() }
        }
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
