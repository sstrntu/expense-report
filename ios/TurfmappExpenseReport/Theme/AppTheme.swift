import SwiftUI

enum AppRole: String, CaseIterable, Identifiable {
    case employee, manager, finance, admin
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var needsSetup: Bool = false
    @Published var profileComplete: Bool = false
    @Published var workspaceReady: Bool = false
    @Published var userName: String = "Sira Sasitorn"
    @Published var userEmail: String = "sira@turfmapp.com"
    @Published var role: AppRole = .employee
    @Published var company: Company = MockData.companies[0]
    @Published var expenses: [Expense] = MockData.expenses
    @Published var projects: [Project] = MockData.projects
    @Published var members: [Member] = MockData.members
    @Published var drafts: [ExpenseDraft] = []

    /// Expenses scoped to the currently selected workspace, excluding archived.
    var currentExpenses: [Expense] {
        expenses.filter { $0.companyId == company.id && !$0.isArchived }
    }

    /// Archived expenses scoped to the currently selected workspace.
    var currentArchivedExpenses: [Expense] {
        expenses.filter { $0.companyId == company.id && $0.isArchived }
    }

    /// Projects scoped to the currently selected workspace.
    var currentProjects: [Project] {
        projects.filter { $0.companyId == company.id }
    }

    /// Members scoped to the currently selected workspace.
    var currentMembers: [Member] {
        members.filter { $0.companyId == company.id }
    }

    var currentDrafts: [ExpenseDraft] {
        drafts.filter { $0.companyId == company.id }
    }

    func updateStatus(id: String, to status: ExpenseStatus, paymentMethod: PaymentMethod? = nil, paymentReceipt: String? = nil) {
        guard let idx = expenses.firstIndex(where: { $0.id == id }) else { return }
        expenses[idx].status = status
        if let method  = paymentMethod  { expenses[idx].paymentMethod  = method }
        if let receipt = paymentReceipt { expenses[idx].paymentReceipt = receipt }
    }

    func archiveExpense(id: String) {
        guard let idx = expenses.firstIndex(where: { $0.id == id }) else { return }
        expenses[idx].isArchived.toggle()
    }

    func deleteExpense(id: String) {
        expenses.removeAll { $0.id == id }
    }

    func setProjectThreshold(id: String, to threshold: Double) {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { return }
        projects[idx].autoApproveThreshold = threshold
    }

    func setMemberRole(id: String, to role: MemberRole) {
        guard let idx = members.firstIndex(where: { $0.id == id }) else { return }
        members[idx].role = role
    }

    func signIn(email: String, needsSetup: Bool = false, role: AppRole? = nil) {
        userEmail = email.isEmpty ? userEmail : email
        isAuthenticated = true
        self.needsSetup = needsSetup
        if !needsSetup {
            profileComplete = true
            workspaceReady = true
            self.role = role ?? .employee
        }
    }

    func signOut() {
        isAuthenticated = false
        needsSetup = false
        profileComplete = false
        workspaceReady = false
        role = .employee
        company = MockData.companies[0]
    }

    func completeProfile(name: String, email: String) {
        userName = name.isEmpty ? userName : name
        userEmail = email.isEmpty ? userEmail : email
        profileComplete = true
        role = .employee
    }

    @discardableResult
    func addProject(name: String, budget: Double, owner: String, visibility: String, threshold: Double) -> Project {
        let project = Project(
            id: "p\(UUID().uuidString.prefix(6))",
            companyId: company.id,
            name: name.isEmpty ? "Untitled project" : name,
            spent: 0,
            budget: max(budget, 1),
            owner: owner.isEmpty ? userName : owner,
            color: company.color,
            visibility: visibility.lowercased(),
            autoApproveThreshold: threshold
        )
        projects.insert(project, at: 0)
        return project
    }

    /// Adds a new expense and auto-routes its initial status based on the project's threshold.
    /// Over threshold → `.pending` (needs approval). Under or equal → `.purchased` (skip approval, awaiting reimbursement).
    func addExpense(kind: ExpenseKind = .preApproval, merchant: String, amount: Double, category: String,
                    project: Project, purpose: String, icon: String) {
        let initialStatus: ExpenseStatus
        switch kind {
        case .preApproval:
            initialStatus = amount > project.autoApproveThreshold ? .pending : .approved
        case .reimbursementClaim:
            initialStatus = amount > project.autoApproveThreshold ? .pending : .purchased
        }
        let id = "e\(UUID().uuidString.prefix(6))"
        let expense = Expense(
            id: id, companyId: project.companyId, merchant: merchant, category: category, amount: amount,
            date: "Just now", status: initialStatus,
            project: project.name, icon: icon
        )
        expenses.insert(expense, at: 0)
    }

    func saveDraft(merchant: String, amount: Double, category: String, project: Project?) {
        let draft = ExpenseDraft(
            id: "d\(UUID().uuidString.prefix(6))",
            companyId: company.id,
            merchant: merchant.isEmpty ? "Untitled expense" : merchant,
            amount: amount,
            category: category,
            project: project?.name ?? "No project",
            updated: "Just now"
        )
        drafts.insert(draft, at: 0)
    }
}

extension View {
    /// Background appropriate for the app — provides content for liquid glass to refract.
    func appBackground() -> some View {
        self.background(
            ZStack {
                LinearGradient(colors: [
                    Color(hex: 0xEEF1F8),
                    Color(hex: 0xE4E8F2)
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                Circle()
                    .fill(Tokens.slate500.opacity(0.45))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 120, y: -260)

                Circle()
                    .fill(Tokens.aiPurple.opacity(0.35))
                    .frame(width: 240, height: 240)
                    .blur(radius: 60)
                    .offset(x: -120, y: 200)
            }
        )
    }
}
