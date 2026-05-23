import SwiftUI
import AuthenticationServices

/// Pair of social sign-in buttons (Google + Apple) for the auth and welcome
/// screens. Apple's official `SignInWithAppleButton` handles its own styling
/// (mandated by Apple's guidelines), so we just style the Google one to match.
///
/// Action closures here are deliberately fire-and-forget — the caller wires
/// them to async tasks on RepositoryAppState that do the real work and then
/// drive AppState forward.
struct SocialAuthButtons: View {
    let onGoogle: () -> Void
    let onApple: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onGoogle) {
                HStack(spacing: 12) {
                    GoogleGlyph()
                        .frame(width: 18, height: 18)
                    Text(tr("auth.continue_with_google"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                }
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Apple's official button: required style + minimum 44pt tap area.
            // We don't put the asynchronous bridging here — the parent's onApple
            // closure runs after the Apple flow completes (the closure itself
            // invokes the coordinator).
            SignInWithAppleButton(.continue) { _ in
                // The system returns a request here but we use our own
                // AppleAuthCoordinator (managed by the parent) to get the
                // nonce + identityToken pair. The system's onCompletion is
                // also intercepted by that coordinator. So this initiator
                // just forwards.
                onApple()
            } onCompletion: { _ in
                // No-op: AppleAuthCoordinator handles the real completion.
                // SwiftUI's SignInWithAppleButton fires onRequest, then
                // performs the request itself; we bypass that path entirely
                // by calling our own controller in `onApple`.
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

/// Vector-ish G glyph. Drawing it ourselves avoids shipping the Google logo
/// asset and the brand-guidelines hassle that comes with it. Four arcs +
/// a single horizontal bar approximating the trademark mark; close enough
/// to read as "Google" without using the real PNG.
private struct GoogleGlyph: View {
    var body: some View {
        ZStack {
            // Outer disc clipped to a ring
            Circle().stroke(Color.primary.opacity(0.5), lineWidth: 2.4)
            // Horizontal "G" bar from the centre out the right side
            Path { p in
                p.move(to: CGPoint(x: 9, y: 10))
                p.addLine(to: CGPoint(x: 17.5, y: 10))
            }
            .stroke(Color.primary.opacity(0.7), lineWidth: 2.4)
            // Inner notch — short vertical going down from the bar
            Path { p in
                p.move(to: CGPoint(x: 16.5, y: 10))
                p.addLine(to: CGPoint(x: 16.5, y: 14))
            }
            .stroke(Color.primary.opacity(0.7), lineWidth: 2.4)
        }
    }
}
