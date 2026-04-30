import SwiftUI

struct StatusPill: View {
    let text: String
    var tint: Color = Tokens.slate500
    var leadingIcon: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let icon = leadingIcon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
            }
            Text(text)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .foregroundStyle(tint)
        .background(tint.opacity(0.18), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.30), lineWidth: 0.5))
    }
}

extension StatusPill {
    init(status: ExpenseStatus) {
        self.init(text: status.label, tint: status.tint)
    }
}
