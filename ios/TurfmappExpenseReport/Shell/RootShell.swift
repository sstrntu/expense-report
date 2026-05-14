import SwiftUI

struct RootShell: View {
    @StateObject private var app = AppState()
    @StateObject private var repositoryApp = RepositoryAppState()
    @State private var selectedTab: TabID = .home
    @State private var navStack: [NavRoute] = []
    @State private var showNotifications = false

    var body: some View {
        if !app.isAuthenticated {
            AuthView()
                .environmentObject(app)
                .appBackground()
        } else if app.needsSetup && !app.profileComplete {
            ProfileSetupView()
                .environmentObject(app)
                .appBackground()
        } else if app.needsSetup && !app.workspaceReady {
            WorkspaceSetupView()
                .environmentObject(app)
                .environmentObject(repositoryApp)
                .appBackground()
        } else {
            appShell
                .environmentObject(repositoryApp)
        }
    }

    private var appShell: some View {
        ZStack(alignment: .bottom) {
            // Background with decorative blobs
            appBg.ignoresSafeArea()

            // Top company bar
            VStack {
                topBar
                Spacer()
            }
            .zIndex(10)

            // Content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 90) // top bar clearance
                    screenContent
                }
            }
            .zIndex(5)

            // Bottom tab bar (hidden when on add/stack screens)
            if navStack.isEmpty && selectedTab != .add {
                BottomTabBar(selected: $selectedTab, role: app.role)
                    .padding(.bottom, 28)
                    .zIndex(20)
            }
        }
        .onChange(of: app.role) { _, _ in
            selectedTab = .home
            navStack = []
        }
        .task {
            await repositoryApp.bootstrap()
        }
        .overlay {
            if showNotifications {
                NotificationsView {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { showNotifications = false }
                }
                .environmentObject(app)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.02, anchor: UnitPoint(x: 0.9, y: 0.06))
                        .combined(with: .opacity),
                    removal: .scale(scale: 0.02, anchor: UnitPoint(x: 0.9, y: 0.06))
                        .combined(with: .opacity)
                ))
            }
        }
    }

    @ViewBuilder
    private var screenContent: some View {
        if let route = navStack.last {
            routeView(route)
        } else {
            tabView
        }
    }

    @ViewBuilder
    private var tabView: some View {
        switch selectedTab {
        case .home:
            if app.role != .employee {
                ManagerOverviewView { selectedTab = .review }
                    .environmentObject(app)
            } else {
                HomeView(selectedTab: $selectedTab) { e in
                    navStack.append(.domainDetail(e))
                }
                .environmentObject(app)
            }
        case .dashboard:
            DashboardView()
                .environmentObject(app)
        case .add:
            SubmitView(onClose: { selectedTab = .home }, onSubmit: { selectedTab = .activity })
                .environmentObject(app)
        case .activity:
            ActivityView { e in navStack.append(.domainDetail(e)) }
                .environmentObject(app)
        case .review:
            ReviewView { e in navStack.append(.domainDetail(e)) }
                .environmentObject(app)
        case .profile:
            ProfileView(role: app.role, onSignOut: app.signOut) { key in
                if key == "manageProjects" { navStack.append(.manageProjects) }
                if key == "permissions"    { navStack.append(.permissions) }
                if key == "notifications"  { navStack.append(.notifications) }
                if key == "account"        { navStack.append(.accountSettings) }
                if key == "security"       { navStack.append(.securitySettings) }
                if key == "preferences"    { navStack.append(.appPreferences) }
                if key == "reports"        { navStack.append(.reports) }
                if key == "systemStates"   { navStack.append(.systemStates) }
                if key == "help"           { navStack.append(.help) }
                if key == "legal"          { navStack.append(.legal) }
            }
            .environmentObject(app)
        }
    }

    @ViewBuilder
    private func routeView(_ route: NavRoute) -> some View {
        switch route {
        case .detail(let e):
            DetailView(expense: e, role: app.role,
                       onBack: { navStack.removeLast() },
                       onAction: { status, method, receipt in
                           syncRepositoryAction(expense: e, status: status, method: method, receipt: receipt)
                           app.updateStatus(id: e.id, to: status, paymentMethod: method, paymentReceipt: receipt)
                           navStack.removeLast()
                       },
                       onArchive: {
                           Task { await repositoryApp.archiveExpense(id: e.id) }
                           app.archiveExpense(id: e.id)
                           navStack.removeLast()
                       },
                       onDelete: {
                           Task { await repositoryApp.deleteExpense(id: e.id) }
                           app.deleteExpense(id: e.id)
                           navStack.removeLast()
                       })
        case .domainDetail(let e):
            DomainDetailView(
                expense: e,
                projects: repositoryApp.projects,
                events: repositoryApp.eventsByExpenseId[e.id] ?? [],
                role: app.role,
                onBack: { navStack.removeLast() },
                onApprove: {
                    Task { await repositoryApp.approveExpense(id: e.id) }
                    app.updateStatus(id: e.id, to: .approved)
                    navStack.removeLast()
                },
                onReject: { reason in
                    Task { await repositoryApp.rejectExpense(id: e.id, reason: reason) }
                    app.updateStatus(id: e.id, to: .rejected)
                    navStack.removeLast()
                },
                onResubmit: {
                    Task { await repositoryApp.resubmitExpense(id: e.id) }
                    app.updateStatus(id: e.id, to: .pending)
                    navStack.removeLast()
                },
                onCancel: {
                    Task { await repositoryApp.cancelExpense(id: e.id, reason: "Cancelled by submitter.") }
                    app.updateStatus(id: e.id, to: .rejected)
                    navStack.removeLast()
                },
                onConfirmPurchase: { finalAmount, receipt in
                    Task {
                        let attachment = await uploadActionAttachment(
                            expenseId: e.id,
                            fileName: receipt,
                            kind: .purchaseReceipt
                        )
                        await repositoryApp.confirmPurchase(
                            id: e.id,
                            input: PurchaseConfirmationInput(
                                finalAmount: finalAmount,
                                purchaseDate: Date(),
                                receiptAttachmentId: attachment?.id,
                                note: receipt
                            )
                        )
                    }
                    app.updateStatus(id: e.id, to: .purchased, paymentReceipt: receipt)
                    navStack.removeLast()
                },
                onMarkReimbursed: { method, receipt in
                    Task {
                        let attachment = await uploadActionAttachment(
                            expenseId: e.id,
                            fileName: receipt,
                            kind: .reimbursementProof
                        )
                        await repositoryApp.markReimbursed(
                            id: e.id,
                            input: ReimbursementInput(
                                amount: e.amount,
                                paymentMethod: method.repositoryMethod,
                                paidAt: Date(),
                                reference: receipt,
                                proofAttachmentId: attachment?.id
                            )
                        )
                    }
                    app.updateStatus(id: e.id, to: .reimbursed, paymentMethod: method, paymentReceipt: receipt)
                    navStack.removeLast()
                },
                onArchive: {
                    Task {
                        if e.isArchived {
                            await repositoryApp.unarchiveExpense(id: e.id)
                        } else {
                            await repositoryApp.archiveExpense(id: e.id)
                        }
                    }
                    app.archiveExpense(id: e.id)
                    navStack.removeLast()
                },
                onDelete: {
                    Task { await repositoryApp.deleteExpense(id: e.id) }
                    app.deleteExpense(id: e.id)
                    navStack.removeLast()
                }
            )
        case .manageProjects:
            ManageProjectsView { navStack.removeLast() }
                .environmentObject(app)
        case .permissions:
            PermissionsView { navStack.removeLast() }
                .environmentObject(app)
        case .notifications:
            NotificationsView { navStack.removeLast() }
                .environmentObject(app)
        case .accountSettings:
            AccountSettingsView { navStack.removeLast() }
                .environmentObject(app)
        case .securitySettings:
            SecuritySettingsView { navStack.removeLast() }
        case .appPreferences:
            AppPreferencesView { navStack.removeLast() }
        case .reports:
            ReportsExportView { navStack.removeLast() }
                .environmentObject(app)
        case .systemStates:
            SystemStatesView { navStack.removeLast() }
        case .help:
            HelpSupportView { navStack.removeLast() }
        case .legal:
            LegalAboutView { navStack.removeLast() }
        }
    }

    private var topBar: some View {
        let selectedWorkspace = repositoryApp.selectedWorkspace

        return HStack {
            // Workspace picker — opens a dropdown menu
            Menu {
                ForEach(repositoryApp.workspaces, id: \.id) { workspace in
                    Button {
                        Task {
                            await repositoryApp.selectWorkspace(id: workspace.id)
                            await MainActor.run {
                                app.company = workspace.legacyCompany
                                app.role = workspace.currentUserRole.appRole
                                selectedTab = .home
                                navStack = []
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(workspace.name)
                                Text(workspace.currentUserRole.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if selectedWorkspace?.id == workspace.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(selectedWorkspace?.brandColor ?? app.company.color)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text(selectedWorkspace?.abbr ?? app.company.abbr)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    Text(selectedWorkspace?.name ?? app.company.name)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
                }
                .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 999)

            Spacer()

            // Notification bell
            Button {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { showNotifications = true }
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16)).foregroundStyle(Color.primary)
                        .frame(width: 38, height: 38)

                    Circle().fill(Tokens.rejected).frame(width: 8, height: 8)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                        .offset(x: -1, y: 2)
                }
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 999)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.ultraThinMaterial.opacity(0))
    }

    private func syncRepositoryAction(expense: Expense, status: ExpenseStatus, method: PaymentMethod?, receipt: String?) {
        Task {
            switch status {
            case .approved:
                await repositoryApp.approveExpense(id: expense.id)
            case .rejected:
                await repositoryApp.rejectExpense(id: expense.id, reason: "Rejected from expense detail.")
            case .purchased:
                await repositoryApp.confirmPurchase(
                    id: expense.id,
                    input: PurchaseConfirmationInput(
                        finalAmount: MoneyAmount(minorUnits: Int((expense.amount * 100).rounded()), currency: "USD"),
                        purchaseDate: Date(),
                        receiptAttachmentId: nil,
                        note: receipt
                    )
                )
            case .reimbursed:
                await repositoryApp.markReimbursed(
                    id: expense.id,
                    input: ReimbursementInput(
                        amount: MoneyAmount(minorUnits: Int((expense.amount * 100).rounded()), currency: "USD"),
                        paymentMethod: method?.repositoryMethod ?? .other,
                        paidAt: Date(),
                        reference: receipt,
                        proofAttachmentId: nil
                    )
                )
            case .pending:
                break
            }
        }
    }

    private func uploadActionAttachment(expenseId: String, fileName: String?, kind: ExpenseAttachment.Kind) async -> ExpenseAttachment? {
        guard let fileName, !fileName.isEmpty else { return nil }
        return await repositoryApp.uploadAttachment(
            expenseId: expenseId,
            upload: PendingReceiptUpload(
                kind: kind,
                fileName: fileName,
                contentType: "application/pdf",
                data: Data("mock-attachment".utf8)
            )
        )
    }

    private var appBg: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xEEF1F8), Color(hex: 0xE4E8F2)],
                           startPoint: .top, endPoint: .bottom)
            Circle().fill(Tokens.slate500.opacity(0.45))
                .frame(width: 300).blur(radius: 70).offset(x: 150, y: -300)
            Circle().fill(Tokens.aiPurple.opacity(0.35))
                .frame(width: 260).blur(radius: 70).offset(x: -140, y: 250)
        }
    }
}

private extension PaymentMethod {
    var repositoryMethod: ReimbursementPaymentMethod {
        switch self {
        case .transfer: return .bankTransfer
        case .qr: return .qrCode
        case .cash: return .cash
        case .card: return .card
        case .cheque: return .cheque
        }
    }
}

// MARK: – Navigation routes

enum NavRoute: Hashable {
    case detail(Expense)
    case domainDetail(DomainExpense)
    case manageProjects
    case permissions
    case notifications
    case accountSettings
    case securitySettings
    case appPreferences
    case reports
    case systemStates
    case help
    case legal
}

// MARK: – Release entry flows

struct AuthView: View {
    @EnvironmentObject var app: AppState
    @State private var email = "sira@turfmapp.com"
    @State private var password = ""
    @State private var mode: AuthMode = .login
    @State private var showReset = false
    @State private var showVerification = false
    @State private var previewCompany: Company = MockData.companies[0]
    @State private var previewRole: AppRole = .employee

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(mode.title)
                    .font(.system(size: 34, weight: .bold))
                Text("Track approvals, purchases, and reimbursements across your workspace.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Picker("Mode", selection: $mode) {
                ForEach(AuthMode.allCases, id: \.self) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                showReset = false
                showVerification = false
            }

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    authField("Email", text: $email, keyboard: .emailAddress)
                    if mode != .preview {
                        Divider().opacity(0.4)
                        secureField("Password", text: $password)
                    }
                }
            }

            if mode == .preview {
                GlassCard(padding: 16) {
                    VStack(spacing: 0) {
                        Picker("Workspace", selection: $previewCompany) {
                            ForEach(MockData.companies, id: \.self) { company in
                                Text(company.name).tag(company)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.vertical, 10)

                        Divider().opacity(0.4)

                        Picker("Role", selection: $previewRole) {
                            ForEach(AppRole.allCases) { role in
                                Text(role.label).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 12)
                    }
                }

                infoBanner(icon: "play.circle.fill", tint: Tokens.slate500,
                           title: "Demo access",
                           message: "Opens the app with a selected workspace and role.")
            }

            if showReset {
                infoBanner(icon: "envelope.fill", tint: Tokens.aiPurple,
                           title: "Password reset sent",
                           message: "Check \(email.isEmpty ? "your email" : email) for a reset link.")
            }

            if showVerification {
                infoBanner(icon: "checkmark.seal.fill", tint: Tokens.approved,
                           title: "Verification required",
                           message: "We will ask new users to confirm their email before joining a workspace.")
            }

            Button {
                if mode == .signup { showVerification = true }
                if mode == .preview {
                    app.company = previewCompany
                    app.signIn(email: email, needsSetup: false, role: previewRole)
                } else {
                    app.signIn(email: email, needsSetup: mode == .signup)
                }
            } label: {
                Text(mode.actionTitle).primaryActionLabel()
            }
            .buttonStyle(.plain)

            HStack {
                if mode == .login {
                    Button("Forgot password?") { showReset = true }
                } else {
                    Button("Back to sign in") { mode = .login }
                }
                Spacer()
                if mode != .preview {
                    Button(mode == .login ? "Create account" : "Use sign in") {
                        mode = mode == .login ? .signup : .login
                        showReset = false
                        showVerification = false
                    }
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tokens.slate500)

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    private func authField(_ label: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: text)
                .font(.system(size: 14, weight: .medium))
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 210)
        }
        .padding(.vertical, 12)
    }

    private func secureField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            SecureField("Password", text: text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 210)
        }
        .padding(.vertical, 12)
    }
}

enum AuthMode {
    case login, signup, preview

    static var allCases: [AuthMode] { [.login, .signup, .preview] }

    var title: String {
        switch self {
        case .login: return "Sign in"
        case .signup: return "Create account"
        case .preview: return "Demo"
        }
    }

    var actionTitle: String {
        switch self {
        case .login: return "Sign in"
        case .signup: return "Create account"
        case .preview: return "Enter demo"
        }
    }
}

struct ProfileSetupView: View {
    @EnvironmentObject var app: AppState
    @State private var name = "Sira Sasitorn"
    @State private var email = "sira@turfmapp.com"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 32)

            Text("Set up profile").font(.system(size: 32, weight: .bold))
            Text("Create the identity teammates will see on requests, approvals, and reimbursement records.")
                .font(.system(size: 14)).foregroundStyle(.secondary)

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    setupField("Full name", text: $name)
                    Divider().opacity(0.4)
                    setupField("Email", text: $email)
                }
            }

            Button {
                app.completeProfile(name: name, email: email)
            } label: {
                Text("Continue").primaryActionLabel()
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    private func setupField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 220)
        }
        .padding(.vertical, 12)
    }
}

struct WorkspaceSetupView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var workspaceName = "Turfmapp"
    @State private var inviteCode = "invite_finance_turfmapp"
    @State private var mode: WorkspaceMode = .create

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 32)

            Text("Workspace").font(.system(size: 32, weight: .bold))
            Text("Create an organization or join one by invite before submitting expenses.")
                .font(.system(size: 14)).foregroundStyle(.secondary)

            GlassCard(padding: 16) {
                Picker("Workspace", selection: $mode) {
                    Text("Create").tag(WorkspaceMode.create)
                    Text("Join").tag(WorkspaceMode.join)
                }
                .pickerStyle(.segmented)
            }

            GlassCard(padding: 16) {
                if mode == .create {
                    VStack(spacing: 0) {
                        setupField("Organization", text: $workspaceName)
                        Divider().opacity(0.4)
                        FormFieldRow(label: "Default currency", value: "USD", showChevron: false)
                    }
                } else {
                    VStack(spacing: 0) {
                        setupField("Invite code", text: $inviteCode)
                        Divider().opacity(0.4)
                        FormFieldRow(label: "Status", value: inviteCode.isEmpty ? "Waiting for invite" : "Ready to join", showChevron: false)
                    }
                }
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.shield.fill", tint: Tokens.rejected,
                           title: "Workspace setup failed",
                           message: lastError)
            }

            infoBanner(icon: "person.2.badge.gearshape.fill", tint: Tokens.slate500,
                       title: "Invite required",
                       message: "If an invite is not accepted yet, this screen keeps the user out of the workspace.")

            Button {
                Task {
                    switch mode {
                    case .create:
                        await repositoryApp.createWorkspace(name: workspaceName, defaultCurrency: "USD")
                    case .join:
                        await repositoryApp.acceptInvite(id: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    if let workspace = repositoryApp.selectedWorkspace {
                        app.company = workspace.legacyCompany
                        app.role = workspace.currentUserRole.appRole
                        app.workspaceReady = true
                    }
                }
            } label: {
                Text(mode == .create ? "Create workspace" : "Join workspace").primaryActionLabel()
            }
            .buttonStyle(.plain)
            .disabled(mode == .join && inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            Spacer()
        }
        .padding(.horizontal, 22)
        .task {
            await repositoryApp.bootstrap()
        }
    }

    private func setupField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            TextField(label, text: text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 210)
        }
        .padding(.vertical, 12)
    }
}

enum WorkspaceMode {
    case create, join
}

func infoBanner(icon: String, tint: Color, title: String, message: String) -> some View {
    HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 24)
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 13.5, weight: .semibold))
            Text(message).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
    .padding(14)
    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
}
