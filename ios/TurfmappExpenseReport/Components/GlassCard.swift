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
}
