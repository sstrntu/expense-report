import SwiftUI

/// Floats a transient error message above the app for a few seconds, then
/// fades out. Driven by `RepositoryAppState.lastError`: anything non-nil
/// becomes a toast, which auto-clears after 4 seconds (or sooner if the user
/// taps it). This replaces the inline `infoBanner` pattern in places where
/// the error is a transient action result (not a persistent state).
///
/// Attach via `.errorToast(repositoryApp:)` in RootShell. Pages that want to
/// keep a banner instead can still read `repositoryApp.lastError` directly.
struct ErrorToast: ViewModifier {
    @ObservedObject var repositoryApp: RepositoryAppState
    @State private var visible: Bool = false
    @State private var displayedMessage: String? = nil

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = displayedMessage, visible {
                    toast(message)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(99)
                }
            }
            // React to lastError changes from any caller. Two patterns we
            // need to handle:
            // 1. lastError goes from nil → "message"  : show
            // 2. lastError goes from "A" → "B"       : replace
            // 3. lastError goes from "msg" → nil     : ignore (we manage
            //    our own auto-dismiss timer)
            .onChange(of: repositoryApp.lastError) { _, new in
                guard let new, !new.isEmpty else { return }
                displayedMessage = new
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    visible = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    await MainActor.run { dismiss() }
                }
            }
    }

    private func toast(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Tokens.rejected)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Tokens.rejected.opacity(0.25), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .onTapGesture { dismiss() }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { visible = false }
    }
}

extension View {
    func errorToast(repositoryApp: RepositoryAppState) -> some View {
        modifier(ErrorToast(repositoryApp: repositoryApp))
    }
}
