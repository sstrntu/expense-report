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
                .buttonStyle(.plain).glassSurface(corner: 999)

                Text(tr("projects.title")).font(.system(size: 18, weight: .bold))
                Spacer()
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
                .buttonStyle(.plain)
                .background(Tokens.slate500, in: Circle())
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
        .sheet(item: $editingThresholdFor) { project in
            DomainThresholdEditorSheet(project: project) { newValue in
                Task {
                    await repositoryApp.updateProjectThreshold(
                        id: project.id,
                        threshold: MoneyAmount(minorUnits: Int((newValue * 100).rounded()), currency: project.approvalThreshold.currency)
                    )
                }
            }
            .presentationDetents([.height(280)])
        }
        .sheet(item: $viewingProject) { project in
            DomainProjectDetailSheet(project: project, expenses: repositoryApp.expenses)
                .environmentObject(app)
                .presentationDetents([.medium])
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
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 13.5, weight: .semibold))
                        Text("\(p.currentUserProjectRole?.label ?? tr("projects.role.member")) · \(localizedVisibility(p.visibility))")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

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
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private var createForm: some View {
        GlassCard(padding: 16) {
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
                    .buttonStyle(.plain)
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
                .buttonStyle(.plain)
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tr("projects.auto_approve_threshold")).font(.system(size: 18, weight: .bold))
                Text(project.name).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.horizontal, 20)

            Text(tr("projects.auto_approve_threshold.subtitle"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack {
                Text(currencyPrefix).font(.system(size: 28, weight: .bold)).foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .font(.system(size: 36, weight: .bold))
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                if let v = Double(amountText), v >= 0 { onSave(v) }
                dismiss()
            } label: {
                Text(tr("common.save")).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name).font(.system(size: 20, weight: .bold))
                    Text("\(project.currentUserProjectRole?.label ?? tr("projects.role.member")) · \(localizedVisibilityFree(project.visibility))").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    isEditing.toggle()
                } label: {
                    Image(systemName: isEditing ? "checkmark" : "pencil")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

            if isEditing {
                policyEditor
            } else {
                policySummary
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(tr("projects.assigned_members"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: -8) {
                    ForEach(repositoryApp.members.prefix(4)) { member in
                        Avatar(color: member.avatarColor, size: 34, label: member.initials)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                    }
                    Spacer()
                    Text(tr("projects.member_total", repositoryApp.members.count))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text(tr("projects.member_assignment_note"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

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
                .buttonStyle(.plain)
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
                    .buttonStyle(.plain)
                    .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .onAppear(perform: seedEditor)
    }

    private var policySummary: some View {
        VStack(spacing: 0) {
            FormFieldRow(label: tr("projects.field.budget"), value: project.budget.formatted, showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: tr("projects.budget_period"), value: localizedBudgetPeriod(project.budgetPeriod), showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: tr("projects.field.spent"), value: MoneyAmount.format(amount: spent, currency: project.budget.currency), showChevron: false)
            Divider().opacity(0.4)
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
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
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
        .padding(.horizontal, 20)
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
