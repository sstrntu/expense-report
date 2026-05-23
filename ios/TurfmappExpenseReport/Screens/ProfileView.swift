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
            Text(tr("profile.title")).font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 4).padding(.top, 4)

            let displayName = repositoryApp.currentUserProfile?.displayName ?? app.userName
            let avatarURL = repositoryApp.currentUserProfile?.avatarUrl.flatMap(URL.init(string:))

            Button { onNav("account") } label: {
                GlassCard(padding: Tokens.padHero) {
                    HStack(spacing: 14) {
                        Avatar(
                            color: repositoryApp.selectedWorkspace?.brandColor ?? app.company.color,
                            size: 56,
                            label: initials(displayName),
                            imageURL: avatarURL
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName.isEmpty ? tr("profile.add_name") : displayName)
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

            if role == .manager || role == .admin {
                sectionHeader(tr("profile.section.workspace_admin"))
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        if role == .admin {
                            navRow(icon: "building.2.fill", label: tr("profile.nav.workspace"),
                                   sub: tr("profile.nav.workspace.sub")) { onNav("workspace") }
                            Divider().opacity(0.4)
                        }
                        let budget = money(repositoryApp.projects.filter { $0.budget.currency == repositoryApp.aggregationCurrency }.reduce(0) { $0 + $1.budget.decimalValue }, currency: repositoryApp.aggregationCurrency)
                        navRow(icon: "folder.fill",  label: tr("profile.nav.manage_projects"),
                               sub: tr("profile.nav.manage_projects.sub", repositoryApp.projects.count, budget)) { onNav("manageProjects") }
                        Divider().opacity(0.4)
                        navRow(icon: "shield.fill",  label: tr("profile.nav.permissions"),
                               sub: tr("profile.nav.permissions.sub", repositoryApp.members.count)) { onNav("permissions") }
                    }
                }
            }

            if role == .finance || role == .admin {
                sectionHeader(tr("profile.section.finance"))
                GlassCard(padding: 0) {
                    navRow(icon: "banknote.fill", label: tr("profile.nav.reimbursement_queue"),
                           sub: tr("profile.nav.reimbursement_queue.sub")) { onNav("review") }
                }
            }

            sectionHeader(tr("profile.section.account"))
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    navRow(icon: "list.bullet",    label: tr("profile.nav.activity"),
                           sub: tr("profile.nav.activity.sub")) { onNav("activity") }
                    Divider().opacity(0.4)
                    navRow(icon: "bell.fill",      label: tr("profile.nav.notifications"),
                           sub: tr("profile.nav.notifications.sub")) { onNav("notifications") }
                    Divider().opacity(0.4)
                    navRow(icon: "person.crop.circle.fill", label: tr("profile.nav.account"),
                           sub: tr("profile.nav.account.sub")) { onNav("account") }
                    Divider().opacity(0.4)
                    navRow(icon: "lock.fill", label: tr("profile.nav.security"),
                           sub: tr("profile.nav.security.sub")) { onNav("security") }
                    Divider().opacity(0.4)
                    navRow(icon: "gearshape.fill", label: tr("profile.nav.preferences"),
                           sub: tr("profile.nav.preferences.sub")) { onNav("preferences") }
                    Divider().opacity(0.4)
                    navRow(icon: "doc.text.fill", label: tr("profile.nav.reports"),
                           sub: tr("profile.nav.reports.sub")) { onNav("reports") }
                    Divider().opacity(0.4)
                    navRow(icon: "questionmark.circle.fill", label: tr("profile.nav.help")) { onNav("help") }
                    Divider().opacity(0.4)
                    navRow(icon: "wand.and.stars",
                           label: tr("profile.nav.tour"),
                           sub: tr("profile.nav.tour.sub")) {
                        NotificationCenter.default.post(name: .replayFeatureTour, object: nil)
                    }
                    Divider().opacity(0.4)
                    navRow(icon: "info.circle.fill", label: tr("profile.nav.legal")) { onNav("legal") }
                }
            }

            sectionHeader(tr("profile.section.access"))
            GlassCard(padding: Tokens.padDense) {
                VStack(alignment: .leading, spacing: 8) {
                    roleScopeRow(tr("role.employee"), tr("role.employee.description"), icon: "person.fill", active: role == .employee)
                    Divider().opacity(0.4)
                    roleScopeRow(tr("role.manager"), tr("role.manager.description"), icon: "checkmark.shield.fill", active: role == .manager)
                    Divider().opacity(0.4)
                    roleScopeRow(tr("role.finance"), tr("role.finance.description"), icon: "banknote.fill", active: role == .finance)
                    Divider().opacity(0.4)
                    roleScopeRow(tr("role.admin"), tr("role.admin.description"), icon: "crown.fill", active: role == .admin)
                }
            }

            GlassCard(padding: 0) {
                navRow(icon: "rectangle.portrait.and.arrow.right",
                       label: tr("profile.signout"), tint: Tokens.rejected, chevron: false) { onSignOut() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    private func roleScopeRow(_ title: String, _ subtitle: String, icon: String, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: active ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(active ? Tokens.approved : Color.secondary.opacity(0.45))
                .font(.system(size: 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(active ? Color.primary : Color.secondary)
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
        case .employee: return tr("role.member")
        case .manager: return tr("role.manager")
        case .finance: return tr("role.finance")
        case .admin: return tr("role.workspace_admin")
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
                        comingSoon: Bool = false,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(comingSoon ? Color.secondary.opacity(0.5) : (tint ?? .secondary))
                    .frame(width: 32, height: 32)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(label)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundStyle(comingSoon ? Color.secondary : (tint ?? .primary))
                        if comingSoon {
                            Text(tr("common.coming_soon"))
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.4)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.primary.opacity(0.08), in: Capsule())
                        }
                    }
                    if let sub {
                        Text(sub).font(.system(size: 11)).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                if chevron && !comingSoon {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .opacity(comingSoon ? 0.55 : 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(comingSoon)
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
        settingsContainer(
            title: tr("notifications.title"),
            onBack: onBack,
            trailing: {
                if unreadCount > 0 {
                    Button {
                        Task { await repositoryApp.markAllNotificationsRead() }
                    } label: {
                        Text(tr("notifications.mark_all_read"))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Tokens.pending)
                    }
                    .buttonStyle(.plain)
                }
            }
        ) {
            HStack(spacing: 8) {
                filterChip(tr("notifications.filter.all"), selected: filter == .all) { filter = .all }
                filterChip(tr("notifications.filter.approvals"), selected: filter == .approvals) { filter = .approvals }
                filterChip(tr("notifications.filter.payments"), selected: filter == .payments) { filter = .payments }
                filterChip(tr("notifications.filter.admin"), selected: filter == .admin) { filter = .admin }
            }

            GlassCard(padding: 0) {
                if filteredNotifications.isEmpty {
                    emptyNotifications
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredNotifications.enumerated()), id: \.element.id) { idx, item in
                            if idx > 0 { Divider().opacity(0.4) }
                            SwipeToDelete(
                                deleteLabel: tr("notifications.delete"),
                                onDelete: {
                                    guard let domainId = item.domainId else { return }
                                    Task { await repositoryApp.deleteNotification(id: domainId) }
                                }
                            ) {
                                notificationRow(item)
                            }
                        }
                    }
                }
            }

            infoBanner(icon: "bell.badge.fill", tint: repositoryApp.selectedWorkspace?.brandColor ?? app.company.color,
                       title: tr("notifications.unread_summary", unreadCount),
                       message: tr("notifications.unread_message"))

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
            Text(tr("notifications.empty.title"))
                .font(.system(size: 15, weight: .semibold))
            Text(tr("notifications.empty.subtitle"))
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
                        Text(tr("notifications.new_badge")).font(.system(size: 9, weight: .semibold)).foregroundStyle(Tokens.pending)
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

    @MainActor
    var label: String {
        switch self {
        case .approval: return tr("notifications.kind.approval")
        case .expense: return tr("notifications.kind.expense")
        case .payment: return tr("notifications.kind.payment")
        case .admin: return tr("notifications.kind.admin")
        }
    }
}

struct NotificationDetailSheet: View {
    let notification: AppNotification
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Circle().fill(notification.tint)
                    .frame(width: 10, height: 10)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 6) {
                    Text(notification.title).font(.system(size: 20, weight: .bold))
                    Text(notification.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(notification.kind.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(notification.tint)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(notification.tint.opacity(0.12), in: Capsule())
                        Text(notification.time)
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

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

        settingsContainer(title: tr("account.title"), onBack: onBack) {
            GlassCard(padding: Tokens.padHero) {
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
                        Text(displayName.isEmpty ? tr("profile.add_name") : displayName)
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

            GlassCard(padding: Tokens.padCard) {
                VStack(spacing: 0) {
                    editableSetting(tr("account.name"), text: $name)
                    Divider().opacity(0.4)
                    FormFieldRow(label: tr("account.email"), value: app.userEmail, showChevron: false)
                    Divider().opacity(0.4)
                    FormFieldRow(label: tr("account.workspace"), value: repositoryApp.selectedWorkspace?.name ?? app.company.name, showChevron: false)
                }
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                           title: tr("account.save_failed"), message: lastError)
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
                Text(tr("account.save")).primaryActionLabel()
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
        settingsContainer(title: tr("security.title"), onBack: onBack) {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    Button { showPasswordSheet = true } label: {
                        securityRow(tr("security.change_password"), tr("security.change_password.sub"), "key.fill", chevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                    Button {
                        Task {
                            if await repositoryApp.requestPasswordReset(email: app.userEmail) {
                                await MainActor.run { statusMessage = tr("security.reset_email.sent", app.userEmail) }
                            }
                        }
                    } label: {
                        securityRow(tr("security.reset_email"), tr("security.reset_email.sub", app.userEmail), "envelope.fill", chevron: true)
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4)
                    Button {
                        Task {
                            let ok = await repositoryApp.signOutAllSessions()
                            if ok {
                                await MainActor.run {
                                    statusMessage = tr("security.signout_all.done")
                                    app.signOut()
                                }
                            }
                        }
                    } label: {
                        securityRow(tr("security.signout_all"), tr("security.signout_all.sub"), "rectangle.portrait.and.arrow.right.fill", chevron: true, tint: Tokens.rejected)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let statusMessage {
                infoBanner(icon: "checkmark.seal.fill", tint: Tokens.approved,
                           title: tr("common.done"), message: statusMessage)
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                           title: tr("security.failed"), message: lastError)
            }
        }
        .sheet(isPresented: $showPasswordSheet) {
            ChangePasswordSheet { newPassword in
                Task {
                    if await repositoryApp.updatePassword(newPassword) {
                        await MainActor.run {
                            statusMessage = tr("common.success")
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
            Text(tr("security.change_password")).font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            GlassCard(padding: Tokens.padCard) {
                VStack(spacing: 0) {
                    HStack {
                        Text(tr("security.password.new")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        SecureField(tr("security.password.hint"), text: $newPassword)
                            .font(.system(size: 13.5, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }
                    .padding(.vertical, 11)
                    Divider().opacity(0.4)
                    HStack {
                        Text(tr("security.password.confirm")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        SecureField(tr("security.password.reenter"), text: $confirm)
                            .font(.system(size: 13.5, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }
                    .padding(.vertical, 11)
                }
            }
            .padding(.horizontal, 20)

            if !confirm.isEmpty && newPassword != confirm {
                Text(tr("security.password.mismatch"))
                    .font(.system(size: 12)).foregroundStyle(Tokens.rejected)
                    .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                onSubmit(newPassword)
            } label: {
                Text(tr("common.save")).primaryActionLabel()
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
    @ObservedObject private var localization = LocalizationManager.shared
    var onBack: () -> Void
    @AppStorage("pref.compactLists") private var compactMode = false

    var body: some View {
        settingsContainer(title: tr("preferences.title"), onBack: onBack) {
            // Language picker — primary control, sits at the top so users
            // can find it without scrolling.
            GlassCard(padding: Tokens.padCard) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("preferences.language"))
                        .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    Picker(tr("preferences.language"), selection: Binding(
                        get: { localization.language },
                        set: { localization.setLanguage($0) }
                    )) {
                        ForEach(LocalizationManager.Language.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(tr("preferences.language.note"))
                        .font(.system(size: 11)).foregroundStyle(.tertiary)
                }
            }

            GlassCard(padding: Tokens.padCard) {
                VStack(spacing: 0) {
                    FormFieldRow(label: tr("preferences.workspace_currency"),
                                 value: repositoryApp.selectedWorkspace?.defaultCurrency ?? "USD",
                                 showChevron: false)
                    Divider().opacity(0.4)
                    ToggleRow(label: tr("preferences.compact_lists"),
                              sub: tr("preferences.compact_lists.sub"),
                              isOn: $compactMode)
                }
            }
            infoBanner(icon: "info.circle.fill", tint: Tokens.slate500,
                       title: tr("preferences.workspace_settings"),
                       message: tr("preferences.workspace_settings.message"))
        }
    }
}

struct ReportsExportView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onBack: () -> Void

    // Filters
    @State private var fromDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var toDate: Date = Date()
    @State private var useDateRange: Bool = false
    @State private var searchText: String = ""
    @State private var selectedProjectId: String? = nil
    @State private var selectedStatus: ExpenseWorkflowStatus? = nil

    // Output
    @State private var pdfFile: URL? = nil
    @State private var csvFile: URL? = nil
    @State private var isExporting = false
    @State private var exportError: String? = nil

    // Filtered set drives both the preview and the export buttons.
    private var filteredExpenses: [DomainExpense] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return repositoryApp.expenses.filter { expense in
            if useDateRange {
                let date = expense.purchaseDate ?? expense.submittedAt ?? expense.createdAt
                let lower = Calendar.current.startOfDay(for: fromDate)
                let upper = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: toDate)) ?? toDate
                if date < lower || date >= upper { return false }
            }
            if let projectId = selectedProjectId, expense.projectId != projectId { return false }
            if let status = selectedStatus, expense.status != status { return false }
            if !trimmedSearch.isEmpty {
                let haystack = "\(expense.merchant) \(expense.businessPurpose)".lowercased()
                if !haystack.contains(trimmedSearch) { return false }
            }
            return true
        }
    }

    private var filteredTotal: Double {
        // Re-project to the workspace currency so the preview total matches what the PDF prints.
        let ids = Set(filteredExpenses.map(\.id))
        return repositoryApp.expensesInDefaultCurrency
            .filter { ids.contains($0.id) }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    var body: some View {
        settingsContainer(title: tr("reports.title"), onBack: onBack) {
            if repositoryApp.expenses.isEmpty {
                infoBanner(icon: "tray", tint: Tokens.slate500,
                           title: tr("reports.empty.title"),
                           message: tr("reports.empty.subtitle"))
            } else {
                filtersCard
                previewCard
                exportButtons
                if let err = exportError {
                    infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                               title: tr("reports.export_failed"),
                               message: err)
                }
                shareLinks
            }
        }
    }

    // MARK: – Filters

    private var filtersCard: some View {
        GlassCard(padding: Tokens.padCard) {
            VStack(alignment: .leading, spacing: 12) {
                // Date range
                HStack {
                    Text(tr("reports.filter.date_range"))
                        .font(.system(size: 11, weight: .semibold)).tracking(0.4)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Toggle("", isOn: $useDateRange).labelsHidden()
                }
                if useDateRange {
                    HStack(spacing: 10) {
                        DatePicker(tr("reports.filter.from"), selection: $fromDate, in: ...toDate, displayedComponents: .date)
                            .labelsHidden()
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary).font(.system(size: 11))
                        DatePicker(tr("reports.filter.to"), selection: $toDate, in: fromDate..., displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                    }
                }

                Divider().opacity(0.4)

                // Search
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.tertiary).font(.system(size: 12))
                    TextField(tr("reports.filter.search"), text: $searchText)
                        .font(.system(size: 13))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    if !searchText.isEmpty {
                        Button { searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().opacity(0.4)

                // Project + Status pickers
                HStack(spacing: 8) {
                    Menu {
                        Button(tr("reports.filter.all_projects")) { selectedProjectId = nil }
                        Divider()
                        ForEach(repositoryApp.projects, id: \.id) { project in
                            Button(project.name) { selectedProjectId = project.id }
                        }
                    } label: {
                        filterPill(
                            icon: "folder",
                            label: selectedProjectId.flatMap { id in repositoryApp.projects.first(where: { $0.id == id })?.name }
                                ?? tr("reports.filter.all_projects"),
                            highlighted: selectedProjectId != nil
                        )
                    }

                    Menu {
                        Button(tr("reports.filter.all_statuses")) { selectedStatus = nil }
                        Divider()
                        ForEach(ExpenseWorkflowStatus.allCases, id: \.self) { status in
                            Button(status.displayLabel) { selectedStatus = status }
                        }
                    } label: {
                        filterPill(
                            icon: "checkmark.seal",
                            label: selectedStatus?.displayLabel ?? tr("reports.filter.all_statuses"),
                            highlighted: selectedStatus != nil
                        )
                    }

                    Spacer()

                    if hasActiveFilters {
                        Button { resetFilters() } label: {
                            Text(tr("reports.filter.reset"))
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Tokens.slate500)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var hasActiveFilters: Bool {
        useDateRange || !searchText.isEmpty || selectedProjectId != nil || selectedStatus != nil
    }

    private func resetFilters() {
        useDateRange = false
        searchText = ""
        selectedProjectId = nil
        selectedStatus = nil
    }

    private func filterPill(icon: String, label: String, highlighted: Bool) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            Text(label).font(.system(size: 11.5, weight: .medium)).lineLimit(1)
            Image(systemName: "chevron.down").font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(highlighted ? Tokens.slate500 : Color.primary.opacity(0.7))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(
            (highlighted ? Tokens.slate500.opacity(0.12) : Color.primary.opacity(0.06)),
            in: Capsule()
        )
    }

    // MARK: – Preview

    private var previewCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                HStack {
                    Text(tr("reports.preview.count", filteredExpenses.count))
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text(money(filteredTotal, currency: repositoryApp.aggregationCurrency))
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 14).padding(.vertical, 10)

                if filteredExpenses.isEmpty {
                    Divider().opacity(0.4)
                    Text(tr("reports.preview.empty"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 18)
                } else {
                    // Show up to 8 rows in the preview to keep the screen scrollable.
                    // The export still uses the full filtered set.
                    ForEach(Array(filteredExpenses.prefix(8).enumerated()), id: \.element.id) { _, e in
                        Divider().opacity(0.4)
                        previewRow(e)
                    }
                    if filteredExpenses.count > 8 {
                        Divider().opacity(0.4)
                        Text("+ \(filteredExpenses.count - 8) more")
                            .font(.system(size: 11)).foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                }
            }
        }
    }

    private func previewRow(_ e: DomainExpense) -> some View {
        let date = e.purchaseDate ?? e.submittedAt ?? e.createdAt
        return HStack(spacing: 10) {
            Text(Self.previewDateFormatter.string(from: date))
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)
            Text(e.merchant).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
            Spacer()
            Text(e.amount.formatted).font(.system(size: 12, weight: .semibold))
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
    }

    private static let previewDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "MMM d"
        return df
    }()

    // MARK: – Export actions

    private var exportButtons: some View {
        HStack(spacing: 10) {
            Button { Task { await runPDFExport() } } label: {
                HStack(spacing: 8) {
                    if isExporting {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    } else {
                        Image(systemName: "doc.richtext.fill")
                    }
                    Text(isExporting ? tr("reports.exporting") : tr("reports.export_pdf"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(14)
                .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(filteredExpenses.isEmpty || isExporting)
            .opacity(filteredExpenses.isEmpty ? 0.5 : 1)

            Button { csvFile = makeCSVFile() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tablecells")
                    Text(tr("reports.export_csv"))
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.primary)
                .frame(maxWidth: .infinity).padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(filteredExpenses.isEmpty)
            .opacity(filteredExpenses.isEmpty ? 0.5 : 1)
        }
    }

    @ViewBuilder
    private var shareLinks: some View {
        if let pdfFile {
            ShareLink(item: pdfFile) {
                shareRow(icon: "doc.richtext.fill", tint: Tokens.approved, fileName: pdfFile.lastPathComponent)
            }
            .glassSurface(corner: 18)
        }
        if let csvFile {
            ShareLink(item: csvFile) {
                shareRow(icon: "paperplane.fill", tint: Tokens.slate500, fileName: csvFile.lastPathComponent)
            }
            .glassSurface(corner: 18)
        }
    }

    private func shareRow(icon: String, tint: Color, fileName: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(tr("reports.share", fileName))
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Color.primary)
                Text(tr("reports.share.subtitle"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: – PDF build (fetches receipts then renders)

    private func runPDFExport() async {
        guard !filteredExpenses.isEmpty else { return }
        isExporting = true
        exportError = nil
        defer { isExporting = false }

        // Resolve the rows: project/category labels + receipt image (if any).
        // Pulling all attachments + downloading their bytes is the slowest step;
        // we run them serially so we don't slam the storage bucket with N parallel
        // requests for a large export. For ~50 expenses this is still fast enough.
        let projectsById = Dictionary(uniqueKeysWithValues: repositoryApp.projects.map { ($0.id, $0.name) })
        var rows: [ReportPDFRenderer.Row] = []
        for expense in filteredExpenses {
            let projectName = projectsById[expense.projectId] ?? "—"
            let categoryName = repositoryApp.displayCategoryName(forId: expense.categoryId)
            let image = await fetchReceiptImage(for: expense)
            rows.append(.init(
                expense: expense,
                projectName: projectName,
                categoryName: categoryName,
                receiptImage: image
            ))
        }

        let range: ClosedRange<Date>? = useDateRange ? fromDate...toDate : nil
        let renderContext = ReportPDFRenderer.Context(
            workspaceName: repositoryApp.selectedWorkspace?.name ?? app.company.name,
            aggregationCurrency: repositoryApp.aggregationCurrency,
            dateRange: range,
            rows: rows,
            totalInAggregationCurrency: filteredTotal
        )

        let pdfData = ReportPDFRenderer.render(renderContext)
        do {
            let stamp = filenameStamp()
            let workspaceSlug = (repositoryApp.selectedWorkspace?.name ?? "expenses")
                .lowercased().replacingOccurrences(of: " ", with: "-")
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(workspaceSlug)-statement-\(stamp).pdf")
            try pdfData.write(to: url, options: .atomic)
            pdfFile = url
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Picks the most-relevant receipt for the expense and returns its image,
    /// or nil if none can be loaded (no attachment, or it's a PDF, or download fails).
    /// Priority: reimbursementProof > purchaseReceipt > submittedReceipt > supportingDocument.
    private func fetchReceiptImage(for expense: DomainExpense) async -> UIImage? {
        let attachments = await repositoryApp.listAttachments(for: expense.id)
        guard !attachments.isEmpty else { return nil }
        let priority: [ExpenseAttachment.Kind] = [.reimbursementProof, .purchaseReceipt, .submittedReceipt, .supportingDocument]
        let sorted = priority.compactMap { kind in attachments.first { $0.kind == kind } }
        for attachment in sorted {
            // Only embed image attachments. PDFs aren't rasterised here; they'd
            // need PDFKit to draw, which is doable but adds complexity. Skipping
            // for now leaves the row in the table without a receipt page.
            guard attachment.contentType.hasPrefix("image/") else { continue }
            if let data = await repositoryApp.downloadAttachment(attachment),
               let image = UIImage(data: data) {
                return image
            }
        }
        return nil
    }

    // MARK: – CSV build (respects current filter)

    private func makeCSVFile() -> URL? {
        let projectsById = Dictionary(uniqueKeysWithValues: repositoryApp.projects.map { ($0.id, $0.name) })
        var rows: [String] = ["id,date,project,category,merchant,amount,currency,status"]
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        for e in filteredExpenses {
            let date = e.submittedAt ?? e.purchaseDate ?? e.createdAt
            let project = projectsById[e.projectId] ?? e.projectId
            let category = repositoryApp.categoryName(forId: e.categoryId)
            let amount = String(format: "%.2f", e.amount.decimalValue)
            let cols = [e.id, iso.string(from: date), project, category, e.merchant, amount, e.amount.currency, e.status.rawValue]
            rows.append(cols.map(csvEscape).joined(separator: ","))
        }
        let csv = rows.joined(separator: "\n").appending("\n")
        let stamp = filenameStamp()
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

    private func filenameStamp() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmm"
        return df.string(from: Date())
    }
}

struct HelpSupportView: View {
    var onBack: () -> Void

    var body: some View {
        settingsContainer(title: tr("help.title"), onBack: onBack) {
            GlassCard(padding: Tokens.padCard) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("help.workflow_title")).font(.system(size: 13.5, weight: .semibold))
                    Text(tr("help.workflow_body"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }

            Link(destination: URL(string: "mailto:support@turfmapp.io?subject=Expenses%20app%20support")!) {
                GlassCard(padding: Tokens.padDense) {
                    HStack(spacing: 12) {
                        Image(systemName: "envelope.fill")
                            .foregroundStyle(Tokens.slate500)
                            .frame(width: 30, height: 30)
                            .background(Tokens.slate500.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("help.contact")).font(.system(size: 13.5, weight: .semibold))
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
        settingsContainer(title: tr("states.title"), onBack: onBack) {
            stateCard(icon: "hourglass", title: tr("states.loading.title"), message: tr("states.loading.message"), tint: Tokens.slate500)
            stateCard(icon: "wifi.slash", title: tr("states.offline.title"), message: tr("states.offline.message"), tint: Tokens.pending)
            stateCard(icon: "exclamationmark.triangle.fill", title: tr("states.failed.title"), message: tr("states.failed.message"), tint: Tokens.rejected)
            stateCard(icon: "tray", title: tr("states.empty.title"), message: tr("states.empty.message"), tint: Tokens.approved)
        }
    }

    private func stateCard(icon: String, title: String, message: String, tint: Color) -> some View {
        GlassCard(padding: Tokens.padDense) {
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

    /// Marketing version (CFBundleShortVersionString) — what users recognise
    /// as "1.2". Falls back to "—" only if the plist key is missing, which
    /// shouldn't happen in any shipped build.
    private var marketingVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    /// Build number (CFBundleVersion) — increments per TestFlight upload.
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        settingsContainer(title: tr("legal.title"), onBack: onBack) {
            GlassCard(padding: Tokens.padCard) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(tr("legal.app_name")).font(.system(size: 18, weight: .bold))
                    Text(tr("legal.version", marketingVersion)).font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    FormFieldRow(label: tr("legal.build"), value: "\(marketingVersion) (\(buildNumber))", showChevron: false)
                    Divider().opacity(0.4)
                    FormFieldRow(label: tr("legal.backend"), value: "Supabase", showChevron: false)
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

        settingsContainer(title: tr("workspace.title"), onBack: onBack) {
            GlassCard(padding: Tokens.padHero) {
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
                        Text(tr("workspace.tap_logo"))
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
                           title: tr("workspace.update_failed"), message: lastError)
            }

            GlassCard(padding: Tokens.padCard) {
                VStack(spacing: 0) {
                    HStack {
                        Text(tr("workspace.name")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        TextField(tr("workspace.name.placeholder"), text: $nameDraft)
                            .font(.system(size: 13.5, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 220)
                    }
                    .padding(.vertical, 11)
                    Divider().opacity(0.4)
                    HStack {
                        Text(tr("workspace.default_currency")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        Picker(tr("workspace.default_currency"), selection: $currencyDraft) {
                            ForEach(Self.currencyOptions, id: \.self) { c in
                                Text(c).tag(c)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .padding(.vertical, 8)
                    Divider().opacity(0.4)
                    FormFieldRow(label: tr("workspace.workspace_id"),
                                 value: String((workspace?.id ?? "").prefix(8)) + "…",
                                 showChevron: false)
                }
            }

            if let saveStatus {
                infoBanner(icon: "checkmark.seal.fill", tint: Tokens.approved,
                           title: tr("common.success"), message: saveStatus)
            }

            Button {
                let trimmed = nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                Task {
                    savingDetails = true
                    let ok = await repositoryApp.updateWorkspace(name: trimmed, defaultCurrency: currencyDraft)
                    await MainActor.run {
                        savingDetails = false
                        if ok { saveStatus = tr("workspace.saved") }
                    }
                }
            } label: {
                Text(savingDetails ? tr("workspace.saving") : tr("workspace.save_changes")).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity((nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      (nameDraft == (workspace?.name ?? "") && currencyDraft == (workspace?.defaultCurrency ?? "USD")) ||
                      savingDetails) ? 0.5 : 1)
            .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                      (nameDraft == (workspace?.name ?? "") && currencyDraft == (workspace?.defaultCurrency ?? "USD")) ||
                      savingDetails)

            infoBanner(icon: "info.circle.fill", tint: Tokens.slate500,
                       title: tr("workspace.per_project_policy"),
                       message: tr("workspace.per_project_policy.message"))
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
    settingsContainer(title: title, onBack: onBack, trailing: { EmptyView() }, content: content)
}

@MainActor
func settingsContainer<Trailing: View, Content: View>(
    title: String,
    onBack: @escaping () -> Void,
    @ViewBuilder trailing: () -> Trailing,
    @ViewBuilder content: () -> Content
) -> some View {
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
            Spacer()
            trailing()
        }
        .padding(.horizontal, 4).padding(.top, 4)

        content()
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 100)
}

/// Row wrapper that reveals a destructive action on left-swipe.
///
/// SwiftUI's built-in `.swipeActions` only works inside `List`, but the
/// notifications inbox sits in a `GlassCard` + `VStack` to keep the glass
/// aesthetic. This component reproduces the mail-style left-swipe gesture
/// with `DragGesture`: the row slides under a red "Delete" tab, snaps open
/// past the threshold, and fires `onDelete` if the swipe is forceful enough
/// (or the tab is tapped).
struct SwipeToDelete<Content: View>: View {
    let deleteLabel: String
    let onDelete: () -> Void
    let content: Content

    @State private var offset: CGFloat = 0
    @State private var committedOffset: CGFloat = 0
    @GestureState private var isDragging: Bool = false

    private let actionWidth: CGFloat = 84
    private let revealThreshold: CGFloat = 30
    private let commitThreshold: CGFloat = 160

    init(deleteLabel: String, onDelete: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.deleteLabel = deleteLabel
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Background action tab — only takes the space we've revealed.
            Button {
                fireDelete()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "trash.fill").font(.system(size: 14, weight: .semibold))
                    Text(deleteLabel).font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: actionWidth)
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }
            .buttonStyle(.plain)
            .opacity(min(1, -offset / actionWidth))

            content
                .background(Color.clear)
                .contentShape(Rectangle())
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 8)
                        .updating($isDragging) { _, state, _ in state = true }
                        .onChanged { value in
                            let proposed = committedOffset + value.translation.width
                            // Allow a little stretch past the action width, but not unbounded.
                            offset = min(0, max(-(actionWidth + 40), proposed))
                        }
                        .onEnded { value in
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                if value.translation.width < -commitThreshold {
                                    // Full swipe → commit delete.
                                    offset = -actionWidth
                                    committedOffset = -actionWidth
                                    fireDelete()
                                } else if offset < -revealThreshold {
                                    // Held open at the delete tab.
                                    offset = -actionWidth
                                    committedOffset = -actionWidth
                                } else {
                                    // Snap back closed.
                                    offset = 0
                                    committedOffset = 0
                                }
                            }
                        }
                )
        }
        .clipped()
    }

    private func fireDelete() {
        withAnimation(.easeOut(duration: 0.18)) {
            offset = -(actionWidth + 40)
            committedOffset = offset
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            onDelete()
        }
    }
}
