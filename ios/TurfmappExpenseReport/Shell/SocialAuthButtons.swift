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
                        .frame(width: 20, height: 20)
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

/// Google "G" mark in its trademark four colors. Drawn programmatically with
/// SwiftUI's Circle().trim(...) — no asset shipped, scales cleanly with any
/// frame size. Colours match Google's identity guidelines:
///   Blue   #4285F4
///   Red    #EA4335
///   Yellow #FBBC05
///   Green  #34A853
///
/// Layout: a circular ring split into four arc segments with a notch on the
/// right side where the horizontal "G" bar enters. Going clockwise from 12
/// o'clock, the arc trim percentages map to the reference logo as follows:
///   0.000 – 0.250   BLUE   top-right
///   0.250 – 0.330   (gap — the bar enters here)
///   0.330 – 0.500   GREEN  bottom-right
///   0.500 – 0.750   YELLOW bottom-left
///   0.750 – 1.000   RED    top-left
private struct GoogleGlyph: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let lineWidth = size * 0.22
            let radius = (size - lineWidth) / 2
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)

            ZStack {
                arc(0.000, 0.250, color: blue,   radius: radius, lineWidth: lineWidth, center: center)
                arc(0.330, 0.500, color: green,  radius: radius, lineWidth: lineWidth, center: center)
                arc(0.500, 0.750, color: yellow, radius: radius, lineWidth: lineWidth, center: center)
                arc(0.750, 1.000, color: red,    radius: radius, lineWidth: lineWidth, center: center)

                // Horizontal blue bar entering through the gap. Starts at the
                // centre of the ring and extends out to where the inner edge
                // of the arc would be at ~3:30 position.
                Capsule()
                    .fill(blue)
                    .frame(width: radius * 0.95, height: lineWidth)
                    .position(x: center.x + radius * 0.42, y: center.y + lineWidth * 0.55)
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private let blue   = Color(red: 66/255,  green: 133/255, blue: 244/255)
    private let red    = Color(red: 234/255, green: 67/255,  blue: 53/255)
    private let yellow = Color(red: 251/255, green: 188/255, blue: 5/255)
    private let green  = Color(red: 52/255,  green: 168/255, blue: 83/255)

    private func arc(_ start: CGFloat, _ end: CGFloat,
                     color: Color,
                     radius: CGFloat,
                     lineWidth: CGFloat,
                     center: CGPoint) -> some View {
        Circle()
            .trim(from: start, to: end)
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .rotationEffect(.degrees(-90))
            .frame(width: radius * 2, height: radius * 2)
            .position(x: center.x, y: center.y)
    }
}
