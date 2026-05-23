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
    /// Drives the label on both buttons — "Sign in with X" vs "Sign up with X"
    /// vs the generic "Continue with X". Welcome / fresh-auth contexts pass
    /// `.continue` while AuthView passes the active mode so the verb matches
    /// the segmented control above the buttons.
    enum Mode {
        case signIn, signUp, `continue`

        /// Apple's official button supports the same three verbs via the
        /// initializer parameter — we forward the user's choice here.
        var appleLabel: SignInWithAppleButton.Label {
            switch self {
            case .signIn:    return .signIn
            case .signUp:    return .signUp
            case .continue:  return .continue
            }
        }

        var googleTextKey: String {
            switch self {
            case .signIn:    return "auth.signin_with_google"
            case .signUp:    return "auth.signup_with_google"
            case .continue:  return "auth.continue_with_google"
            }
        }
    }

    let mode: Mode
    let onGoogle: () -> Void
    let onApple: () -> Void

    init(mode: Mode = .continue, onGoogle: @escaping () -> Void, onApple: @escaping () -> Void) {
        self.mode = mode
        self.onGoogle = onGoogle
        self.onApple = onApple
    }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onGoogle) {
                // Icon and label sit next to each other as a single centered
                // unit, matching how SignInWithAppleButton lays out its mark.
                HStack(spacing: 10) {
                    GoogleGlyph()
                        .frame(width: 20, height: 20)
                    Text(tr(mode.googleTextKey))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.primary)
                }
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
            }
            .buttonStyle(.plain)

            // Apple's official button. The label verb tracks `mode` so it
            // stays aligned with the segmented control above. The native
            // button wraps a UIKit _ASAuthorizationAppleIDButton whose label
            // is baked in at init — SwiftUI's diffing reuses the view across
            // state changes, so flipping `mode` alone wouldn't re-render the
            // text. `.id(mode)` forces SwiftUI to discard and rebuild the
            // wrapped view when the verb changes.
            SignInWithAppleButton(mode.appleLabel) { _ in onApple() } onCompletion: { _ in }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .id(mode)
        }
    }
}

/// Official Google "G" mark, drawn pixel-for-pixel from the SVG that Google
/// ships in its sign-in branding bundle
/// (https://developers.google.com/static/identity/images/signin-assets.zip,
/// file: iOS/png@1x/light/ios_light_sq_na.svg).
///
/// The path data covers a 20×20 region from (12,12) to (32,32) in the
/// original 44×44 SVG viewBox. Each `GoogleGlyphShape` variant pulls one of
/// the four brand-color paths; we stack them in a ZStack so they composite
/// correctly. Colours match the SVG fills exactly:
///   #4285F4 blue   – top-right + the horizontal "G" bar
///   #34A853 green  – bottom-right
///   #FBBC04 yellow – bottom-left
///   #EA4335 red    – top-left
private struct GoogleGlyph: View {
    var body: some View {
        ZStack {
            GoogleGlyphShape.blue.fill(Color(red: 66/255,  green: 133/255, blue: 244/255))
            GoogleGlyphShape.green.fill(Color(red: 52/255,  green: 168/255, blue: 83/255))
            GoogleGlyphShape.yellow.fill(Color(red: 251/255, green: 188/255, blue: 4/255))
            GoogleGlyphShape.red.fill(Color(red: 233/255, green: 66/255,  blue: 53/255))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// One of the four colored sub-paths that compose the Google G. Coordinates
/// are in the original SVG's 44-unit space; the Shape transforms them so the
/// icon's natural 20×20 region centers in the rect we're given.
private enum GoogleGlyphShape: Shape {
    case blue, green, yellow, red

    func path(in rect: CGRect) -> Path {
        // Original icon occupies (12,12)..(32,32) within a 44×44 viewbox.
        // Scale that 20-unit region to fit `rect` and translate the offset.
        let s = min(rect.width, rect.height) / 20.0
        let dx = rect.midX - 10 * s
        let dy = rect.midY - 10 * s
        // SVG units → local coordinate, after dropping the 12-unit offset.
        func pt(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: dx + CGFloat(x - 12) * s, y: dy + CGFloat(y - 12) * s)
        }

        var p = Path()
        switch self {
        case .blue:
            // M31.6 22.2273 C31.6 21.5182, 31.5364 20.8364, 31.4182 20.1818
            // H22 V24.05 H27.3818
            // C27.15 25.3, 26.4455 26.3591, 25.3864 27.0682
            // V29.5773 H28.6182
            // C30.5091 27.8364, 31.6 25.2727, 31.6 22.2273 Z
            p.move(to: pt(31.6, 22.2273))
            p.addCurve(to: pt(31.4182, 20.1818),
                       control1: pt(31.6, 21.5182),
                       control2: pt(31.5364, 20.8364))
            p.addLine(to: pt(22, 20.1818))
            p.addLine(to: pt(22, 24.05))
            p.addLine(to: pt(27.3818, 24.05))
            p.addCurve(to: pt(25.3864, 27.0682),
                       control1: pt(27.15, 25.3),
                       control2: pt(26.4455, 26.3591))
            p.addLine(to: pt(25.3864, 29.5773))
            p.addLine(to: pt(28.6182, 29.5773))
            p.addCurve(to: pt(31.6, 22.2273),
                       control1: pt(30.5091, 27.8364),
                       control2: pt(31.6, 25.2727))
            p.closeSubpath()

        case .green:
            // M22 32 C24.7 32, 26.9636 31.1045, 28.6181 29.5773
            // L25.3863 27.0682
            // C24.4909 27.6682, 23.3454 28.0227, 22 28.0227
            // C19.3954 28.0227, 17.1909 26.2636, 16.4045 23.9
            // H13.0636 V26.4909
            // C14.7091 29.7591, 18.0909 32, 22 32 Z
            p.move(to: pt(22, 32))
            p.addCurve(to: pt(28.6181, 29.5773),
                       control1: pt(24.7, 32),
                       control2: pt(26.9636, 31.1045))
            p.addLine(to: pt(25.3863, 27.0682))
            p.addCurve(to: pt(22, 28.0227),
                       control1: pt(24.4909, 27.6682),
                       control2: pt(23.3454, 28.0227))
            p.addCurve(to: pt(16.4045, 23.9),
                       control1: pt(19.3954, 28.0227),
                       control2: pt(17.1909, 26.2636))
            p.addLine(to: pt(13.0636, 23.9))
            p.addLine(to: pt(13.0636, 26.4909))
            p.addCurve(to: pt(22, 32),
                       control1: pt(14.7091, 29.7591),
                       control2: pt(18.0909, 32))
            p.closeSubpath()

        case .yellow:
            // M16.4045 23.9
            // C16.2045 23.3, 16.0909 22.6591, 16.0909 22
            // C16.0909 21.3409, 16.2045 20.7, 16.4045 20.1
            // V17.5091 H13.0636
            // C12.3864 18.8591, 12 20.3864, 12 22
            // C12 23.6136, 12.3864 25.1409, 13.0636 26.4909
            // L16.4045 23.9 Z
            p.move(to: pt(16.4045, 23.9))
            p.addCurve(to: pt(16.0909, 22),
                       control1: pt(16.2045, 23.3),
                       control2: pt(16.0909, 22.6591))
            p.addCurve(to: pt(16.4045, 20.1),
                       control1: pt(16.0909, 21.3409),
                       control2: pt(16.2045, 20.7))
            p.addLine(to: pt(16.4045, 17.5091))
            p.addLine(to: pt(13.0636, 17.5091))
            p.addCurve(to: pt(12, 22),
                       control1: pt(12.3864, 18.8591),
                       control2: pt(12, 20.3864))
            p.addCurve(to: pt(13.0636, 26.4909),
                       control1: pt(12, 23.6136),
                       control2: pt(12.3864, 25.1409))
            p.addLine(to: pt(16.4045, 23.9))
            p.closeSubpath()

        case .red:
            // M22 15.9773
            // C23.4681 15.9773, 24.7863 16.4818, 25.8227 17.4727
            // L28.6909 14.6045
            // C26.9591 12.9909, 24.6954 12, 22 12
            // C18.0909 12, 14.7091 14.2409, 13.0636 17.5091
            // L16.4045 20.1
            // C17.1909 17.7364, 19.3954 15.9773, 22 15.9773 Z
            p.move(to: pt(22, 15.9773))
            p.addCurve(to: pt(25.8227, 17.4727),
                       control1: pt(23.4681, 15.9773),
                       control2: pt(24.7863, 16.4818))
            p.addLine(to: pt(28.6909, 14.6045))
            p.addCurve(to: pt(22, 12),
                       control1: pt(26.9591, 12.9909),
                       control2: pt(24.6954, 12))
            p.addCurve(to: pt(13.0636, 17.5091),
                       control1: pt(18.0909, 12),
                       control2: pt(14.7091, 14.2409))
            p.addLine(to: pt(16.4045, 20.1))
            p.addCurve(to: pt(22, 15.9773),
                       control1: pt(17.1909, 17.7364),
                       control2: pt(19.3954, 15.9773))
            p.closeSubpath()
        }
        return p
    }
}
