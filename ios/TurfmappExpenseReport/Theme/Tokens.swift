import SwiftUI

enum Tokens {
    static let slate900 = Color(hex: 0x21293A)
    static let slate800 = Color(hex: 0x424753)
    static let slate500 = Color(hex: 0x878E9F)
    static let slate400 = Color(hex: 0x8990A1)
    static let slate300 = Color(hex: 0xA0A7BA)
    static let slate100 = Color(hex: 0xCDD2DE)
    static let slate025 = Color(hex: 0xF0F2F7)

    static let approved   = Color(hex: 0x5EA06C)
    static let pending    = Color(hex: 0xDCA050)
    static let rejected   = Color(hex: 0xD66C6C)
    static let purchased  = Color(hex: 0x6B7EC9)
    static let reimbursed = Color(hex: 0x4A9EC4)
    static let aiPurple   = Color(hex: 0xB8A0E8)

    static let radiusCard: CGFloat = 22
    static let radiusButton: CGFloat = 14
    static let radiusPill: CGFloat = 999
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8)  & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
