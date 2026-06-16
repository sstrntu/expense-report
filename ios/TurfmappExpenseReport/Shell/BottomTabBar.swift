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
    /// True when the user can review via a *project* role even though their
    /// workspace role is `employee`. Lets project-scoped approvers/finance get
    /// the reviewer tab set (Overview + Review) instead of the employee set.
    var canReview: Bool = false
    var badgeCounts: [TabID: Int] = [:]
    // Subscribe so labels re-render immediately when the user switches language.
    @ObservedObject private var localization = LocalizationManager.shared
    /// Drives the morphing highlight pill that slides between tabs.
    @Namespace private var activePill

    private var showsReviewerTabs: Bool {
        role != .employee || canReview
    }

    private var tabs: [TabItem] {
        if showsReviewerTabs {
            return [
                TabItem(id: .home,      icon: "house.fill",     label: tr("tab.overview")),
                TabItem(id: .dashboard, icon: "chart.bar.fill",  label: tr("tab.dashboard")),
                TabItem(id: .add,       icon: "plus",            label: "",      isCenter: true),
                TabItem(id: .review,    icon: "tray.fill",       label: tr("tab.review")),
                TabItem(id: .profile,   icon: "person.fill",     label: tr("tab.you")),
            ]
        }
        return [
            TabItem(id: .home,      icon: "house.fill",     label: tr("tab.home")),
            TabItem(id: .dashboard, icon: "chart.bar.fill",  label: tr("tab.dashboard")),
            TabItem(id: .add,       icon: "plus",            label: "",      isCenter: true),
            TabItem(id: .activity,  icon: "list.bullet",     label: tr("tab.activity")),
            TabItem(id: .profile,   icon: "person.fill",     label: tr("tab.you")),
        ]
    }

    var body: some View {
        // GlassEffectContainer lets the bar and the raised center button render
        // as one liquid surface — the shapes blend where they come close
        // instead of stacking two independent blurs.
        GlassEffectContainer(spacing: 18) {
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
        }
        .padding(.horizontal, 16)
        .sensoryFeedback(.selection, trigger: selected)
    }

    private func tabButton(_ tab: TabItem) -> some View {
        let badgeCount = badgeCounts[tab.id] ?? 0
        let isActive = selected == tab.id
        return Button {
            withAnimation(Motion.snappy) { selected = tab.id }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
                    .symbolEffect(.bounce, options: .speed(1.4), value: isActive)
                    .overlay(alignment: .topTrailing) {
                        if badgeCount > 0 {
                            Text(badgeCount < 100 ? "\(badgeCount)" : "99+")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, badgeCount < 10 ? 4 : 5)
                                .padding(.vertical, 2)
                                .background(Tokens.rejected, in: Capsule())
                                .offset(x: 10, y: -6)
                        }
                    }
                    .frame(height: 26)

                Text(tab.label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(isActive ? Color.primary : Color.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background {
                // Soft pill that slides between tabs as the selection moves.
                if isActive {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.primary.opacity(0.07))
                        .matchedGeometryEffect(id: "activePill", in: activePill)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
    }

    private var centerButton: some View {
        Button {
            withAnimation(Motion.bouncy) { selected = .add }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .prominentGlassSurface(tint: Tokens.slate500, corner: 24)
        }
        .buttonStyle(.pressable)
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: selected == .add)
    }
}
