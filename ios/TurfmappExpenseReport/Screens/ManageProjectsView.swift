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

                Text("Manage projects").font(.system(size: 18, weight: .bold))
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
                        threshold: MoneyAmount(minorUnits: Int((newValue * 100).rounded()), currency: "USD")
                    )
                }
                app.setProjectThreshold(id: project.id, to: newValue)
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
            .filter { $0.projectId == p.id && [.approved, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains($0.status) }
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
                        Text("\(p.currentUserProjectRole?.label ?? "Member") · \(p.visibility)")
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
                Text("$\(Int(spent / 1000))k spent")
                Spacer()
                Text("$\(Int(p.budget.decimalValue / 1000))k budget")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)

            ProgressView(value: progress).progressViewStyle(.linear).tint(Tokens.slate500)

            Button { editingThresholdFor = p } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.approved)
                    Text("Auto-approve under")
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
                    Text("New project").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { showCreate = false } label: {
                        Image(systemName: "xmark").foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 10)

                createField("Name", text: $projectName, placeholder: "Project name")
                Divider().opacity(0.4)
                createField("Budget", text: $projectBudget, placeholder: "25000", prefix: "$")
                Divider().opacity(0.4)
                createField("Owner", text: $projectOwner, placeholder: app.userName)
                Divider().opacity(0.4)
                createField("Auto-approve under", text: $projectThreshold, placeholder: "100", prefix: "$")

                Text("Visibility")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.top, 12).padding(.bottom, 6)

                ForEach(["Private", "Team", "Org-wide"], id: \.self) { v in
                    Button {
                        projectVisibility = v
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5).frame(width: 18, height: 18)
                                if v == projectVisibility {
                                    Circle().fill(Tokens.slate500).frame(width: 9, height: 9)
                                }
                            }
                            Text(v).font(.system(size: 13))
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    let legacyProject = app.addProject(
                        name: projectName,
                        budget: Double(projectBudget) ?? 0,
                        owner: projectOwner,
                        visibility: projectVisibility,
                        threshold: Double(projectThreshold) ?? 100
                    )
                    Task {
                        await repositoryApp.createProject(domainProject(from: legacyProject))
                    }
                    showCreate = false
                } label: {
                    Text("Create project")
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
                .keyboardType(prefix == "$" ? .numberPad : .default)
                .frame(maxWidth: 180)
        }
        .padding(.vertical, 11)
    }

    private func domainProject(from project: Project) -> DomainProject {
        DomainProject(
            id: project.id,
            workspaceId: project.companyId,
            name: project.name,
            budget: MoneyAmount(minorUnits: Int((project.budget * 100).rounded()), currency: "USD"),
            budgetPeriod: "quarterly",
            ownerMembershipId: "member_current",
            visibility: project.visibility,
            routingMode: .managerThenFinance,
            overBudgetBehavior: .warn,
            allowedCategoryIds: ["meals", "travel", "software", "office", "other"],
            approvalThreshold: MoneyAmount(minorUnits: Int((project.autoApproveThreshold * 100).rounded()), currency: "USD"),
            receiptRequiredThreshold: MoneyAmount(minorUnits: 7500, currency: "USD"),
            currentUserProjectRole: .projectAdmin,
            isArchived: false
        )
    }
}

private extension ProjectRole {
    var label: String {
        switch self {
        case .viewer: return "Viewer"
        case .submitter: return "Submitter"
        case .approver: return "Approver"
        case .finance: return "Finance"
        case .projectAdmin: return "Project admin"
        }
    }
}

// MARK: – Threshold editor sheet

struct ThresholdEditorSheet: View {
    let project: Project
    var onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String

    init(project: Project, onSave: @escaping (Double) -> Void) {
        self.project = project
        self.onSave = onSave
        _amountText = State(initialValue: String(format: "%.0f", project.autoApproveThreshold))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-approve threshold").font(.system(size: 18, weight: .bold))
                Text(project.name).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.horizontal, 20)

            Text("Expenses at or below this amount on this project will skip manager approval.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack {
                Text("$").font(.system(size: 28, weight: .bold)).foregroundStyle(.secondary)
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
                Text("Save").primaryActionLabel()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

struct ProjectDetailSheet: View {
    let project: Project
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name).font(.system(size: 20, weight: .bold))
                    Text("\(project.owner) · \(project.visibility)").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

            VStack(spacing: 0) {
                FormFieldRow(label: "Budget", value: money(project.budget), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: "Spent", value: money(project.spent), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: "Auto-approve under", value: money(project.autoApproveThreshold), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: "Visibility", value: project.visibility.capitalized, showChevron: false)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("Assigned members")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: -8) {
                    ForEach(app.currentMembers.prefix(4)) { member in
                        Avatar(color: member.avatarColor, size: 34, label: member.initials)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                    }
                    Spacer()
                    Text("\(app.currentMembers.count) total")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            infoBanner(icon: "slider.horizontal.3", tint: Tokens.slate500,
                       title: "Project policy",
                       message: "Project-level policy overrides workspace defaults for approval threshold, visibility, and assigned members.")
                .padding(.horizontal, 20)

            infoBanner(icon: "archivebox.fill", tint: Tokens.pending,
                       title: "Archive actions",
                       message: "Project detail should support archive and delete confirmation before hiding a project.")
                .padding(.horizontal, 20)

            Spacer()
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

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-approve threshold").font(.system(size: 18, weight: .bold))
                Text(project.name).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.horizontal, 20)

            Text("Expenses at or below this amount follow the project's routing mode.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack {
                Text("$").font(.system(size: 28, weight: .bold)).foregroundStyle(.secondary)
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
                Text("Save").primaryActionLabel()
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

    private let categories: [(id: String, label: String)] = [
        ("meals", "Meals"),
        ("travel", "Travel"),
        ("software", "Software"),
        ("office", "Office"),
        ("other", "Other")
    ]

    private var spent: Double {
        expenses
            .filter { $0.projectId == project.id && [.approved, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains($0.status) }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name).font(.system(size: 20, weight: .bold))
                    Text("\(project.currentUserProjectRole?.label ?? "Member") · \(project.visibility)").font(.system(size: 12)).foregroundStyle(.secondary)
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
                Text("Assigned members")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: -8) {
                    ForEach(repositoryApp.members.prefix(4)) { member in
                        Avatar(color: member.avatarColor, size: 34, label: member.initials)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                    }
                    Spacer()
                    Text("\(repositoryApp.members.count) total")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Text("Project member access will persist as project_members rows; current mock shows active workspace members eligible for assignment.")
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
                    Label("Archive Project", systemImage: "archivebox")
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
                        Text("Save Policy")
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
            FormFieldRow(label: "Budget", value: project.budget.formatted, showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: "Budget period", value: project.budgetPeriod.capitalized, showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: "Spent", value: money(spent), showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: "Auto-approve under", value: project.approvalThreshold.formatted, showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: "Receipt required over", value: project.receiptRequiredThreshold.formatted, showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: "Routing", value: project.routingMode.label, showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: "Over budget", value: project.overBudgetBehavior.rawValue.capitalized, showChevron: false)
            Divider().opacity(0.4)
            FormFieldRow(label: "Allowed categories", value: allowedCategoryLabel(project.allowedCategoryIds), showChevron: false)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 20)
    }

    private var policyEditor: some View {
        VStack(spacing: 0) {
            editTextRow("Name", text: $nameText)
            Divider().opacity(0.4)
            editTextRow("Budget", text: $budgetText, prefix: "$")
            Divider().opacity(0.4)
            editTextRow("Auto-approve under", text: $thresholdText, prefix: "$")
            Divider().opacity(0.4)
            editTextRow("Receipt required over", text: $receiptThresholdText, prefix: "$")
            Divider().opacity(0.4)
            pickerRow("Budget period", selection: $budgetPeriod, options: ["monthly", "quarterly", "annual"])
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

    private func pickerRow(_ label: String, selection: Binding<String>, options: [String]) -> some View {
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option.capitalized) { selection.wrappedValue = option }
            }
        } label: {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(selection.wrappedValue.capitalized).font(.system(size: 13.5, weight: .medium))
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
                Text("Routing").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
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
                Button(behavior.rawValue.capitalized) { overBudgetBehavior = behavior }
            }
        } label: {
            HStack {
                Text("Over budget").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(overBudgetBehavior.rawValue.capitalized).font(.system(size: 13.5, weight: .medium))
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
                Text("Allowed categories").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(allowedCategoryLabel(Array(allowedCategoryIds))).font(.system(size: 13.5, weight: .medium))
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
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
        if ids.isEmpty { return "All categories" }
        let names = categories.filter { ids.contains($0.id) }.map { $0.label }
        return names.isEmpty ? "Custom" : names.joined(separator: ", ")
    }
}

private extension ProjectRoutingMode {
    var label: String {
        switch self {
        case .managerOnly: return "Manager only"
        case .financeOnly: return "Finance only"
        case .managerThenFinance: return "Manager then finance"
        case .autoApproveThenFinance: return "Auto-approve then finance"
        case .autoReimburse: return "Auto reimburse"
        }
    }
}
