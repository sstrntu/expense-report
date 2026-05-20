import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var role: AppRole
    var onSignOut: () -> Void
    var onNav: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("You").font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 4).padding(.top, 4)

            let displayName = repositoryApp.currentUserProfile?.displayName ?? app.userName
            let avatarURL = repositoryApp.currentUserProfile?.avatarUrl.flatMap(URL.init(string:))

            Button { onNav("account") } label: {
                GlassCard(padding: 18) {
                    HStack(spacing: 14) {
                        Avatar(
                            color: repositoryApp.selectedWorkspace?.brandColor ?? app.company.color,
                            size: 56,
                            label: initials(displayName),
                            imageURL: avatarURL
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName.isEmpty ? "Add your name" : displayName)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color.primary)
                            Text(roleSubtitle + " · \(app.userEmail)")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)

            if role != .employee {
                sectionHeader("Workspace admin")
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        if role == .admin {
                            navRow(icon: "building.2.fill", label: "Workspace",
                                   sub: "Name, logo, and identity") { onNav("workspace") }
                            Divider().opacity(0.4)
                        }
                        navRow(icon: "folder.fill",  label: "Manage projects",
                               sub: "\(repositoryApp.projects.count) projects · \(money(repositoryApp.projects.filter { $0.budget.currency == repositoryApp.aggregationCurrency }.reduce(0) { $0 + $1.budget.decimalValue }, currency: repositoryApp.aggregationCurrency)) budget") { onNav("manageProjects") }
                        Divider().opacity(0.4)
                        navRow(icon: "shield.fill",  label: "Permissions",
                               sub: "\(repositoryApp.members.count) members · 4 roles")        { onNav("permissions") }
                    }
                }
            }

            sectionHeader("Account")
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    navRow(icon: "list.bullet",    label: "My activity",
                           sub: "Drafts, submitted, approved, reimbursed") { onNav("activity") }
                    Divider().opacity(0.4)
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

    private var roleSubtitle: String {
        switch role {
        case .employee: return "Member"
        case .manager: return "Manager"
        case .finance: return "Finance"
        case .admin: return "Workspace admin"
        }
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
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onBack: () -> Void
    var onOpenExpense: (DomainExpense) -> Void = { _ in }
    @State private var selectedNotification: AppNotification? = nil
    @State private var filter: NotificationFilter = .all

    private var notifications: [AppNotification] {
        repositoryApp.notifications.map { n in
            let kind: NotificationKind
            let tint: Color
            switch n.eventType {
            case .expenseSubmitted, .expenseApproved, .expenseRejected:
                kind = .approval; tint = Tokens.pending
            case .purchaseConfirmed:
                kind = .expense; tint = Tokens.purchased
            case .reimbursementSent:
                kind = .payment; tint = Tokens.reimbursed
            case .workspaceInvite, .projectBudgetWarning:
                kind = .admin; tint = Tokens.slate500
            }
            return AppNotification(
                domainId: n.id,
                expenseId: n.expenseId,
                title: n.title,
                subtitle: n.body,
                tint: tint,
                action: "Open",
                kind: kind,
                time: Self.relativeFormatter.localizedString(for: n.createdAt, relativeTo: Date()),
                unread: !n.isRead
            )
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

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
                if filteredNotifications.isEmpty {
                    emptyNotifications
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredNotifications.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { Divider().opacity(0.4) }
                            notificationRow(item)
                        }
                    }
                }
            }

            infoBanner(icon: "bell.badge.fill", tint: repositoryApp.selectedWorkspace?.brandColor ?? app.company.color,
                       title: "\(unreadCount) unread notifications",
                       message: "New approval, reimbursement, and workspace updates will appear here.")

        }
        .sheet(item: $selectedNotification) { item in
            NotificationDetailSheet(notification: item)
                .presentationDetents([.height(360)])
        }
    }

    private var emptyNotifications: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No notifications")
                .font(.system(size: 15, weight: .semibold))
            Text("Approval, reimbursement, and invite updates will appear here when they are available.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 28)
    }

    private func notificationRow(_ item: AppNotification) -> some View {
        Button {
            if item.unread, let domainId = item.domainId {
                Task { await repositoryApp.markNotificationRead(id: domainId) }
            }
            if let expenseId = item.expenseId,
               let expense = repositoryApp.expenses.first(where: { $0.id == expenseId }) {
                onOpenExpense(expense)
            } else {
                selectedNotification = item
            }
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

}

struct AppNotification: Identifiable {
    let id = UUID()
    var domainId: String? = nil
    var expenseId: String? = nil
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
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onBack: () -> Void
    @State private var name = ""
    @State private var email = ""
    @State private var avatarPick: PhotosPickerItem?
    @State private var uploadingAvatar = false

    var body: some View {
        let displayName = repositoryApp.currentUserProfile?.displayName ?? app.userName
        let avatarURL = repositoryApp.currentUserProfile?.avatarUrl.flatMap(URL.init(string:))

        settingsContainer(title: "Account", onBack: onBack) {
            GlassCard(padding: 18) {
                HStack(spacing: 14) {
                    PhotosPicker(selection: $avatarPick, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            Avatar(
                                color: repositoryApp.selectedWorkspace?.brandColor ?? app.company.color,
                                size: 54,
                                label: initials(displayName),
                                imageURL: avatarURL
                            )
                            if uploadingAvatar {
                                Circle().fill(.ultraThinMaterial).frame(width: 54, height: 54)
                                    .overlay(ProgressView().tint(.white))
                            } else {
                                Circle().fill(Tokens.slate500)
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(displayName.isEmpty ? "Add your name" : displayName)
                            .font(.system(size: 17, weight: .bold))
                        Text(app.userEmail).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .onChange(of: avatarPick) { _, item in
                guard let item else { return }
                Task {
                    uploadingAvatar = true
                    if let data = try? await item.loadTransferable(type: Data.self),
                       !data.isEmpty {
                        _ = await repositoryApp.setUserAvatar(data: data, contentType: "image/jpeg", fileExtension: "jpg")
                    }
                    avatarPick = nil
                    uploadingAvatar = false
                }
            }

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    editableSetting("Name", text: $name)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Email", value: app.userEmail, showChevron: false)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Workspace", value: repositoryApp.selectedWorkspace?.name ?? app.company.name, showChevron: false)
                }
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                           title: "Could not save", message: lastError)
            }

            Button {
                let newName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !newName.isEmpty else { return }
                Task {
                    if await repositoryApp.updateDisplayName(newName) {
                        await MainActor.run { app.userName = newName }
                    }
                }
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
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onBack: () -> Void
    @State private var showPasswordSheet = false
    @State private var statusMessage: String?

    var body: some View {
        settingsContainer(title: "Security", onBack: onBack) {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    Button { showPasswordSheet = true } label: {
                        securityRow("Change password", "Set a new password for this account", "key.fill", chevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                    Button {
                        Task {
                            if await repositoryApp.requestPasswordReset(email: app.userEmail) {
                                await MainActor.run { statusMessage = "Password-reset email sent to \(app.userEmail)." }
                            }
                        }
                    } label: {
                        securityRow("Send password reset email", "Email a reset link to \(app.userEmail)", "envelope.fill", chevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                    Button {
                        Task {
                            let ok = await repositoryApp.signOutAllSessions()
                            if ok {
                                await MainActor.run {
                                    statusMessage = "Signed out of all devices."
                                    app.signOut()
                                }
                            }
                        }
                    } label: {
                        securityRow("Sign out of all devices", "Invalidates every active session", "rectangle.portrait.and.arrow.right.fill", chevron: true, tint: Tokens.rejected)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let statusMessage {
                infoBanner(icon: "checkmark.seal.fill", tint: Tokens.approved,
                           title: "Done", message: statusMessage)
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                           title: "Could not complete", message: lastError)
            }
        }
        .sheet(isPresented: $showPasswordSheet) {
            ChangePasswordSheet { newPassword in
                Task {
                    if await repositoryApp.updatePassword(newPassword) {
                        await MainActor.run {
                            statusMessage = "Password updated."
                            showPasswordSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.height(360)])
        }
    }

    private func securityRow(_ title: String, _ subtitle: String, _ icon: String,
                             chevron: Bool = false, tint: Color? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(tint ?? .secondary).frame(width: 30, height: 30)
                .background((tint ?? Color.primary).opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(tint ?? Color.primary)
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct ChangePasswordSheet: View {
    var onSubmit: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var newPassword = ""
    @State private var confirm = ""

    private var canSubmit: Bool {
        newPassword.count >= 8 && newPassword == confirm
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Change password").font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text("New").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        SecureField("8+ characters", text: $newPassword)
                            .font(.system(size: 13.5, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }
                    .padding(.vertical, 11)
                    Divider().opacity(0.4)
                    HStack {
                        Text("Confirm").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        SecureField("Re-enter", text: $confirm)
                            .font(.system(size: 13.5, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }
                    .padding(.vertical, 11)
                }
            }
            .padding(.horizontal, 20)

            if !confirm.isEmpty && newPassword != confirm {
                Text("Passwords don't match.")
                    .font(.system(size: 12)).foregroundStyle(Tokens.rejected)
                    .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                onSubmit(newPassword)
            } label: {
                Text("Save").primaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity(canSubmit ? 1 : 0.5)
            .disabled(!canSubmit)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

struct AppPreferencesView: View {
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onBack: () -> Void
    @AppStorage("pref.compactLists") private var compactMode = false

    var body: some View {
        settingsContainer(title: "Preferences", onBack: onBack) {
            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    FormFieldRow(label: "Workspace currency",
                                 value: repositoryApp.selectedWorkspace?.defaultCurrency ?? "USD",
                                 showChevron: false)
                    Divider().opacity(0.4)
                    ToggleRow(label: "Compact lists", sub: "Saved on this device", isOn: $compactMode)
                }
            }
            infoBanner(icon: "info.circle.fill", tint: Tokens.slate500,
                       title: "Workspace settings",
                       message: "Currency and receipt rules are configured per workspace and project by an admin.")
        }
    }
}

struct ReportsExportView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onBack: () -> Void

    @State private var csvFile: URL?

    var body: some View {
        settingsContainer(title: "Reports", onBack: onBack) {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(repositoryApp.selectedWorkspace?.name ?? app.company.name).font(.system(size: 15, weight: .bold))
                    HStack {
                        reportMetric("Expenses", "\(repositoryApp.expenses.count)")
                        Spacer()
                        reportMetric("Spend",
                            money(repositoryApp.expensesInDefaultCurrency.reduce(0) { $0 + $1.amount.decimalValue },
                                  currency: repositoryApp.aggregationCurrency))
                        Spacer()
                        reportMetric("Pending", "\(repositoryApp.managerQueue.count)")
                    }
                }
            }

            if repositoryApp.expenses.isEmpty {
                infoBanner(icon: "tray", tint: Tokens.slate500,
                           title: "Nothing to export yet",
                           message: "Submit your first expense and the CSV export will be ready here.")
            } else {
                Button { csvFile = makeCSVFile() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Export CSV").font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text("\(repositoryApp.expenses.count) rows — id, date, project, category, merchant, amount, currency, status")
                                .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .glassSurface(corner: 18)

                if let csvFile {
                    ShareLink(item: csvFile) {
                        HStack(spacing: 12) {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(Tokens.approved)
                                .frame(width: 30, height: 30)
                                .background(Tokens.approved.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Share \(csvFile.lastPathComponent)")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Text("Send to Mail, Files, AirDrop, …")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .glassSurface(corner: 18)
                }
            }

            infoBanner(icon: "info.circle.fill", tint: Tokens.slate500,
                       title: "PDF & receipt bundle",
                       message: "Coming soon — for now use the CSV in any spreadsheet tool.")
        }
    }

    private func makeCSVFile() -> URL? {
        let projectsById = Dictionary(uniqueKeysWithValues: repositoryApp.projects.map { ($0.id, $0.name) })
        var rows: [String] = ["id,date,project,category,merchant,amount,currency,status"]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        for e in repositoryApp.expenses {
            let date = e.submittedAt ?? e.purchaseDate ?? e.createdAt
            let project = projectsById[e.projectId] ?? e.projectId
            let category = repositoryApp.categoryName(forId: e.categoryId)
            let amount = String(format: "%.2f", e.amount.decimalValue)
            let cols = [e.id, iso.string(from: date), project, category, e.merchant, amount, e.amount.currency, e.status.rawValue]
            rows.append(cols.map(csvEscape).joined(separator: ","))
        }
        let csv = rows.joined(separator: "\n").appending("\n")
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let workspaceSlug = (repositoryApp.selectedWorkspace?.name ?? "expenses")
            .lowercased().replacingOccurrences(of: " ", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(workspaceSlug)-\(stamp).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    private func csvEscape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private func reportMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10.5, weight: .semibold)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 15, weight: .bold))
        }
    }

}

struct HelpSupportView: View {
    var onBack: () -> Void

    var body: some View {
        settingsContainer(title: "Help", onBack: onBack) {
            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("How approvals work").font(.system(size: 13.5, weight: .semibold))
                    Text("Submit a pre-approval before purchase, or a reimbursement claim afterwards. The manager queue clears requests above the project's auto-approve threshold; finance then handles reimbursement.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "mailto:support@turfmapp.io?subject=Expenses%20app%20support")!) {
                GlassCard(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Tokens.slate500)
                            .frame(width: 30, height: 30)
                            .background(Tokens.slate500.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Contact support").font(.system(size: 13.5, weight: .semibold))
                                .foregroundStyle(Color.primary)
                            Text("support@turfmapp.io")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
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
                    FormFieldRow(label: "Build", value: "1.0 (1)", showChevron: false)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Backend", value: "Supabase", showChevron: false)
                }
            }
        }
    }
}

struct WorkspaceSettingsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onBack: () -> Void

    @State private var logoPick: PhotosPickerItem?
    @State private var uploading = false
    @State private var nameDraft: String = ""
    @State private var currencyDraft: String = "USD"
    @State private var savingDetails = false
    @State private var saveStatus: String?

    private static let currencyOptions = ["USD", "EUR", "GBP", "THB", "JPY", "SGD", "AUD", "CAD"]

    var body: some View {
        let workspace = repositoryApp.selectedWorkspace
        let logoURL = workspace?.logoUrl.flatMap(URL.init(string:))

        settingsContainer(title: "Workspace", onBack: onBack) {
            GlassCard(padding: 18) {
                HStack(spacing: 14) {
                    PhotosPicker(selection: $logoPick, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            WorkspaceBadge(
                                color: workspace?.brandColor ?? app.company.color,
                                name: workspace?.name ?? app.company.name,
                                logoURL: logoURL,
                                size: 60,
                                corner: 14
                            )
                            if uploading {
                                RoundedRectangle(cornerRadius: 14).fill(.ultraThinMaterial)
                                    .frame(width: 60, height: 60)
                                    .overlay(ProgressView().tint(.white))
                            } else {
                                Circle().fill(Tokens.slate500)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Image(systemName: "pencil")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundStyle(.white)
                                    )
                                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workspace?.name ?? app.company.name)
                            .font(.system(size: 17, weight: .bold))
                        Text("Tap the logo to upload an image, or leave it to show the workspace's initials.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
            }
            .onChange(of: logoPick) { _, item in
                guard let item else { return }
                Task {
                    uploading = true
                    if let data = try? await item.loadTransferable(type: Data.self),
                       !data.isEmpty {
                        _ = await repositoryApp.setWorkspaceLogo(data: data, contentType: "image/jpeg", fileExtension: "jpg")
                    }
                    logoPick = nil
                    uploading = false
                }
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                           title: "Could not update workspace", message: lastError)
            }

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Name").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        TextField("Workspace name", text: $nameDraft)
                            .font(.system(size: 13.5, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }
                    .padding(.vertical, 11)
                    Divider().opacity(0.4)
                    HStack {
                        Text("Default currency").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        Picker("Currency", selection: $currencyDraft) {
                            ForEach(Self.currencyOptions, id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.vertical, 8)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Workspace ID",
                                 value: String((workspace?.id ?? "").prefix(8)) + "…",
                                 showChevron: false)
                }
            }

            if let saveStatus {
                infoBanner(icon: "checkmark.seal.fill", tint: Tokens.approved,
                           title: "Saved", message: saveStatus)
            }

            Button {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Task {
                    savingDetails = true
                    let ok = await repositoryApp.updateWorkspace(name: trimmed, defaultCurrency: currencyDraft)
                    await MainActor.run {
                        savingDetails = false
                        if ok { saveStatus = "Workspace updated." }
                    }
                }
            } label: {
                Text(savingDetails ? "Saving..." : "Save changes").primaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity((nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      (nameDraft == (workspace?.name ?? "") && currencyDraft == (workspace?.defaultCurrency ?? "USD")) ||
                      savingDetails) ? 0.5 : 1)
            .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      (nameDraft == (workspace?.name ?? "") && currencyDraft == (workspace?.defaultCurrency ?? "USD")) ||
                      savingDetails)

            infoBanner(icon: "info.circle.fill", tint: Tokens.slate500,
                       title: "Per-project policy",
                       message: "Approval thresholds and routing live on individual projects — open Manage projects to edit those.")
        }
        .onAppear {
            nameDraft = workspace?.name ?? ""
            currencyDraft = workspace?.defaultCurrency ?? "USD"
        }
        .onChange(of: repositoryApp.selectedWorkspace?.id) { _, _ in
            nameDraft = repositoryApp.selectedWorkspace?.name ?? ""
            currencyDraft = repositoryApp.selectedWorkspace?.defaultCurrency ?? "USD"
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
