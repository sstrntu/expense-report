import SwiftUI

/// Liquid-glass card. Uses the iOS 26 `.glassEffect()` modifier for true GPU-backed
/// refraction; falls back to `.ultraThinMaterial` on earlier OS versions.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var corner: CGFloat = Tokens.radiusCard
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassSurface(corner: corner)
    }
}

extension View {
    @ViewBuilder
    func glassSurface(corner: CGFloat = Tokens.radiusCard) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: corner))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5)
                )
        }
    }

    /// Heavier glass — used for the bottom tab bar.
    @ViewBuilder
    func liquidGlassBar(corner: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: corner))
        } else {
            self
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
        }
    }

    /// Tinted interactive glass — the treatment for primary action buttons.
    /// The interactive flag gives the built-in press shimmer; the soft tinted
    /// shadow lifts the button off the page so it reads as the main action.
    @ViewBuilder
    func prominentGlassSurface(tint: Color, corner: CGFloat = Tokens.radiusButton) -> some View {
        if #available(iOS 26.0, *) {
            self
                .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: corner))
                .shadow(color: tint.opacity(0.32), radius: 12, x: 0, y: 5)
        } else {
            self
                .background(tint, in: RoundedRectangle(cornerRadius: corner))
                .overlay(
                    RoundedRectangle(cornerRadius: corner)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: tint.opacity(0.32), radius: 12, x: 0, y: 5)
        }
    }
}
