import SwiftUI

struct Avatar: View {
    let color: Color
    var size: CGFloat = 36
    var label: String = ""

    var body: some View {
        Circle()
            .fill(LinearGradient(colors: [color, color.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: size, height: size)
            .overlay(
                Text(label)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            )
            .overlay(
                Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5)
            )
    }
}
