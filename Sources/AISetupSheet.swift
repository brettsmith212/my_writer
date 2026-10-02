import SwiftUI

/// Shown the first time an AI feature is used with nothing connected. Leads
/// with Sign in with ChatGPT (no API key needed); API keys are one step away.
struct AISetupSheet: View {
    @ObservedObject private var chatGPT = ChatGPTAuth.shared
    @Environment(\.dismiss) private var dismiss

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

            if let error = chatGPT.lastError {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(nsColor: Theme.cutStrike).opacity(1))
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 4) {
                Text("Have an Anthropic or OpenAI API key?")
                    .foregroundStyle(Color.inkSecondary)
                SettingsLink { Text("Use it in Settings") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accent)
                    .simultaneousGesture(TapGesture().onEnded { dismiss() })
            }
            .font(.system(size: 11.5))

            Button("Not now") {
                chatGPT.cancelSignIn()
                dismiss()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12))
            .foregroundStyle(Color.inkSecondary)
            .keyboardShortcut(.cancelAction)
        }
        .padding(28)
        .frame(width: 380)
        .background(Color.panel)
        .onChange(of: chatGPT.isConnected) { _, connected in
            if connected { dismiss() }
        }
    }
}
