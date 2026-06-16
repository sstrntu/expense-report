import SwiftUI

struct ManageProjectsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var showCreate = false
    @State private var editingThresholdFor: DomainProject? = nil
    @State private var viewingProject: DomainProject? = nil
    @State private var projectName = ""
    @State private var projectBudget = ""
    @State private var projectOwner = ""
    @State private var projectThreshold = "100"
    @State private var projectVisibility = "Team"
    /// New-project base currency. Nil → falls back to workspace default at
    /// submit time. The picker exposes the same ISO codes as the submit screen.
    @State private var projectCurrency: String?

    /// ISO codes offered when picking a project's base currency. Kept in sync
    /// with SubmitView.currencyOptions so users don't end up with a project
    /// whose base they can't enter expenses in.
    private static let currencyOptions = ["USD", "EUR", "GBP", "THB", "JPY", "SGD", "AUD", "CAD"]
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.pressable).glassSurface(corner: 999)

                Text(tr("projects.title")).font(.system(size: 18, weight: .bold))
                Spacer()
                // Project creation is admin-only server-side ("admins can
                // manage projects" RLS) — showing the button to managers gave
                // them a form whose submit was always rejected.
                if app.role == .admin {
                    Button {
                        projectName = ""
                        projectBudget = ""
                        projectOwner = app.userName
                        projectThreshold = "100"
                        projectVisibility = "Team"
                        showCreate.toggle()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.pressable)
                    .background(Tokens.slate500, in: Circle())
                }
            }
            .padding(.horizontal, 4).padding(.top, 4)

            if showCreate {
                createForm
            }

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(repositoryApp.projects.enumerated()), id: \.element.id) { idx, p in
                        if idx > 0 { Divider().opacity(0.4) }
                        projectRow(p)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        // Pick up project edits made by another admin since last bootstrap.
        // Throttled by refreshIfStale so quick re-entries are a no-op.
        .task {
            await repositoryApp.refreshIfStale()
        }
        .sheet(item: $editingThresholdFor) { project in
            DomainThresholdEditorSheet(project: project) { newValue in
                Task {
                    await repositoryApp.updateProjectThreshold(
                        id: project.id,
                        threshold: MoneyAmount(minorUnits: Int((newValue * 100).rounded()), currency: project.approvalThreshold.currency)
                    )
                }
            }
            .presentationDetents([.height(340)])
        }
        .sheet(item: $viewingProject) { project in
            DomainProjectDetailSheet(project: project, expenses: repositoryApp.expenses)
                .environmentObject(app)
                .presentationDetents([.large])
        }
    }

    private func projectRow(_ p: DomainProject) -> some View {
        let spent = repositoryApp.expenses
            .filter { $0.projectId == p.id
                      && $0.amount.currency == p.budget.currency
                      && [.approved, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains($0.status) }
            .reduce(0) { $0 + $1.amount.decimalValue }
        let progress = min(spent / max(p.budget.decimalValue, 1), 1)

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                viewingProject = p
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(Tokens.slate500).frame(width: 6, height: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.name).font(.system(size: 13.5, weight: .semibold))
                        // Visibility carries an icon so the word ("Team") reads
                        // as access scope, and the role is spelled out as
                        // "you're <role>" so it isn't mistaken for a second
                        // visibility value.
                        HStack(spacing: 5) {
                            Image(systemName: projectVisibilityIcon(p.visibility))
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text(tr("projects.row.subtitle",
                                    localizedVisibility(p.visibility),
                                    projectAccessLabel(projectRole: p.currentUserProjectRole, workspaceRole: app.role)))
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.pressable)

            HStack {
                Text(tr("projects.spent.label", MoneyAmount.format(amount: spent, currency: p.budget.currency)))
                Spacer()
                Text(tr("projects.budget.label", p.budget.formatted))
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)

            ProgressView(value: progress).progressViewStyle(.linear).tint(Tokens.slate500)

            Button { editingThresholdFor = p } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.approved)
                    Text(tr("projects.auto_approve_under"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(p.approvalThreshold.formatted)
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.pressable)
        }
        .padding(14)
    }

    private var createForm: some View {
        GlassCard(padding: Tokens.padCard) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tr("projects.new")).font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { showCreate = false } label: {
                        Image(systemName: "xmark").foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 10)

                createField(tr("projects.field.name"), text: $projectName, placeholder: tr("projects.field.name.placeholder"))
                Divider().opacity(0.4)
                currencyPickerRow
                Divider().opacity(0.4)
                createField(tr("projects.field.budget"), text: $projectBudget, placeholder: tr("projects.field.budget.placeholder"), prefix: effectiveCurrencySymbol)
                Divider().opacity(0.4)
                createField(tr("projects.field.owner"), text: $projectOwner, placeholder: app.userName)
                Divider().opacity(0.4)
                createField(tr("projects.auto_approve_under"), text: $projectThreshold, placeholder: tr("projects.field.threshold.placeholder"), prefix: effectiveCurrencySymbol)

                Text(tr("projects.visibility"))
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.top, 12).padding(.bottom, 6)

                ForEach(visibilityOptions, id: \.value) { option in
                    Button {
                        projectVisibility = option.value
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5).frame(width: 18, height: 18)
                                if option.value == projectVisibility {
                                    Circle().fill(Tokens.slate500).frame(width: 9, height: 9)
                                }
                            }
                            Text(option.label).font(.system(size: 13))
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.pressable)
                }

                Button {
                    guard let workspaceId = repositoryApp.selectedWorkspace?.id else { return }
                    // Project base currency: explicit picker wins, then workspace default.
                    let currency = projectCurrency ?? repositoryApp.selectedWorkspace?.defaultCurrency ?? "USD"
                    let budget = Double(projectBudget) ?? 0
                    let threshold = Double(projectThreshold) ?? 100
                    let newProject = DomainProject(
                        id: UUID().uuidString,
                        workspaceId: workspaceId,
                        name: projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? tr("projects.untitled") : projectName,
                        budget: MoneyAmount(minorUnits: Int((max(budget, 0)) * 100), currency: currency),
                        budgetPeriod: "quarterly",
                        ownerMembershipId: "",
                        visibility: projectVisibility.lowercased() == "org-wide" ? "workspace" : projectVisibility.lowercased(),
                        routingMode: .managerThenFinance,
                        overBudgetBehavior: .warn,
                        allowedCategoryIds: [],
                        approvalThreshold: MoneyAmount(minorUnits: Int(max(threshold, 0) * 100), currency: currency),
                        receiptRequiredThreshold: MoneyAmount(minorUnits: 7500, currency: currency),
                        currentUserProjectRole: .projectAdmin,
                        isArchived: false
                    )
                    Task { await repositoryApp.createProject(newProject) }
                    showCreate = false
                } label: {
                    Text(tr("projects.new"))
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.pressable)
                .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 10)
            }
        }
    }

    private func createField(_ label: String, text: Binding<String>, placeholder: String, prefix: String = "") -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            if !prefix.isEmpty {
                Text(prefix).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.secondary)
            }
            TextField(placeholder, text: text)
                .font(.system(size: 13.5, weight: .medium))
                .multilineTextAlignment(.trailing)
                .keyboardType(prefix == "$" || prefix.count <= 3 ? .numbersAndPunctuation : .default)
                .frame(maxWidth: 180)
        }
        .padding(.vertical, 11)
    }

    /// Resolves the picker's choice, falling back to the workspace default
    /// when the user hasn't explicitly picked. Mirrors the resolution logic
    /// in the Create button so the prefix always matches what we'll write.
    private var effectiveProjectCurrency: String {
        projectCurrency ?? repositoryApp.selectedWorkspace?.defaultCurrency ?? "USD"
    }

    /// Used as the budget/threshold prefix so users see (e.g.) "฿" when the
    /// project base currency is THB. Falls back to the ISO code for currencies
    /// without a unique short symbol.
    private var effectiveCurrencySymbol: String {
        switch effectiveProjectCurrency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "THB": return "฿"
        default: return effectiveProjectCurrency
        }
    }

    /// Tuple keeps the stored value ("private", "team", "workspace") stable
    /// while the label refreshes with the active language.
    @MainActor private var visibilityOptions: [(value: String, label: String)] {
        [
            ("Private", tr("projects.visibility.private")),
            ("Team", tr("projects.visibility.team")),
            ("Org-wide", tr("projects.visibility.org_wide"))
        ]
    }

    /// Resolves a stored visibility token (Private / Team / Org-wide /
    /// private / team / workspace — both casings occur historically) to its
    /// localized label. Falls back to the raw value when nothing matches.
    @MainActor func localizedVisibility(_ raw: String) -> String {
        switch raw.lowercased() {
        case "private":             return tr("projects.visibility.private")
        case "team":                return tr("projects.visibility.team")
        case "org-wide", "workspace": return tr("projects.visibility.org_wide")
        default:                    return raw
        }
    }

    private var currencyPickerRow: some View {
        HStack {
            Text(tr("projects.field.base_currency")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            Menu {
                ForEach(Self.currencyOptions, id: \.self) { code in
                    Button {
                        projectCurrency = code
                    } label: {
                        HStack {
                            Text(code)
                            if effectiveProjectCurrency == code { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Text(effectiveProjectCurrency)
                    .font(.system(size: 13.5, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
        }
        .padding(.vertical, 11)
    }
}

extension ProjectRole {
    @MainActor var label: String {
        switch self {
        case .viewer: return tr("projects.role.viewer")
        case .submitter: return tr("projects.role.submitter")
        case .approver: return tr("projects.role.approver")
        case .finance: return tr("projects.role.finance")
        case .projectAdmin: return tr("projects.role.project_admin")
        }
    }

    /// One-line plain-language description of what the role grants *inside a
    /// project*. Surfaced under the role picker in the Add Member sheet so the
    /// person granting access understands the choice without prior knowledge.
    @MainActor var blurb: String {
        switch self {
        case .viewer: return tr("projects.role.viewer.desc")
        case .submitter: return tr("projects.role.submitter.desc")
        case .approver: return tr("projects.role.approver.desc")
        case .finance: return tr("projects.role.finance.desc")
        case .projectAdmin: return tr("projects.role.project_admin.desc")
        }
    }
}

/// How to describe the *current user's* standing on a project. An explicit
/// project role wins; otherwise we name the workspace role their access flows
/// from (e.g. "Admin (workspace)") rather than the misleading bare "Member" —
/// admins/managers/finance reach projects through their workspace role, not a
/// project-membership row, so they never carry a project role here.
@MainActor func projectAccessLabel(projectRole: ProjectRole?, workspaceRole: AppRole) -> String {
    if let projectRole { return projectRole.label }
    switch workspaceRole {
    case .admin, .manager, .finance:
        return tr("projects.access.via_workspace", tr("role.\(workspaceRole.rawValue)"))
    case .employee:
        return tr("projects.role.member")
    }
}

/// SF Symbol + localized label for a project's visibility token. Centralised
/// so the project list and detail sheet render visibility identically and
/// users learn the icon ↔ meaning mapping.
@MainActor func projectVisibilityIcon(_ raw: String) -> String {
    switch raw.lowercased() {
    case "private":               return "lock.fill"
    case "team":                  return "person.2.fill"
    case "org-wide", "workspace": return "building.2.fill"
    default:                      return "person.2.fill"
    }
}

struct DomainThresholdEditorSheet: View {
    let project: DomainProject
    var onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String

    init(project: DomainProject, onSave: @escaping (Double) -> Void) {
        self.project = project
        self.onSave = onSave
        _amountText = State(initialValue: String(format: "%.0f", project.approvalThreshold.decimalValue))
    }

    /// Currency-aware prefix so a THB project shows "฿" instead of "$".
    /// Falls back to the ISO code for currencies without a single short symbol.
    private var currencyPrefix: String {
        switch project.approvalThreshold.currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "THB": return "฿"
        default:    return project.approvalThreshold.currency
        }
    }

    var body: some View {
        SheetScaffold(
            scrolls: false,
            header: {
                SheetHeader(
                    title: tr("projects.auto_approve_threshold"),
                    subtitle: project.name,
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    Text(tr("projects.auto_approve_threshold.subtitle"))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Text(currencyPrefix).font(.system(size: 28, weight: .bold)).foregroundStyle(.secondary)
                        TextField("0", text: $amountText)
                            .font(.system(size: 36, weight: .bold))
                            .keyboardType(.numberPad)
                    }
                }
            },
            footer: {
                Button {
                    if let v = Double(amountText), v >= 0 { onSave(v) }
                    dismiss()
                } label: {
                    Text(tr("common.save")).primaryActionLabel()
                }
                .buttonStyle(.pressable)
            }
        )
    }
}

struct DomainProjectDetailSheet: View {
    let project: DomainProject
    let expenses: [DomainExpense]
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var nameText = ""
    @State private var budgetText = ""
    @State private var thresholdText = ""
    @State private var receiptThresholdText = ""
    @State private var budgetPeriod = "quarterly"
    @State private var visibility = "Team"
    @State private var routingMode: ProjectRoutingMode = .managerThenFinance
    @State private var overBudgetBehavior: OverBudgetBehavior = .warn
    @State private var allowedCategoryIds: Set<String> = []
    // Project-level membership editor state. Loaded lazily on appear because
    // the project list query doesn't include the full member list (only the
    // current user's project role).
    @State private var projectMembers: [DomainProjectMember] = []
    @State private var isLoadingMembers = false
    @State private var showAddMemberSheet = false

    /// True if the current user can manage this project's membership.
    /// Mirrors the server-side "project admins can manage project memberships"
    /// policy: workspace admin OR project_admin role.
    private var canManageMembers: Bool {
        if app.role == .admin { return true }
        return project.currentUserProjectRole == .projectAdmin
    }

    /// Workspace members not yet in the project — the candidate pool for
    /// the Add Member sheet. Filters out the project's existing members and
    /// workspace admins: admins already have blanket access to every project
    /// via their workspace role, so a project-membership row would grant them
    /// nothing — listing them (including the creator) just invites the
    /// confusing "add yourself to your own project" action.
    private var addableMembers: [DomainWorkspaceMember] {
        let assigned = Set(projectMembers.map(\.workspaceMembershipId))
        return repositoryApp.members.filter { !assigned.contains($0.id) && $0.role != .admin }
    }

    private var categories: [(id: String, label: String)] {
        repositoryApp.categories.map { (id: $0.id, label: $0.name) }
    }

    private var spent: Double {
        expenses
            .filter { $0.projectId == project.id
                      && $0.amount.currency == project.budget.currency
                      && [.approved, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains($0.status) }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    var body: some View {
        SheetScaffold(
            header: { detailHeader },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    if isEditing {
                        policyEditor
                    } else {
                        policySummary
                    }
                    membersSection
                }
            },
            footer: { detailFooter }
        )
        .onAppear(perform: seedEditor)
        .task { await loadProjectMembers() }
        .sheet(isPresented: $showAddMemberSheet) {
            AddProjectMemberSheet(
                addableMembers: addableMembers,
                onAdd: { membershipId, role in
                    Task { await addMember(workspaceMembershipId: membershipId, role: role) }
                }
            )
            .environmentObject(repositoryApp)
            .presentationDetents([.large])
        }
    }

    /// Custom header: title + visibility/role subtitle, an inline edit toggle,
    /// and the standard ✕. Richer than `SheetHeader`, so it's built inline and
    /// handed to the scaffold's header slot.
    private var detailHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name).font(.system(size: 20, weight: .bold))
                HStack(spacing: 5) {
                    Image(systemName: projectVisibilityIcon(project.visibility))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(tr("projects.row.subtitle",
                            localizedVisibilityFree(project.visibility),
                            projectAccessLabel(projectRole: project.currentUserProjectRole, workspaceRole: app.role)))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button { isEditing.toggle() } label: {
                Image(systemName: isEditing ? "checkmark" : "pencil")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.pressable)
            .background(Color.primary.opacity(0.06), in: Circle())
            SheetCloseButton { dismiss() }
        }
    }

    private var detailFooter: some View {
        HStack(spacing: 10) {
            Button {
                Task {
                    await repositoryApp.archiveProject(id: project.id)
                    await MainActor.run { dismiss() }
                }
            } label: {
                Label(tr("projects.archive_project"), systemImage: "archivebox")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.rejected)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.pressable)
            .background(Tokens.rejected.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))

            if isEditing {
                Button {
                    savePolicy()
                } label: {
                    Text(tr("projects.save_policy"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.pressable)
                .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: – Members section

    @ViewBuilder
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(tr("projects.assigned_members"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if canManageMembers && !addableMembers.isEmpty {
                    Button {
                        showAddMemberSheet = true
                    } label: {
                        Label(tr("projects.member.add"), systemImage: "person.crop.circle.badge.plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Tokens.slate500)
                    }
                    .buttonStyle(.pressable)
                }
            }

            if isLoadingMembers && projectMembers.isEmpty {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 12)
            } else if projectMembers.isEmpty {
                // Empty state — workspace visibility implies the project is
                // open to everyone, so the lack of explicit members is fine.
                // For restricted visibility this empty state would mean
                // "nobody can access this project yet".
                Text(tr("projects.member.empty"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(projectMembers.enumerated()), id: \.element.id) { idx, member in
                        if idx > 0 { Divider().opacity(0.4) }
                        memberRow(member)
                    }
                }
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
            }
        }
    }

    private func memberRow(_ member: DomainProjectMember) -> some View {
        HStack(spacing: 10) {
            Avatar(color: Tokens.slate500, size: 30, label: initials(member.displayName))
            VStack(alignment: .leading, spacing: 1) {
                Text(member.displayName).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(member.email).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            if canManageMembers {
                Menu {
                    ForEach(ProjectRole.allCases, id: \.self) { role in
                        Button {
                            Task { await updateMember(member, to: role) }
                        } label: {
                            Label(role.label, systemImage: member.role == role ? "checkmark" : "")
                        }
                    }
                    Divider()
                    Button(role: .destructive) {
                        Task { await removeMember(member) }
                    } label: {
                        Label(tr("projects.member.remove"), systemImage: "minus.circle")
                    }
                } label: {
                    rolePill(member.role)
                }
            } else {
                rolePill(member.role)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }

    private func rolePill(_ role: ProjectRole) -> some View {
        Text(role.label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Tokens.slate500)
            .padding(.horizontal, 9).padding(.vertical, 4)
            .background(Tokens.slate500.opacity(0.12), in: Capsule())
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        let chars = parts.prefix(2).compactMap(\.first).map(String.init).joined()
        return chars.isEmpty ? "M" : chars
    }

    // MARK: – Actions

    private func loadProjectMembers() async {
        isLoadingMembers = true
        projectMembers = await repositoryApp.listProjectMembers(projectId: project.id)
        isLoadingMembers = false
    }

    private func addMember(workspaceMembershipId: String, role: ProjectRole) async {
        if await repositoryApp.addProjectMember(projectId: project.id, workspaceMembershipId: workspaceMembershipId, role: role) != nil {
            await loadProjectMembers()
        }
    }

    private func updateMember(_ member: DomainProjectMember, to role: ProjectRole) async {
        guard role != member.role else { return }
        if await repositoryApp.updateProjectMemberRole(id: member.id, role: role) != nil {
            await loadProjectMembers()
        }
    }

    private func removeMember(_ member: DomainProjectMember) async {
        if await repositoryApp.removeProjectMember(id: member.id) {
            await loadProjectMembers()
        }
    }

    private var policySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(tr("projects.detail.intro"))
                .font(.system(size: 12)).foregroundStyle(.secondary)

            summaryCard(tr("projects.section.budget")) {
                FormFieldRow(label: tr("projects.field.budget"), value: project.budget.formatted, showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("projects.budget_period"), value: localizedBudgetPeriod(project.budgetPeriod), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("projects.field.spent"), value: MoneyAmount.format(amount: spent, currency: project.budget.currency), showChevron: false)
            }

            summaryCard(tr("projects.section.approval_rules")) {
                FormFieldRow(label: tr("projects.auto_approve_under"), value: project.approvalThreshold.formatted, showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("projects.field.receipt_required_over"), value: project.receiptRequiredThreshold.formatted, showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("projects.routing"), value: project.routingMode.label, showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("projects.over_budget"), value: localizedOverBudget(project.overBudgetBehavior), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("projects.allowed_categories"), value: allowedCategoryLabel(project.allowedCategoryIds), showChevron: false)
            }
        }
    }

    /// A titled group of read-only policy rows. Splitting the previously flat
    /// nine-row list into "Budget & spend" and "Approval rules" gives the sheet
    /// scannable structure instead of one undifferentiated wall of values.
    @ViewBuilder
    private func summaryCard<Rows: View>(_ title: String, @ViewBuilder rows: () -> Rows) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            VStack(spacing: 0) { rows() }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var policyEditor: some View {
        VStack(spacing: 0) {
            editTextRow(tr("projects.field.name"), text: $nameText)
            Divider().opacity(0.4)
            editTextRow(tr("projects.field.budget"), text: $budgetText, prefix: currencyPrefix)
            Divider().opacity(0.4)
            editTextRow(tr("projects.auto_approve_under"), text: $thresholdText, prefix: currencyPrefix)
            Divider().opacity(0.4)
            editTextRow(tr("projects.field.receipt_required_over"), text: $receiptThresholdText, prefix: currencyPrefix)
            Divider().opacity(0.4)
            budgetPeriodPicker
            Divider().opacity(0.4)
            routingPicker
            Divider().opacity(0.4)
            overBudgetPicker
            Divider().opacity(0.4)
            categoryPicker
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func editTextRow(_ label: String, text: Binding<String>, prefix: String = "") -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            if !prefix.isEmpty {
                Text(prefix).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.secondary)
            }
            TextField(label, text: text)
                .font(.system(size: 13.5, weight: .medium))
                .keyboardType(prefix == "$" ? .decimalPad : .default)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 180)
        }
        .padding(.vertical, 10)
    }

    private var budgetPeriodPicker: some View {
        Menu {
            ForEach(["monthly", "quarterly", "annual"], id: \.self) { option in
                Button(localizedBudgetPeriod(option)) { budgetPeriod = option }
            }
        } label: {
            HStack {
                Text(tr("projects.budget_period")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(localizedBudgetPeriod(budgetPeriod)).font(.system(size: 13.5, weight: .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
    }

    private var routingPicker: some View {
        Menu {
            ForEach(ProjectRoutingMode.allCases, id: \.self) { mode in
                Button(mode.label) { routingMode = mode }
            }
        } label: {
            HStack {
                Text(tr("projects.routing")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(routingMode.label).font(.system(size: 13.5, weight: .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
    }

    private var overBudgetPicker: some View {
        Menu {
            ForEach(OverBudgetBehavior.allCases, id: \.self) { behavior in
                Button(localizedOverBudget(behavior)) { overBudgetBehavior = behavior }
            }
        } label: {
            HStack {
                Text(tr("projects.over_budget")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(localizedOverBudget(overBudgetBehavior)).font(.system(size: 13.5, weight: .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
    }

    private var categoryPicker: some View {
        Menu {
            ForEach(categories, id: \.id) { category in
                Button {
                    if allowedCategoryIds.contains(category.id) {
                        allowedCategoryIds.remove(category.id)
                    } else {
                        allowedCategoryIds.insert(category.id)
                    }
                } label: {
                    Label(category.label, systemImage: allowedCategoryIds.contains(category.id) ? "checkmark" : "")
                }
            }
        } label: {
            HStack {
                Text(tr("projects.allowed_categories")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(allowedCategoryLabel(Array(allowedCategoryIds))).font(.system(size: 13.5, weight: .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
    }

    /// Currency-aware prefix for the budget/threshold inputs. Mirrors the
    /// resolution used by the create form so an editor reopened on a THB
    /// project shows ฿ instead of $.
    private var currencyPrefix: String {
        switch project.budget.currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "THB": return "฿"
        default:    return project.budget.currency
        }
    }

    /// Sheet-scoped visibility localizer (the view-level one above lives in
    /// ManageProjectsView; this sheet doesn't share that scope).
    @MainActor func localizedVisibilityFree(_ raw: String) -> String {
        switch raw.lowercased() {
        case "private":             return tr("projects.visibility.private")
        case "team":                return tr("projects.visibility.team")
        case "org-wide", "workspace": return tr("projects.visibility.org_wide")
        default:                    return raw
        }
    }

    private func seedEditor() {
        nameText = project.name
        budgetText = String(format: "%.2f", project.budget.decimalValue)
        thresholdText = String(format: "%.2f", project.approvalThreshold.decimalValue)
        receiptThresholdText = String(format: "%.2f", project.receiptRequiredThreshold.decimalValue)
        budgetPeriod = project.budgetPeriod
        visibility = project.visibility
        routingMode = project.routingMode
        overBudgetBehavior = project.overBudgetBehavior
        allowedCategoryIds = Set(project.allowedCategoryIds)
    }

    private func savePolicy() {
        let updated = DomainProject(
            id: project.id,
            workspaceId: project.workspaceId,
            name: nameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? project.name : nameText,
            budget: moneyAmount(budgetText, fallback: project.budget),
            budgetPeriod: budgetPeriod,
            ownerMembershipId: project.ownerMembershipId,
            visibility: visibility,
            routingMode: routingMode,
            overBudgetBehavior: overBudgetBehavior,
            allowedCategoryIds: Array(allowedCategoryIds).sorted(),
            approvalThreshold: moneyAmount(thresholdText, fallback: project.approvalThreshold),
            receiptRequiredThreshold: moneyAmount(receiptThresholdText, fallback: project.receiptRequiredThreshold),
            currentUserProjectRole: project.currentUserProjectRole,
            isArchived: project.isArchived
        )
        Task {
            await repositoryApp.updateProject(updated)
            await MainActor.run {
                isEditing = false
                dismiss()
            }
        }
    }

    private func moneyAmount(_ text: String, fallback: MoneyAmount) -> MoneyAmount {
        let value = Double(text.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines))
        return MoneyAmount(minorUnits: Int(((value ?? fallback.decimalValue) * 100).rounded()), currency: fallback.currency)
    }

    private func allowedCategoryLabel(_ ids: [String]) -> String {
        if ids.isEmpty { return tr("projects.categories.all") }
        let names = categories.filter { ids.contains($0.id) }.map { $0.label }
        return names.isEmpty ? tr("projects.categories.custom") : names.joined(separator: ", ")
    }
}

extension ProjectRoutingMode {
    @MainActor var label: String {
        switch self {
        case .managerOnly: return tr("projects.routing.manager_only")
        case .financeOnly: return tr("projects.routing.finance_only")
        case .managerThenFinance: return tr("projects.routing.manager_then_finance")
        case .autoApproveThenFinance: return tr("projects.routing.auto_approve_then_finance")
        case .autoReimburse: return tr("projects.routing.auto_reimburse")
        }
    }
}

@MainActor func localizedBudgetPeriod(_ period: String) -> String {
    switch period.lowercased() {
    case "monthly":   return tr("projects.budget_period.monthly")
    case "quarterly": return tr("projects.budget_period.quarterly")
    case "annual":    return tr("projects.budget_period.annual")
    default:          return period.capitalized
    }
}

@MainActor func localizedOverBudget(_ behavior: OverBudgetBehavior) -> String {
    switch behavior {
    case .warn:     return tr("projects.over_budget.warn")
    case .escalate: return tr("projects.over_budget.escalate")
    case .block:    return tr("projects.over_budget.block")
    }
}

/// Sheet for adding a workspace member to a project. Used from
/// DomainProjectDetailSheet by workspace admins and project_admins. Closes
/// itself after the parent's `onAdd` closure fires — the parent re-fetches
/// the project's member list to reflect the new row.
struct AddProjectMemberSheet: View {
    let addableMembers: [DomainWorkspaceMember]
    var onAdd: (_ workspaceMembershipId: String, _ role: ProjectRole) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var pickedMembershipId: String? = nil
    @State private var pickedRole: ProjectRole = .submitter

    var body: some View {
        SheetScaffold(
            header: {
                SheetHeader(
                    title: tr("projects.member.add"),
                    subtitle: tr("projects.member.add.subtitle"),
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 18) {
                    // Step 1 — who. Pick first; choosing what they can do only
                    // matters once there's a person to grant it to.
                    VStack(alignment: .leading, spacing: 8) {
                        stepLabel(tr("projects.member.step_member"))
                        if addableMembers.isEmpty {
                            Text(tr("projects.member.none_to_add"))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16).padding(.vertical, 20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(addableMembers.enumerated()), id: \.element.id) { idx, member in
                                    if idx > 0 { Divider().opacity(0.4) }
                                    Button { pickedMembershipId = member.id } label: {
                                        HStack(spacing: 10) {
                                            Avatar(color: member.avatarColor, size: 30, label: member.initials)
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(member.displayName).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.primary)
                                                Text(member.email).font(.system(size: 11)).foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Image(systemName: pickedMembershipId == member.id ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 18))
                                                .foregroundStyle(pickedMembershipId == member.id ? Tokens.approved : Color.secondary.opacity(0.4))
                                        }
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }

                    // Step 2 — what. The selected role's plain-language blurb
                    // sits right below the chips so the choice is legible to
                    // someone who doesn't already know the role taxonomy.
                    VStack(alignment: .leading, spacing: 8) {
                        stepLabel(tr("projects.member.step_role"))
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(ProjectRole.allCases, id: \.self) { role in
                                    Button { pickedRole = role } label: {
                                        Text(role.label)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(pickedRole == role ? .white : Color.primary)
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(
                                                pickedRole == role ? Tokens.slate500 : Color.primary.opacity(0.06),
                                                in: Capsule()
                                            )
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Tokens.slate500)
                            Text(pickedRole.blurb)
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(Tokens.slate500.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            },
            footer: {
                Button {
                    guard let id = pickedMembershipId else { return }
                    onAdd(id, pickedRole)
                    dismiss()
                } label: {
                    Text(tr("projects.member.add_action")).primaryActionLabel()
                }
                .buttonStyle(.pressable)
                .disabled(pickedMembershipId == nil)
                .opacity(pickedMembershipId == nil ? 0.5 : 1)
            }
        )
    }

    private func stepLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 4)
    }
}
