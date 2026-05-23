import SwiftUI

struct RootShell: View {
    @StateObject private var app = AppState()
    @StateObject private var repositoryApp = RepositoryAppState()
    @State private var selectedTab: TabID = .home
    @State private var navStack: [NavRoute] = []
    /// Tracks whether we've finished the launch-time session restore. We
    /// hold the UI on a launch screen during this window so a returning user
    /// doesn't see the AuthView flash before their saved session resolves.
    @State private var launchState: LaunchState = .restoring
    /// When a draft is picked from Home/Overview, this carries the row's id
    /// across to SubmitView so the form opens already populated. Cleared once
    /// SubmitView consumes it, so re-entering the Add tab without picking
    /// again shows the normal blank form.
    @State private var pendingDraftId: String?
    /// Drives the Welcome step. Persisted to UserDefaults so a user who
    /// completes onboarding (or signs out and back in) doesn't see it twice.
    @AppStorage("onboarding.hasSeenWelcome") private var hasSeenWelcome: Bool = false
    /// Same idea for the coach-marks tour: once you finish or skip it, we
    /// don't auto-show again. Profile → Replay app tour resets this manually.
    @AppStorage("tour.completed") private var tourCompleted: Bool = false
    /// Transient: gates the post-workspace celebration screen. We flip it
    /// to true when WorkspaceSetupView finishes, then back to false when
    /// the user taps "Go to Home" or one of the quick-action tiles.
    @State private var showCompletion: Bool = false
    /// Coordinator for the in-app feature tour. Drives tab switches +
    /// holds the captured frames for spotlighted UI elements.
    @StateObject private var tourCoordinator = TourCoordinator()

    private enum LaunchState { case restoring, ready }

    private var tabBadges: [TabID: Int] {
        if app.role == .employee {
            let rejected = repositoryApp.expenses.filter { $0.status == .rejected }.count
            return rejected > 0 ? [.activity: rejected] : [:]
        }
        let queueCount: Int = {
            switch app.role {
            case .finance: return repositoryApp.financeQueue.count
            case .admin:   return repositoryApp.managerQueue.count + repositoryApp.financeQueue.count
            default:       return repositoryApp.managerQueue.count
            }
        }()
        return queueCount > 0 ? [.review: queueCount] : [:]
    }

    var body: some View {
        Group {
            switch launchState {
            case .restoring:
                launchSplash
            case .ready:
                routedBody
            }
        }
        .task {
            await restoreSession()
        }
        // Fire the completion screen exactly once: when the user transitions
        // from "still in setup" → "workspace ready". Returning users (who
        // skipped setup entirely on launch) won't trip this because their
        // workspaceReady flag is set during session restore before the body
        // observers attach.
        .onChange(of: app.workspaceReady) { wasReady, isReady in
            if !wasReady && isReady && app.needsSetup {
                showCompletion = true
                // Setup is done — drop the needsSetup flag so the router doesn't
                // bounce back into the workspace screen.
                app.needsSetup = false
            }
        }
    }

    private var launchSplash: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(tr("shell.loading")).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .appBackground()
    }

    @ViewBuilder
    private var routedBody: some View {
        if !app.isAuthenticated && !hasSeenWelcome {
            WelcomeView(
                onGetStarted: { hasSeenWelcome = true },
                onSignIn: { hasSeenWelcome = true }
            )
                .environmentObject(app)
                .appBackground()
        } else if !app.isAuthenticated {
            AuthView()
                .environmentObject(app)
                .environmentObject(repositoryApp)
                .appBackground()
        } else if app.needsSetup && !app.profileComplete {
            ProfileSetupView()
                .environmentObject(app)
                .environmentObject(repositoryApp)
                .appBackground()
        } else if app.needsSetup && !app.workspaceReady {
            WorkspaceSetupView()
                .environmentObject(app)
                .environmentObject(repositoryApp)
                .appBackground()
        } else if showCompletion {
            OnboardingCompletionView(
                onSubmitExpense: { dismissCompletion(switchingTo: .add, startTour: false) },
                onInviteTeammate: { dismissCompletion(switchingTo: .profile, startTour: false) },
                onBrowseSettings: { dismissCompletion(switchingTo: .profile, startTour: false) },
                onGoHome: { dismissCompletion(switchingTo: .home, startTour: !tourCompleted) }
            )
                .environmentObject(app)
                .environmentObject(repositoryApp)
                .appBackground()
        } else {
            ZStack {
                appShell
                    .environmentObject(repositoryApp)
                    .environmentObject(tourCoordinator)
                if tourCoordinator.isActive {
                    FeatureTour(coordinator: tourCoordinator)
                        .zIndex(100)
                        .transition(.opacity)
                }
            }
            // The coordinator publishes requestedTab when it wants to navigate.
            // We translate that into a selectedTab change here. Wrapping in a
            // tiny delay lets the previous step's UI fully unmount before the
            // next page's .tourTarget modifiers re-emit their frames.
            .onChange(of: tourCoordinator.requestedTab) { _, tab in
                guard let tab else { return }
                selectedTab = tab
            }
            // Latch tourCompleted once we observe the active flag go false.
            // Attaching this above the FeatureTour view (rather than on it)
            // ensures the observer outlives the overlay being removed.
            .onChange(of: tourCoordinator.isActive) { _, active in
                if !active { tourCompleted = true }
            }
            // Pump frames captured by .tourTarget modifiers into the coordinator.
            // The modifier uses onGeometryChange + a shared TourTargetCollector
            // which posts a Notification we listen for here.
            .onReceive(NotificationCenter.default.publisher(for: .tourTargetFrameChanged)) { note in
                guard let target = note.userInfo?["target"] as? TourTarget,
                      let rect = note.userInfo?["rect"] as? CGRect else { return }
                tourCoordinator.frames[target] = rect
            }
            .onReceive(NotificationCenter.default.publisher(for: .replayFeatureTour)) { _ in
                tourCoordinator.start(for: app.role)
            }
        }
    }

    private func dismissCompletion(switchingTo tab: TabID, startTour: Bool) {
        showCompletion = false
        selectedTab = tab
        if startTour {
            // Defer one tick so the appShell renders first; otherwise the
            // overlay's frame lookups run before the page's .tourTarget
            // modifiers have emitted their initial rectangles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                tourCoordinator.start(for: app.role)
            }
        }
    }

    /// Resume the previous session if one is persisted, then hand off to
    /// `routedBody`. If restore fails we land on AuthView the same as a
    /// fresh install.
    private func restoreSession() async {
        if await repositoryApp.restoreSession() {
            await repositoryApp.bootstrap()
            if let workspace = repositoryApp.selectedWorkspace {
                app.signIn(email: repositoryApp.currentUserProfile?.email ?? "",
                           needsSetup: false,
                           role: workspace.currentUserRole.appRole)
                app.company = workspace.legacyCompany
            } else {
                // Authenticated but hasn't created/joined a workspace yet.
                app.signIn(email: repositoryApp.currentUserProfile?.email ?? "",
                           needsSetup: true)
            }
            if let profile = repositoryApp.currentUserProfile {
                if app.userName.isEmpty { app.userName = profile.displayName }
                if app.userEmail.isEmpty { app.userEmail = profile.email }
            }
            Task { await repositoryApp.backfillFXSnapshots() }
        }
        launchState = .ready
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
            .refreshable { await repositoryApp.refresh() }
            .zIndex(5)

            // Bottom tab bar (hidden when on add/stack screens)
            if navStack.isEmpty && selectedTab != .add {
                BottomTabBar(selected: $selectedTab, role: app.role, badgeCounts: tabBadges)
                    .padding(.bottom, 28)
                    .zIndex(20)
            }
        }
        .onChange(of: app.role) { _, _ in
            selectedTab = .home
            navStack = []
        }
        .onChange(of: repositoryApp.currentUserProfile) { _, profile in
            guard let profile else { return }
            if app.userName.isEmpty { app.userName = profile.displayName }
            if app.userEmail.isEmpty { app.userEmail = profile.email }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceTokenReceived)) { note in
            guard let token = note.userInfo?["token"] as? String else { return }
            Task { await repositoryApp.registerDeviceToken(token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .pushNotificationOpened)) { note in
            guard let expenseId = note.userInfo?["expenseId"] as? String else { return }
            openExpenseFromPush(id: expenseId)
        }
    }

    private func openExpenseFromPush(id: String) {
        // Navigate straight to detail if the expense is already loaded;
        // otherwise refresh then navigate (covers cold-start tap).
        if let expense = repositoryApp.expenses.first(where: { $0.id == id }) {
            navStack = [.domainDetail(expense)]
            selectedTab = .activity
        } else {
            Task {
                await repositoryApp.refresh()
                if let expense = repositoryApp.expenses.first(where: { $0.id == id }) {
                    navStack = [.domainDetail(expense)]
                    selectedTab = .activity
                }
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
                ManagerOverviewView(
                    onGoToReview: { selectedTab = .review },
                    onOpenDraft: { id in
                        pendingDraftId = id
                        selectedTab = .add
                    }
                )
                    .environmentObject(app)
            } else {
                HomeView(
                    selectedTab: $selectedTab,
                    onOpenDraft: { id in
                        pendingDraftId = id
                        selectedTab = .add
                    },
                    onOpen: { e in navStack.append(.domainDetail(e)) }
                )
                .environmentObject(app)
            }
        case .dashboard:
            DashboardView { e in navStack.append(.domainDetail(e)) }
                .environmentObject(app)
        case .add:
            SubmitView(
                onClose: { selectedTab = .home },
                onSubmit: { selectedTab = .activity },
                initialDraftId: pendingDraftId,
                onDidLoadInitialDraft: { pendingDraftId = nil }
            )
                .environmentObject(app)
        case .activity:
            ActivityView { e in navStack.append(.domainDetail(e)) }
                .environmentObject(app)
        case .review:
            ReviewView { e in navStack.append(.domainDetail(e)) }
                .environmentObject(app)
        case .profile:
            ProfileView(role: app.role, onSignOut: {
                Task { await repositoryApp.signOut() }
                app.signOut()
            }) { key in
                if key == "manageProjects" { navStack.append(.manageProjects) }
                if key == "permissions"    { navStack.append(.permissions) }
                if key == "workspace"      { navStack.append(.workspaceSettings) }
                if key == "activity"       { navStack.append(.activity) }
                if key == "notifications"  { navStack.append(.notifications) }
                if key == "account"        { navStack.append(.accountSettings) }
                if key == "security"       { navStack.append(.securitySettings) }
                if key == "preferences"    { navStack.append(.appPreferences) }
                if key == "reports"        { navStack.append(.reports) }
                if key == "systemStates"   { navStack.append(.systemStates) }
                if key == "help"           { navStack.append(.help) }
                if key == "legal"          { navStack.append(.legal) }
                if key == "review"         { selectedTab = .review }
            }
            .environmentObject(app)
        }
    }

    private func popNav() { if !navStack.isEmpty { navStack.removeLast() } }

    @ViewBuilder
    private func routeView(_ route: NavRoute) -> some View {
        switch route {
        case .domainDetail(let e):
            DomainDetailView(
                expense: e,
                projects: repositoryApp.projects,
                categories: repositoryApp.categories,
                events: repositoryApp.eventsByExpenseId[e.id] ?? [],
                role: app.role,
                onBack: { popNav() },
                onApprove: {
                    Task { await repositoryApp.approveExpense(id: e.id) }
                    popNav()
                },
                onReject: { reason in
                    Task { await repositoryApp.rejectExpense(id: e.id, reason: reason) }
                    popNav()
                },
                onResubmit: {
                    Task { await repositoryApp.resubmitExpense(id: e.id) }
                    popNav()
                },
                onCancel: {
                    Task { await repositoryApp.cancelExpense(id: e.id, reason: "Cancelled by submitter.") }
                    popNav()
                },
                onConfirmPurchase: { finalAmount, receiptData, receiptFileName, receiptContentType in
                    Task {
                        var attachmentId: String? = nil
                        if let data = receiptData, let fileName = receiptFileName, let contentType = receiptContentType {
                            let attachment = await repositoryApp.uploadAttachment(
                                expenseId: e.id,
                                upload: PendingReceiptUpload(
                                    kind: .purchaseReceipt,
                                    fileName: fileName,
                                    contentType: contentType,
                                    data: data
                                )
                            )
                            attachmentId = attachment?.id
                        }
                        await repositoryApp.confirmPurchase(
                            id: e.id,
                            input: PurchaseConfirmationInput(
                                finalAmount: finalAmount,
                                purchaseDate: Date(),
                                receiptAttachmentId: attachmentId,
                                note: nil
                            )
                        )
                    }
                    popNav()
                },
                onMarkReimbursed: { method, receiptData, receiptFileName, receiptContentType in
                    Task {
                        var attachmentId: String? = nil
                        if let data = receiptData, let fileName = receiptFileName, let contentType = receiptContentType {
                            let attachment = await repositoryApp.uploadAttachment(
                                expenseId: e.id,
                                upload: PendingReceiptUpload(
                                    kind: .reimbursementProof,
                                    fileName: fileName,
                                    contentType: contentType,
                                    data: data
                                )
                            )
                            attachmentId = attachment?.id
                        }
                        await repositoryApp.markReimbursed(
                            id: e.id,
                            input: ReimbursementInput(
                                amount: e.amount,
                                paymentMethod: method.repositoryMethod,
                                paidAt: Date(),
                                reference: nil,
                                proofAttachmentId: attachmentId
                            )
                        )
                    }
                    popNav()
                },
                onArchive: {
                    Task {
                        if e.isArchived {
                            await repositoryApp.unarchiveExpense(id: e.id)
                        } else {
                            await repositoryApp.archiveExpense(id: e.id)
                        }
                    }
                    popNav()
                },
                onDelete: {
                    Task { await repositoryApp.deleteExpense(id: e.id) }
                    popNav()
                },
                onAttachReceipt: { data, fileName, contentType in
                    // Tag the attachment with the kind that matches the current workflow step
                    // so finance can tell a purchase receipt from the original submitted one.
                    let kind: ExpenseAttachment.Kind = {
                        switch e.status {
                        case .approved, .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement:
                            return .purchaseReceipt
                        case .reimbursed:
                            return .reimbursementProof
                        default:
                            return .submittedReceipt
                        }
                    }()
                    Task {
                        _ = await repositoryApp.uploadAttachment(
                            expenseId: e.id,
                            upload: PendingReceiptUpload(
                                kind: kind,
                                fileName: fileName,
                                contentType: contentType,
                                data: data
                            )
                        )
                    }
                }
            )
        case .manageProjects:
            ManageProjectsView { popNav() }
                .environmentObject(app)
        case .workspaceSettings:
            WorkspaceSettingsView { popNav() }
                .environmentObject(app)
        case .activity:
            ActivityView(
                onOpen: { e in navStack.append(.domainDetail(e)) },
                onBack: { popNav() }
            )
            .environmentObject(app)
        case .permissions:
            PermissionsView { popNav() }
                .environmentObject(app)
        case .notifications:
            NotificationsView(
                onBack: { popNav() },
                onOpenExpense: { e in
                    popNav()
                    navStack.append(.domainDetail(e))
                }
            )
                .environmentObject(app)
        case .accountSettings:
            AccountSettingsView { popNav() }
                .environmentObject(app)
        case .securitySettings:
            SecuritySettingsView { popNav() }
        case .appPreferences:
            AppPreferencesView { popNav() }
        case .reports:
            ReportsExportView { popNav() }
                .environmentObject(app)
        case .systemStates:
            SystemStatesView { popNav() }
        case .help:
            HelpSupportView { popNav() }
        case .legal:
            LegalAboutView { popNav() }
        }
    }

    private var topBar: some View {
        let selectedWorkspace = repositoryApp.selectedWorkspace
        let workspaceName = selectedWorkspace?.name ?? app.company.name
        let hasUnread = repositoryApp.notifications.contains { !$0.isRead }

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
                    WorkspaceBadge(
                        color: selectedWorkspace?.brandColor ?? app.company.color,
                        name: workspaceName,
                        logoURL: selectedWorkspace?.logoUrl.flatMap(URL.init(string:)),
                        size: 26
                    )
                    Text(workspaceName)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: 180, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                }
                .padding(.leading, 6).padding(.trailing, 12).padding(.vertical, 6)
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 999)

            Spacer()

            // Notification bell
            Button {
                navStack.append(.notifications)
            } label: {
                Image(systemName: "bell.fill")
                    .font(.system(size: 16)).foregroundStyle(Color.primary)
                    .frame(width: 38, height: 38)
                    .overlay(alignment: .topTrailing) {
                        if hasUnread {
                            Circle()
                                .fill(Tokens.rejected)
                                .frame(width: 8, height: 8)
                                .offset(x: -4, y: 4)
                        }
                    }
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 999)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(.ultraThinMaterial.opacity(0))
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
    case domainDetail(DomainExpense)
    case manageProjects
    case workspaceSettings
    case activity
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
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var email = ""
    @State private var password = ""
    @State private var mode: AuthMode = .login
    @State private var showReset = false
    @State private var showVerification = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(tr(mode.titleKey))
                    .font(.system(size: 34, weight: .bold))
                Text(tr("auth.subtitle"))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Picker("Mode", selection: $mode) {
                ForEach(AuthMode.allCases, id: \.self) { item in
                    Text(tr(item.titleKey)).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in
                showReset = false
                showVerification = false
            }

            GlassCard(padding: Tokens.padCard) {
                VStack(spacing: 0) {
                    authField(tr("auth.email"), text: $email, keyboard: .emailAddress)
                    Divider().opacity(0.4)
                    secureField(tr("auth.password"), text: $password)
                }
            }

            if showReset {
                infoBanner(icon: "envelope.fill", tint: Tokens.aiPurple,
                           title: tr("auth.reset_sent.title"),
                           message: tr("auth.reset_sent.message", email.isEmpty ? tr("auth.reset_sent.fallback") : email))
            }

            if showVerification {
                infoBanner(icon: "checkmark.seal.fill", tint: Tokens.approved,
                           title: tr("auth.verification.title"),
                           message: tr("auth.verification.message"))
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                           title: tr("auth.failed.title"),
                           message: lastError)
            }

            Button {
                Task {
                    switch mode {
                    case .login:
                        await repositoryApp.signIn(email: email, password: password)
                        showVerification = false
                    case .signup:
                        showVerification = false
                        await repositoryApp.signUp(email: email, password: password)
                        showVerification = repositoryApp.lastError?.localizedCaseInsensitiveContains("confirm") == true
                    }
                    if repositoryApp.lastError == nil {
                        app.signIn(email: email, needsSetup: repositoryApp.workspaces.isEmpty)
                        if let workspace = repositoryApp.selectedWorkspace {
                            app.company = workspace.legacyCompany
                            app.role = workspace.currentUserRole.appRole
                        }
                    }
                }
            } label: {
                Text(tr(mode.actionKey)).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .disabled(email.isEmpty || password.isEmpty)

            HStack {
                if mode == .login {
                    Button(tr("auth.forgot")) {
                        Task {
                            let sent = await repositoryApp.requestPasswordReset(email: email)
                            await MainActor.run { showReset = sent }
                        }
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                } else {
                    Button(tr("auth.back_to_signin")) { mode = .login }
                }
                Spacer()
                Button(mode == .login ? tr("auth.switch_to_signup") : tr("auth.switch_to_signin")) {
                    mode = mode == .login ? .signup : .login
                    showReset = false
                    showVerification = false
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

enum AuthMode: CaseIterable {
    case login, signup

    var titleKey: String {
        switch self {
        case .login: return "auth.signin.title"
        case .signup: return "auth.signup.title"
        }
    }

    var actionKey: String {
        switch self {
        case .login: return "auth.signin.action"
        case .signup: return "auth.signup.action"
        }
    }
}

struct WorkspaceSetupView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var workspaceName = ""
    @State private var inviteCode = ""
    @State private var defaultCurrency = "USD"
    @State private var mode: WorkspaceMode = .create

    private static let currencyOptions = ["USD", "EUR", "GBP", "THB", "JPY", "SGD", "AUD", "CAD"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgress(current: 2, total: 2)
            stepContent
        }
    }

    private var stepContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 24)

            Text(tr("setup.workspace.title")).font(.system(size: 30, weight: .bold))
            Text(tr("setup.workspace.subtitle"))
                .font(.system(size: 14)).foregroundStyle(.secondary)

            GlassCard(padding: Tokens.padCard) {
                Picker(tr("setup.workspace.title"), selection: $mode) {
                    Text(tr("setup.workspace.mode.create")).tag(WorkspaceMode.create)
                    Text(tr("setup.workspace.mode.join")).tag(WorkspaceMode.join)
                }
                .pickerStyle(.segmented)
            }

            GlassCard(padding: Tokens.padCard) {
                if mode == .create {
                    VStack(spacing: 0) {
                        setupField(tr("setup.workspace.org_name"), text: $workspaceName)
                        Divider().opacity(0.4)
                        HStack {
                            Text(tr("setup.workspace.default_currency"))
                                .font(.system(size: 14))
                            Spacer()
                            Picker("", selection: $defaultCurrency) {
                                ForEach(Self.currencyOptions, id: \.self) { code in
                                    Text(code).tag(code)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        .padding(.vertical, 10)
                    }
                } else {
                    VStack(spacing: 0) {
                        setupField(tr("setup.workspace.invite_code"), text: $inviteCode)
                        Divider().opacity(0.4)
                        FormFieldRow(label: tr("setup.workspace.status"), value: inviteCode.isEmpty ? tr("setup.workspace.waiting_invite") : tr("setup.workspace.ready_join"), showChevron: false)
                    }
                }
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(icon: "exclamationmark.shield.fill", tint: Tokens.rejected,
                           title: tr("setup.workspace.failed.title"),
                           message: lastError)
            }

            infoBanner(icon: "person.2.badge.gearshape.fill", tint: Tokens.slate500,
                       title: tr("setup.workspace.invite_required.title"),
                       message: tr("setup.workspace.invite_required.message"))

            Button {
                Task {
                    switch mode {
                    case .create:
                        await repositoryApp.createWorkspace(name: workspaceName, defaultCurrency: defaultCurrency)
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
                Text(mode == .create ? tr("setup.workspace.create_action") : tr("setup.workspace.join_action")).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .disabled(
                (mode == .create && workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) ||
                (mode == .join && inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )

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
