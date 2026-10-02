import AppKit

/// Native window tabs: ⌘T opens a new document as a tab of the front window;
/// ⌘W (Close) closes the tab, and the window with its last tab.
@MainActor
enum WindowTabs {
    #if DEBUG
    /// Whether the last new tab arrived already in the tab group (for tests).
    static var debugArrivedTabbed: Bool?
    #endif

    static func newTab() {
        guard let front = NSApp.keyWindow ?? NSApp.mainWindow,
              let host = Optional(front.sheetParent ?? front), host.windowController?.document != nil else {
            // No document window in front (e.g. the welcome window): a plain new document.
            NSDocumentController.shared.newDocument(nil)
            return
        }
        let existing = Set(NSApp.windows.map(ObjectIdentifier.init))
        // The new window is handed to the tab group the moment it's about to
        // appear (see installTabbingHook), so it slides in as a tab and never
        // shows as a separate window first.
        pendingHost = host
        NSDocumentController.shared.newDocument(nil)
        adopt(into: host, excluding: existing, attempt: 0)
    }

    /// Moves a tab to a new position in its window's tabs, keeping the
    /// current tab selected.
    static func move(_ window: NSWindow, to index: Int) {
        guard let group = window.tabGroup, let from = group.windows.firstIndex(of: window), from != index else { return }
        let selected = group.selectedWindow
        group.removeWindow(window)
        group.insertWindow(window, at: max(0, min(index, group.windows.count)))
        if let selected, group.windows.contains(selected) { group.selectedWindow = selected }
        hideSystemTabBar(of: window)
        TabsModel.shared.refresh()
    }

    /// The window a new tab should join, while one is being created.
    static var pendingHost: NSWindow?

    /// Routes the next new document window into `pendingHost`'s tabs as it is
    /// first shown. Installed once at launch.
    static func installTabbingHook() {
        guard let original = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.order(_:relativeTo:))),
              let replacement = class_getInstanceMethod(NSWindow.self, #selector(NSWindow.mw_order(_:relativeTo:))) else { return }
        method_exchangeImplementations(original, replacement)
    }

    /// Waits for the new document's window, then tabs it into the host window.
    private static func adopt(into host: NSWindow, excluding existing: Set<ObjectIdentifier>, attempt: Int) {
        if let window = NSApp.windows.first(where: {
            !existing.contains(ObjectIdentifier($0)) && $0.windowController?.document != nil
        }) {
            pendingHost = nil
            #if DEBUG
            debugArrivedTabbed = window.tabGroup === host.tabGroup && (host.tabGroup?.windows.count ?? 0) > 1
            #endif
            if window.tabGroup !== host.tabGroup || host.tabGroup == nil {
                host.addTabbedWindow(window, ordered: .above)
            }
            window.makeKeyAndOrderFront(nil)
            hideSystemTabBar(of: window)
            TabsModel.shared.refresh()
            return
        }
        guard attempt < 40 else { pendingHost = nil; return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) { adopt(into: host, excluding: existing, attempt: attempt + 1) }
    }
}

extension WindowTabs {
    /// MyWriter draws its own tab strip, so the system's tab bar stays hidden.
    /// macOS keeps that bar showing whenever a window has two or more tabs, so
    /// hide its view in the window frame directly. If a future macOS renames
    /// it, the only effect is that the system bar shows again.
    static func hideSystemTabBar(of window: NSWindow?) {
        guard let frame = window?.contentView?.superview else { return }
        func hide(in view: NSView) {
            for sub in view.subviews {
                if String(describing: type(of: sub)).contains("TabBar") {
                    if !sub.isHidden { sub.isHidden = true }
                } else {
                    hide(in: sub)
                }
            }
        }
        hide(in: frame)
    }

    static func showAllTabs() {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        if let group = window.tabGroup { group.isOverviewVisible = true } else { window.toggleTabOverview(nil) }
    }

    static func selectNextTab(_ forward: Bool) {
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        if forward { window.selectNextTab(nil) } else { window.selectPreviousTab(nil) }
    }
}

/// Tells tab strips to redraw when windows open, close, change focus or are renamed.
@MainActor
final class TabsModel: ObservableObject {
    static let shared = TabsModel()
    @Published private(set) var tick = 0
    private var titleObservations: [NSKeyValueObservation] = []

    private init() {
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification, NSWindow.didResignMainNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { TabsModel.shared.refresh() }
            }
        }
        // A new document window that appears while a tab overview is open came
        // from the overview's +: make it a tab of that window, not a new window.
        center.addObserver(forName: NSWindow.didBecomeMainNotification, object: nil, queue: .main) { note in
            MainActor.assumeIsolated {
                guard let window = note.object as? NSWindow, window.windowController?.document != nil,
                      (window.tabGroup?.windows.count ?? 1) <= 1,
                      let host = NSApp.windows.first(where: { $0 !== window && $0.tabGroup?.isOverviewVisible == true })
                else { return }
                host.addTabbedWindow(window, ordered: .above)
                window.makeKeyAndOrderFront(nil)
                TabsModel.shared.refresh()
            }
        }
        // A closing window is still listed until the close finishes.
        center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { TabsModel.shared.refresh() } }
        }
    }

    func refresh() {
        let documentWindows = NSApp.windows.filter { $0.windowController?.document != nil }
        documentWindows.forEach { WindowTabs.hideSystemTabBar(of: $0) }
        titleObservations = documentWindows.map { window in
            window.observe(\.title) { _, _ in
                DispatchQueue.main.async { MainActor.assumeIsolated { TabsModel.shared.tick += 1 } }
            }
        }
        tick += 1
    }
}

extension NSWindow {
    /// Swapped with order(_:relativeTo:) by WindowTabs.installTabbingHook.
    @objc func mw_order(_ place: NSWindow.OrderingMode, relativeTo otherWindow: Int) {
        MainActor.assumeIsolated {
            if place != .out, let host = WindowTabs.pendingHost, host !== self,
               windowController?.document != nil, (tabGroup?.windows.count ?? 1) <= 1 {
                WindowTabs.pendingHost = nil
                host.addTabbedWindow(self, ordered: .above)
                makeKey()
                return
            }
            mw_order(place, relativeTo: otherWindow)  // the original
        }
    }
}
