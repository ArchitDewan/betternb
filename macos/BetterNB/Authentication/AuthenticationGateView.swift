import SwiftUI

struct AuthenticationGateView: View {
    @ObservedObject var session: AuthenticationSession
    @Environment(\.workspaceZoom) private var zoom

    var body: some View {
        Group {
            if session.state.unlocksWorkspace {
                WorkspaceShellView(accountID: session.state.account!.id)
                    .id(session.state.account!.id)
                    .environmentObject(session)
            } else {
                signInSurface
            }
        }
        .task {
            if session.state == .restoring {
                await session.restore()
            }
        }
    }

    private var signInSurface: some View {
        ZStack {
            AppTheme.canvas.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22 * zoom) {
                LemmaKnowledgeMotif()
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.bottom, 4 * zoom)
                VStack(alignment: .leading, spacing: 8 * zoom) {
                    Text("Lemma")
                        .zFont(14, weight: .semibold, zoom: zoom)
                        .foregroundStyle(LemmaColors.accent)

                    Text("Your study workspace,\nready when you are.")
                        .zFont(34, weight: .semibold, zoom: zoom)
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Sign in with Apple, Google, or an email code to continue.")
                        .zFont(15, zoom: zoom)
                        .foregroundStyle(AppTheme.secondaryText)
                }

                if let errorMessage = session.errorMessage {
                    Text(errorMessage)
                        .zFont(13, zoom: zoom)
                        .foregroundStyle(AppTheme.critical)
                        .accessibilityLabel("Sign-in error: \(errorMessage)")
                }

                Button {
                    Task { await session.signIn() }
                } label: {
                    HStack(spacing: 8 * zoom) {
                        if isBusy {
                            ProgressView().controlSize(.small)
                        }
                        Text(buttonTitle)
                            .zFont(14, weight: .semibold, zoom: zoom)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 42 * zoom)
                    .foregroundStyle(AppTheme.inverseText)
                    .background(
                        LemmaColors.accent,
                        in: RoundedRectangle(cornerRadius: 10 * zoom, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isBusy)
                .accessibilityHint("Opens secure sign-in in the system browser")
            }
            .padding(32 * zoom)
            .frame(width: 460 * zoom, alignment: .leading)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 18 * zoom))
            .overlay {
                RoundedRectangle(cornerRadius: 18 * zoom)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            }
        }
    }

    private var isBusy: Bool {
        switch session.state {
        case .restoring, .authenticating, .bootstrappingAccount: true
        default: false
        }
    }

    private var buttonTitle: String {
        switch session.state {
        case .restoring: "Restoring session…"
        case .authenticating: "Opening secure sign-in…"
        case .bootstrappingAccount: "Preparing your workspace…"
        default: "Continue securely"
        }
    }
}
