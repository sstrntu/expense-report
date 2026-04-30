import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    var role: AppRole
    var onSignOut: () -> Void
    var onNav: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You").font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 4).padding(.top, 4)

            GlassCard(padding: 18) {
                HStack(spacing: 14) {
                    Avatar(color: app.company.color, size: 56, label: initials(app.userName))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.userName).font(.system(size: 17, weight: .bold))
                        Text((role == .employee ? "Member" : "Workspace admin") + " · \(app.userEmail)")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }

            if role != .employee {
                sectionHeader("Workspace admin")
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        navRow(icon: "folder.fill",  label: "Manage projects",
                               sub: "\(app.currentProjects.count) projects · \(money(app.currentProjects.reduce(0) { $0 + $1.budget })) budget") { onNav("manageProjects") }
                        Divider().opacity(0.4)
                        navRow(icon: "shield.fill",  label: "Permissions",
                               sub: "\(app.currentMembers.count) members · 3 roles")        { onNav("permissions") }
                    }
                }
            }

            sectionHeader("Account")
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    navRow(icon: "bell.fill",      label: "Notifications",
                           sub: "Approvals, reminders, reimbursements") { onNav("notifications") }
                    Divider().opacity(0.4)
                    navRow(icon: "person.crop.circle.fill", label: "Account",
                           sub: "Profile, email, workspace identity") { onNav("account") }
                    Divider().opacity(0.4)
                    navRow(icon: "lock.fill", label: "Security",
                           sub: "Password, sessions, recovery") { onNav("security") }
                    Divider().opacity(0.4)
                    navRow(icon: "gearshape.fill", label: "Preferences",
                           sub: "Theme, currency, export format") { onNav("preferences") }
                    Divider().opacity(0.4)
                    navRow(icon: "doc.text.fill", label: "Reports & export",
                           sub: "CSV, PDF, monthly summaries") { onNav("reports") }
                    Divider().opacity(0.4)
                    navRow(icon: "wifi.exclamationmark", label: "System states",
                           sub: "Loading, offline, empty, retry") { onNav("systemStates") }
                    Divider().opacity(0.4)
                    navRow(icon: "questionmark.circle.fill", label: "Help & support") { onNav("help") }
                    Divider().opacity(0.4)
                    navRow(icon: "info.circle.fill", label: "Legal & about") { onNav("legal") }
                }
            }

            if role == .employee {
                GlassCard(padding: 14) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "person.fill")
                            .foregroundStyle(Tokens.slate500)
                            .font(.system(size: 14, weight: .semibold))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Employee access").font(.system(size: 12.5, weight: .semibold))
                            Text("Permissions are assigned by a manager or admin.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                sectionHeader("Access")
                GlassCard(padding: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        roleScopeRow("Manager", "Review queue, approve/reject, manage projects and policies", active: role == .manager)
                        Divider().opacity(0.4)
                        roleScopeRow("Admin", "Invite members, remove users, manage policies and reports", active: role == .admin)
                    }
                }
            }

            GlassCard(padding: 0) {
                navRow(icon: "rectangle.portrait.and.arrow.right",
                       label: "Sign out", tint: Tokens.rejected, chevron: false) { onSignOut() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    private func roleScopeRow(_ title: String, _ subtitle: String, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(active ? Tokens.approved : Color.secondary.opacity(0.45))
                .font(.system(size: 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func initials(_ name: String) -> String {
        let value = name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
        return value.isEmpty ? "U" : value
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .semibold)).tracking(0.6)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 4)
    }

    private func navRow(icon: String, label: String, sub: String? = nil,
                        tint: Color? = nil, chevron: Bool = true,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint ?? .secondary)
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(tint ?? .primary)
                    if let sub {
                        Text(sub).font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if chevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Account and release-support screens

struct NotificationsView: View {
    @EnvironmentObject var app: AppState
    var onBack: () -> Void
    @State private var selectedNotification: AppNotification? = nil
    @State private var filter: NotificationFilter = .all

    private var notifications: [AppNotification] {
        [
            AppNotification(title: "Approval requested", subtitle: "Delta Airlines needs manager review", tint: Tokens.pending, action: "Open expense", kind: .approval, time: "2m ago", unread: true),
            AppNotification(title: "Expense approved", subtitle: "Uber is ready for purchase confirmation", tint: Tokens.approved, action: "Confirm purchase", kind: .expense, time: "11m ago", unread: true),
            AppNotification(title: "Reimbursement sent", subtitle: "WeWork was marked reimbursed", tint: Tokens.reimbursed, action: "View proof", kind: .payment, time: "Yesterday", unread: false),
            AppNotification(title: "Workspace invite", subtitle: "Finance team invite is pending", tint: app.company.color, action: "Review invite", kind: .admin, time: "Yesterday", unread: false)
        ]
    }

    private var filteredNotifications: [AppNotification] {
        notifications.filter { filter == .all || $0.kind == filter.kind }
    }

    private var unreadCount: Int {
        notifications.filter { $0.unread }.count
    }

    var body: some View {
        settingsContainer(title: "Notifications", onBack: onBack) {
            HStack(spacing: 8) {
                filterChip("All", selected: filter == .all) { filter = .all }
                filterChip("Approvals", selected: filter == .approvals) { filter = .approvals }
                filterChip("Payments", selected: filter == .payments) { filter = .payments }
                filterChip("Admin", selected: filter == .admin) { filter = .admin }
            }

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(filteredNotifications.enumerated()), id: \.element.id) { idx, item in
                        if idx > 0 { Divider().opacity(0.4) }
                        notificationRow(item)
                    }
                }
            }

            infoBanner(icon: "bell.badge.fill", tint: app.company.color,
                       title: "\(unreadCount) unread notifications",
                       message: "Covers approval requests, rejection updates, purchase confirmations, reimbursement events, and workspace invites.")

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    actionRow("Notification preferences", "Push, email, and in-app settings")
                    Divider().opacity(0.4)
                    actionRow("Approval alerts", "Manager and admin notifications")
                }
            }
        }
        .sheet(item: $selectedNotification) { item in
            NotificationDetailSheet(notification: item)
                .presentationDetents([.height(360)])
        }
    }

    private func notificationRow(_ item: AppNotification) -> some View {
        Button {
            selectedNotification = item
        } label: {
            HStack(spacing: 12) {
                Circle().fill(item.unread ? item.tint : item.tint.opacity(0.45)).frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.title).font(.system(size: 13.5, weight: .semibold))
                        Text(item.kind.label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(item.tint)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(item.tint.opacity(0.10), in: Capsule())
                    }
                    Text(item.subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(item.time).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.tertiary)
                    if item.unread {
                        Text("New").font(.system(size: 9, weight: .semibold)).foregroundStyle(Tokens.pending)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selected ? Tokens.slate500 : Color.primary.opacity(0.06), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func actionRow(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct AppNotification: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let tint: Color
    let action: String
    let kind: NotificationKind
    let time: String
    let unread: Bool
}

enum NotificationFilter {
    case all, approvals, payments, admin

    var kind: NotificationKind? {
        switch self {
        case .all: return nil
        case .approvals: return .approval
        case .payments: return .payment
        case .admin: return .admin
        }
    }
}

enum NotificationKind {
    case approval, expense, payment, admin

    var label: String {
        switch self {
        case .approval: return "Approval"
        case .expense: return "Expense"
        case .payment: return "Payment"
        case .admin: return "Admin"
        }
    }
}

struct NotificationDetailSheet: View {
    let notification: AppNotification
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.title).font(.system(size: 20, weight: .bold))
                    Text(notification.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

            infoBanner(icon: "arrowshape.turn.up.right.fill", tint: notification.tint,
                       title: notification.action,
                       message: "Production tap-through should deep-link to the relevant expense, proof, or workspace invite.")
                .padding(.horizontal, 20)

            Spacer()
        }
    }
}

struct AccountSettingsView: View {
    @EnvironmentObject var app: AppState
    var onBack: () -> Void
    @State private var name = ""
    @State private var email = ""

    var body: some View {
        settingsContainer(title: "Account", onBack: onBack) {
            GlassCard(padding: 18) {
                HStack(spacing: 14) {
                    Avatar(color: app.company.color, size: 54, label: initials(app.userName))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(app.userName).font(.system(size: 17, weight: .bold))
                        Text(app.userEmail).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
            }

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    editableSetting("Name", text: $name)
                    Divider().opacity(0.4)
                    editableSetting("Email", text: $email)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Workspace", value: app.company.name, showChevron: false)
                }
            }

            Button {
                app.userName = name.isEmpty ? app.userName : name
                app.userEmail = email.isEmpty ? app.userEmail : email
            } label: {
                Text("Save account").primaryActionLabel()
            }
            .buttonStyle(.plain)
        }
        .onAppear {
            name = app.userName
            email = app.userEmail
        }
    }

    private func initials(_ name: String) -> String {
        let value = name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
        return value.isEmpty ? "U" : value
    }

    private func editableSetting(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: text)
                .font(.system(size: 13.5, weight: .medium))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 210)
        }
        .padding(.vertical, 11)
    }
}

struct SecuritySettingsView: View {
    var onBack: () -> Void

    var body: some View {
        settingsContainer(title: "Security", onBack: onBack) {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    securityRow("Password", "Updated 24 days ago", "key.fill")
                    Divider().opacity(0.4)
                    securityRow("Active sessions", "1 iPhone simulator", "iphone")
                    Divider().opacity(0.4)
                    securityRow("Recovery email", "Verified", "checkmark.seal.fill")
                }
            }
            infoBanner(icon: "lock.shield.fill", tint: Tokens.slate500,
                       title: "Session expired state",
                       message: "When auth expires, users return to sign in without losing a local draft.")
        }
    }

    private func securityRow(_ title: String, _ subtitle: String, _ icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(.secondary).frame(width: 30, height: 30)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct AppPreferencesView: View {
    var onBack: () -> Void
    @State private var compactMode = false
    @State private var requireReceipt = true

    var body: some View {
        settingsContainer(title: "Preferences", onBack: onBack) {
            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    FormFieldRow(label: "Currency", value: "USD", showChevron: true)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Export format", value: "CSV + PDF", showChevron: true)
                    Divider().opacity(0.4)
                    ToggleRow(label: "Compact lists", isOn: compactMode)
                    Divider().opacity(0.4)
                    ToggleRow(label: "Require receipts", sub: "For reimbursable expenses", isOn: requireReceipt)
                }
            }
        }
    }
}

struct ReportsExportView: View {
    @EnvironmentObject var app: AppState
    var onBack: () -> Void

    var body: some View {
        settingsContainer(title: "Reports", onBack: onBack) {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(app.company.name).font(.system(size: 15, weight: .bold))
                    HStack {
                        reportMetric("Expenses", "\(app.currentExpenses.count)")
                        Spacer()
                        reportMetric("Spend", money(app.currentExpenses.reduce(0) { $0 + $1.amount }))
                        Spacer()
                        reportMetric("Pending", "\(app.currentExpenses.filter { $0.status == .pending }.count)")
                    }
                }
            }

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    exportRow("Monthly PDF", "Summary by status and project")
                    Divider().opacity(0.4)
                    exportRow("CSV export", "Raw expense rows for finance")
                    Divider().opacity(0.4)
                    exportRow("Receipt bundle", "Attached receipts and proofs")
                }
            }
        }
    }

    private func reportMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 15, weight: .bold))
        }
    }

    private func exportRow(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "square.and.arrow.up").foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct HelpSupportView: View {
    var onBack: () -> Void

    var body: some View {
        settingsContainer(title: "Help", onBack: onBack) {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    helpRow("How approvals work", "Pre-approval, purchase, reimbursement")
                    Divider().opacity(0.4)
                    helpRow("Contact support", "Send logs and a short description")
                    Divider().opacity(0.4)
                    helpRow("Report a problem", "Attach screenshots and device details")
                }
            }
        }
    }

    private func helpRow(_ title: String, _ subtitle: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct SystemStatesView: View {
    var onBack: () -> Void

    var body: some View {
        settingsContainer(title: "System states", onBack: onBack) {
            stateCard(icon: "hourglass", title: "Loading", message: "Skeleton cards appear while workspace data syncs.", tint: Tokens.slate500)
            stateCard(icon: "wifi.slash", title: "Offline", message: "Users can keep drafts locally and retry when connected.", tint: Tokens.pending)
            stateCard(icon: "exclamationmark.triangle.fill", title: "Failed to load", message: "Show a retry action without losing the selected organization.", tint: Tokens.rejected)
            stateCard(icon: "tray", title: "Empty", message: "First-run screens explain what to create or submit next.", tint: Tokens.approved)
        }
    }

    private func stateCard(icon: String, title: String, message: String, tint: Color) -> some View {
        GlassCard(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13.5, weight: .semibold))
                    Text(message).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct LegalAboutView: View {
    var onBack: () -> Void

    var body: some View {
        settingsContainer(title: "About", onBack: onBack) {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Turfmapp Expenses").font(.system(size: 18, weight: .bold))
                    Text("Version 1.0").font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    FormFieldRow(label: "Terms", value: "View", showChevron: true)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Privacy", value: "View", showChevron: true)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Licenses", value: "View", showChevron: true)
                }
            }
        }
    }
}

@MainActor
func settingsContainer<Content: View>(title: String, onBack: @escaping () -> Void, @ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 999)
            Text(title).font(.system(size: 18, weight: .bold))
        }
        .padding(.horizontal, 4).padding(.top, 4)

        content()
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 100)
}
