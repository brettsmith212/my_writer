import SwiftUI

/// Shown the first time an AI feature is used with nothing connected. Leads
/// with Sign in with ChatGPT (no API key needed); API keys are one step away.
struct AISetupSheet: View {
    @ObservedObject private var chatGPT = ChatGPTAuth.shared
    @Environment(\.dismiss) private var dismiss
    @State private var hoveringSignIn = false
    @State private var hoveringSettings = false
    @State private var hoveringLater = false

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Color.accent)
                .frame(width: 56, height: 56)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accent.opacity(0.12)))

            VStack(spacing: 6) {
                Text("Connect AI")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.ink)
                Text("AI alternatives and the Lab use your own AI account. Sign in with ChatGPT to use the plan you already have.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                chatGPT.signIn()
            } label: {
                HStack(spacing: 8) {
                    if chatGPT.signingIn { ProgressView().controlSize(.small) }
                    Text(chatGPT.signingIn ? "Finish signing in your browser…" : "Sign in with ChatGPT")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.accent)
            .controlSize(.large)
            .disabled(chatGPT.signingIn)
            .brightness(hoveringSignIn && !chatGPT.signingIn ? 0.06 : 0)
            .scaleEffect(hoveringSignIn && !chatGPT.signingIn ? 1.01 : 1)
            .onHover { hoveringSignIn = $0 }
            .animation(.easeOut(duration: 0.12), value: hoveringSignIn)
            .pointingHandOnHover()

            if let error = chatGPT.lastError {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(nsColor: Theme.cutStrike).opacity(1))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 4) {
                Text("Have an Anthropic or OpenAI API key?")
                    .foregroundStyle(Color.inkSecondary)
                SettingsLink { Text("Use it in Settings").underline(hoveringSettings) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accent)
                    .onHover { hoveringSettings = $0 }
                    .pointingHandOnHover()
                    .simultaneousGesture(TapGesture().onEnded {
                        SettingsView.showAITab()
                        dismiss()
                    })
            }
            .font(.system(size: 11.5))

            Button("Not now") {
                chatGPT.cancelSignIn()
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(hoveringLater ? Color.ink : Color.inkSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(Color.ink.opacity(hoveringLater ? 0.07 : 0)))
            .contentShape(Capsule())
            .onHover { hoveringLater = $0 }
            .animation(.easeOut(duration: 0.12), value: hoveringLater)
            .keyboardShortcut(.cancelAction)
            .pointingHandOnHover()
        }
        .padding(28)
        .frame(width: 380)
        .background(Color.panel)
        .onChange(of: chatGPT.isConnected) { _, connected in
            if connected { dismiss() }
        }
    }
}
