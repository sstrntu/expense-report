import SwiftUI

enum TabID: String, CaseIterable {
    case home, dashboard, add, activity, review, profile
}

struct TabItem {
    let id: TabID
    let icon: String
    let label: String
    var isCenter: Bool = false
}

struct BottomTabBar: View {
    @Binding var selected: TabID
    let role: AppRole

    private var tabs: [TabItem] {
        if role == .manager {
            return [
                TabItem(id: .home,      icon: "house.fill",     label: "Overview"),
                TabItem(id: .dashboard, icon: "chart.bar.fill",  label: "Dashboard"),
                TabItem(id: .add,       icon: "plus",            label: "",      isCenter: true),
                TabItem(id: .review,    icon: "tray.fill",       label: "Review"),
                TabItem(id: .profile,   icon: "person.fill",     label: "You"),
            ]
        }
        return [
            TabItem(id: .home,      icon: "house.fill",     label: "Home"),
            TabItem(id: .dashboard, icon: "chart.bar.fill",  label: "Dashboard"),
            TabItem(id: .add,       icon: "plus",            label: "",      isCenter: true),
            TabItem(id: .activity,  icon: "list.bullet",     label: "Activity"),
            TabItem(id: .profile,   icon: "person.fill",     label: "You"),
        ]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                if tab.isCenter {
                    centerButton
                } else {
                    tabButton(tab)
                }
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 64)
        .liquidGlassBar(corner: 32)
        .padding(.horizontal, 16)
    }

    private func tabButton(_ tab: TabItem) -> some View {
        Button {
            selected = tab.id
        } label: {
            VStack(spacing: 3) {
                ZStack(alignment: .top) {
                    // Active dot
                    if selected == tab.id {
                        Circle()
                            .fill(Color.primary)
                            .frame(width: 4, height: 4)
                            .offset(y: -8)
                    }
                    Image(systemName: tab.icon)
                        .font(.system(size: 20, weight: selected == tab.id ? .semibold : .regular))
                        .foregroundStyle(selected == tab.id ? Color.primary : Color.secondary)
                }
                .frame(height: 26)

                Text(tab.label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(selected == tab.id ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var centerButton: some View {
        Button { selected = .add } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Tokens.slate500)
                    .frame(width: 44, height: 44)
                    .shadow(color: Tokens.slate500.opacity(0.4), radius: 10, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                    )
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
