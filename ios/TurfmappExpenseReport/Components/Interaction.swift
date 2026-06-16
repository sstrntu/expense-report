import SwiftUI

/// Shared motion curves so every surface animates with the same feel.
/// `snappy` drives navigation + selection, `bouncy` is for playful elements
/// (tab bar, FAB), `gentle` for ambient fades (splash, toasts).
enum Motion {
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.86)
    static let bouncy = Animation.spring(response: 0.38, dampingFraction: 0.68)
    static let gentle = Animation.easeInOut(duration: 0.32)
}

/// The app-wide button feel: springy press-down scale with a slight dim,
/// plus automatic fading when the button is disabled. Visually identical to
/// `.plain` at rest, so it can replace it anywhere without relayout.
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.82 : (isEnabled ? 1 : 0.45))
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
            .animation(Motion.gentle, value: isEnabled)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    /// Softer variant for full-width cards/rows where 0.96 reads as too much.
    static var pressableRow: PressableButtonStyle { PressableButtonStyle(scale: 0.985) }
}
