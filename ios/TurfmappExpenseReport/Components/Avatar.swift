import SwiftUI

struct Avatar: View {
    let color: Color
    var size: CGFloat = 36
    var label: String = ""
    var imageURL: URL? = nil

    var body: some View {
        ZStack {
            if let imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initialsBackground
                    case .empty:
                        initialsBackground.opacity(0.7)
                    @unknown default:
                        initialsBackground
                    }
                }
            } else {
                initialsBackground
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 0.5))
    }

    private var initialsBackground: some View {
        Circle()
            .fill(LinearGradient(colors: [color, color.opacity(0.8)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Text(label)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(.white)
            )
    }
}

/// Rounded-square brand icon for a workspace. Shows the uploaded logo when
/// present, otherwise initials derived from the workspace name on the brand
/// color (e.g. "Turfmapp" -> "T", "Baan Saen Saep" -> "BS").
struct WorkspaceBadge: View {
    let color: Color
    let name: String
    var logoURL: URL? = nil
    var size: CGFloat = 26
    var corner: CGFloat = 7

    var body: some View {
        ZStack {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        initialsBackground
                    }
                }
            } else {
                initialsBackground
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner))
    }

    private var initials: String {
        let tokens = name.split { !$0.isLetter && !$0.isNumber }
        let letters = tokens.compactMap { $0.first.map { String($0).uppercased() } }
        if !letters.isEmpty { return letters.prefix(2).joined() }
        let fallback = name.first.map { String($0).uppercased() } ?? "?"
        return fallback
    }

    private var initialsBackground: some View {
        RoundedRectangle(cornerRadius: corner)
            .fill(color)
            .overlay(
                Text(initials)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(.white)
            )
    }
}
