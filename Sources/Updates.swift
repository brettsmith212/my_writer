import SwiftUI
import Sparkle

/// Software updates via Sparkle. MyWriter checks its feed about once a day.
/// Instead of interrupting with a window, a found update shows as a quiet
/// "Update available" pill in the top bar; clicking it opens Sparkle's update
/// window (release notes, Install). With "Automatically download and install"
/// on, updates install on quit with no prompt.
@MainActor
final class Updates: NSObject, ObservableObject, SPUStandardUserDriverDelegate, SPUUpdaterDelegate {
    static let shared = Updates()

    /// The version waiting to be installed, when there is one.
    @Published private(set) var available: String?

    private(set) lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true, updaterDelegate: self, userDriverDelegate: self
    )

    var updater: SPUUpdater { controller.updater }

    func start() { _ = controller }

    func checkForUpdates() { updater.checkForUpdates() }

    #if DEBUG
    /// Debug builds can test against a local feed: MYWRITER_FEED=file:///…/appcast.xml
    nonisolated func feedURLString(for updater: SPUUpdater) -> String? {
        ProcessInfo.processInfo.environment["MYWRITER_FEED"]
    }

    nonisolated func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("MyWriter update check failed: %@", String(describing: error))
    }
    #endif

    // MARK: Gentle reminders

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Let Sparkle show its window only when you asked (Check for Updates…);
    /// for background checks, MyWriter shows its own pill instead.
    nonisolated func standardUserDriverShouldHandleShowingScheduledUpdate(_ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool) -> Bool {
        immediateFocus
    }

    nonisolated func standardUserDriverWillHandleShowingUpdate(_ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState) {
        let version = update.displayVersionString
        Task { @MainActor in
            if !handleShowingUpdate && !state.userInitiated { self.available = version }
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor in self.available = nil }
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        Task { @MainActor in self.available = nil }
    }
}

/// The quiet top-bar notice for a waiting update.
struct UpdatePill: View {
    @ObservedObject private var updates = Updates.shared

    var body: some View {
        if let version = updates.available {
            Button {
                updates.checkForUpdates()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 10.5))
                    Text("Update \(version)")
                }
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.accent.opacity(0.1)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pointingHandOnHover()
            .help("MyWriter \(version) is available. Click to see what's new and install.")
            .transition(.opacity)
        }
    }
}

/// Settings → Updates.
struct UpdatesSection: View {
    @State private var autoCheck = Updates.shared.updater.automaticallyChecksForUpdates
    @State private var autoInstall = Updates.shared.updater.automaticallyDownloadsUpdates

    var body: some View {
        Section("Updates") {
            Toggle("Check for updates automatically", isOn: $autoCheck)
                .onChange(of: autoCheck) { _, on in Updates.shared.updater.automaticallyChecksForUpdates = on }
            Toggle("Download and install updates automatically", isOn: $autoInstall)
                .onChange(of: autoInstall) { _, on in Updates.shared.updater.automaticallyDownloadsUpdates = on }
                .disabled(!autoCheck)
            LabeledContent {
                Button("Check Now") { Updates.shared.checkForUpdates() }
            } label: {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
            }
        }
    }
}
