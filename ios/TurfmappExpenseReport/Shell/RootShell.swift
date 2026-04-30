import SwiftUI

struct RootShell: View {
    @StateObject private var app = AppState()
    @State private var selectedTab: TabID = .home
    @State private var navStack: [NavRoute] = []

    var body: some View {
        if !app.isAuthenticated {
            AuthView()
                .environmentObject(app)
                .appBackground()
        } else if !app.profileComplete {
            ProfileSetupView()
                .environmentObject(app)
                .appBackground()
        } else if !app.workspaceReady {
            WorkspaceSetupView()
                .environmentObject(app)
                .appBackground()
        } else {
            appShell
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
        // Debug menu — shake to open on device, or use the sheet below
        .sheet(isPresented: $app.debugMenuOpen) {
            DebugMenuSheet()
                .environmentObject(app)
                .presentationDetents([.medium])
        }
        .onShake { app.debugMenuOpen.toggle() }
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
            if app.role == .manager {
                ManagerOverviewView { selectedTab = .review }
                    .environmentObject(app)
            } else {
                HomeView(selectedTab: $selectedTab) { e in
                    navStack.append(.detail(e))
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
            ActivityView { e in navStack.append(.detail(e)) }
                .environmentObject(app)
        case .review:
            ReviewView { e in navStack.append(.detail(e)) }
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
                           app.updateStatus(id: e.id, to: status, paymentMethod: method, paymentReceipt: receipt)
                           navStack.removeLast()
                       })
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
        HStack {
            // Workspace picker — opens a dropdown menu
            Menu {
                ForEach(MockData.companies, id: \.id) { c in
                    Button {
                        app.company = c
                    } label: {
                        HStack {
                            Text(c.name)
                            if app.company == c {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(app.company.color)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Text(app.company.abbr)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                        )
                    Text(app.company.name)
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
            Button { app.debugMenuOpen.toggle() } label: {
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

// MARK: – Navigation routes

enum NavRoute: Hashable {
    case detail(Expense)
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

// MARK: – Debug menu (role + workspace switcher)

struct DebugMenuSheet: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Role") {
                    Picker("Role", selection: $app.role) {
                        ForEach(AppRole.allCases) { r in
                            Text(r.label).tag(r)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Workspace") {
                    ForEach(MockData.companies, id: \.id) { c in
                        HStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(c.color).frame(width: 22, height: 22)
                                .overlay(Text(c.abbr).font(.system(size: 8, weight: .bold)).foregroundStyle(.white))
                            Text(c.name)
                            Spacer()
                            if app.company == c {
                                Image(systemName: "checkmark").foregroundStyle(Tokens.slate500)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { app.company = c }
                    }
                }
            }
            .navigationTitle("Debug / Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: – Shake gesture (opens debug menu on device)

extension View {
    func onShake(action: @escaping () -> Void) -> some View {
        self.modifier(ShakeModifier(action: action))
    }
}

struct ShakeModifier: ViewModifier {
    let action: () -> Void
    func body(content: Content) -> some View {
        content.onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
            action()
        }
    }
}

extension NSNotification.Name {
    static let deviceDidShakeNotification = NSNotification.Name("DeviceDidShake")
}

// MARK: – Release entry flows

struct AuthView: View {
    @EnvironmentObject var app: AppState
    @State private var email = "sam@turfmapp.io"
    @State private var password = ""
    @State private var mode: AuthMode = .login
    @State private var showReset = false
    @State private var showVerification = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 40)

            VStack(alignment: .leading, spacing: 6) {
                Text(mode == .login ? "Sign in" : "Create account")
                    .font(.system(size: 34, weight: .bold))
                Text("Track approvals, purchases, and reimbursements across your workspace.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    authField("Email", text: $email, keyboard: .emailAddress)
                    Divider().opacity(0.4)
                    secureField("Password", text: $password)
                }
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
                app.signIn(email: email)
            } label: {
                Text(mode == .login ? "Sign in" : "Create account").primaryActionLabel()
            }
            .buttonStyle(.plain)

            HStack {
                Button(mode == .login ? "Forgot password?" : "Already have an account?") {
                    if mode == .login {
                        showReset = true
                    } else {
                        mode = .login
                    }
                }
                Spacer()
                Button(mode == .login ? "Create account" : "Use sign in") {
                    mode = mode == .login ? .signup : .login
                    showReset = false
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
            SecureField("Required", text: text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 210)
        }
        .padding(.vertical, 12)
    }
}

enum AuthMode {
    case login, signup
}

struct ProfileSetupView: View {
    @EnvironmentObject var app: AppState
    @State private var name = "Sam Otero"
    @State private var email = "sam@turfmapp.io"
    @State private var role: AppRole = .employee

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

            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Default role").font(.system(size: 13, weight: .semibold))
                    Picker("Role", selection: $role) {
                        ForEach(AppRole.allCases) { r in Text(r.label).tag(r) }
                    }
                    .pickerStyle(.segmented)
                }
            }

            Button {
                app.completeProfile(name: name, email: email, role: role)
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
    @State private var workspaceName = "Turfmapp"
    @State private var inviteCode = ""
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
                        FormFieldRow(label: "Status", value: inviteCode.isEmpty ? "Waiting for invite" : "Invite found", showChevron: false)
                    }
                }
            }

            infoBanner(icon: "person.2.badge.gearshape.fill", tint: Tokens.slate500,
                       title: "Invite pending state covered",
                       message: "If an invite is not accepted yet, this screen keeps the user out of the workspace.")

            Button {
                app.workspaceReady = true
            } label: {
                Text(mode == .create ? "Create workspace" : "Join workspace").primaryActionLabel()
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
