import Foundation
import SwiftUI
import UIKit

actor MockRepositoryStore {
    private(set) var currentUserId = "user_sira"
    private var workspaces: [DomainWorkspace]
    private var members: [DomainWorkspaceMember]
    private var projects: [DomainProject]
    private var expenses: [DomainExpense]
    private var attachments: [ExpenseAttachment] = []
    private var scans: [ReceiptScanResult] = []
    private var invites: [WorkspaceInvite] = []
    private var events: [ExpenseWorkflowEvent] = []

    init() {
        workspaces = MockData.companies.enumerated().map { idx, company in
            DomainWorkspace(
                id: company.id,
                name: company.name,
                abbr: company.abbr,
                brandColorHex: company.color.hexString,
                defaultCurrency: "USD",
                currentUserRole: idx == 0 ? .admin : .manager
            )
        }

        members = MockData.members.map { member in
            DomainWorkspaceMember(
                id: member.id,
                workspaceId: member.companyId,
                userId: "user_\(member.id)",
                displayName: member.name,
                email: member.email,
                role: member.role.workspaceRole,
                status: "active",
                avatarColorHex: member.avatarColor.hexString
            )
        }

        invites = [
            WorkspaceInvite(
                id: "invite_finance_turfmapp",
                workspaceId: "turfmapp",
                email: "finance@turfmapp.io",
                role: .finance,
                status: .pending,
                expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
            )
        ]

        projects = MockData.projects.map { project in
            DomainProject(
                id: project.id,
                workspaceId: project.companyId,
                name: project.name,
                budget: MoneyAmount(minorUnits: Int(project.budget * 100), currency: "USD"),
                budgetPeriod: "quarterly",
                ownerMembershipId: "member_owner_\(project.id)",
                visibility: project.visibility,
                routingMode: .managerThenFinance,
                overBudgetBehavior: .warn,
                allowedCategoryIds: ["meals", "travel", "software", "office", "other"],
                approvalThreshold: MoneyAmount(minorUnits: Int(project.autoApproveThreshold * 100), currency: "USD"),
                receiptRequiredThreshold: MoneyAmount(minorUnits: 7500, currency: "USD"),
                currentUserProjectRole: .projectAdmin,
                isArchived: false
            )
        }

        expenses = MockData.expenses.map { expense in
            let projectId = MockData.projects.first { $0.companyId == expense.companyId && $0.name == expense.project }?.id ?? "unknown_project"
            return DomainExpense(
                id: expense.id,
                workspaceId: expense.companyId,
                projectId: projectId,
                submittedByMembershipId: "member_sira_\(expense.companyId)",
                kind: expense.status == .pending || expense.status == .approved ? .preApproval : .reimbursementClaim,
                status: expense.status.workflowStatus,
                merchant: expense.merchant,
                amount: MoneyAmount(minorUnits: Int(expense.amount * 100), currency: "USD"),
                categoryId: expense.category.lowercased(),
                businessPurpose: "Business expense for \(expense.project)",
                purchaseDate: nil,
                neededByDate: nil,
                createdAt: Date(),
                submittedAt: Date(),
                isArchived: expense.isArchived
            )
        }
    }

    func signIn(email: String, password: String) async throws {
        currentUserId = email.isEmpty ? currentUserId : email
    }

    func signOut() async throws {}

    func listWorkspaces() -> [DomainWorkspace] {
        workspaces
    }

    func listMembers(workspaceId: String) -> [DomainWorkspaceMember] {
        members.filter { $0.workspaceId == workspaceId && $0.status == "active" }
    }

    func listInvites(workspaceId: String) -> [WorkspaceInvite] {
        expirePendingInvites()
        return invites.filter { $0.workspaceId == workspaceId && $0.status == .pending }
    }

    func createWorkspace(name: String, defaultCurrency: String) -> DomainWorkspace {
        let workspaceName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let workspace = DomainWorkspace(
            id: "workspace_\(UUID().uuidString.prefix(8))",
            name: workspaceName.isEmpty ? "Untitled workspace" : workspaceName,
            abbr: String((workspaceName.isEmpty ? "UW" : workspaceName).prefix(2)).uppercased(),
            brandColorHex: "878E9F",
            defaultCurrency: defaultCurrency,
            currentUserRole: .admin
        )
        workspaces.insert(workspace, at: 0)
        members.insert(
            DomainWorkspaceMember(
                id: "member_\(UUID().uuidString.prefix(8))",
                workspaceId: workspace.id,
                userId: currentUserId,
                displayName: "Sira Sasitorn",
                email: "sira@turfmapp.com",
                role: .admin,
                status: "active",
                avatarColorHex: "4B5563"
            ),
            at: 0
        )
        return workspace
    }

    func acceptInvite(id: String) throws -> DomainWorkspace {
        guard let idx = invites.firstIndex(where: { $0.id == id }),
              invites[idx].status == .pending,
              invites[idx].expiresAt > Date(),
              let invite = invites[safe: idx],
              let workspace = workspaces.first(where: { $0.id == invite.workspaceId }) else {
            throw MockRepositoryError.notFound
        }
        invites[idx] = WorkspaceInvite(
            id: invite.id,
            workspaceId: invite.workspaceId,
            email: invite.email,
            role: invite.role,
            status: .accepted,
            expiresAt: invite.expiresAt
        )
        if !members.contains(where: { $0.workspaceId == invite.workspaceId && $0.userId == currentUserId && $0.status == "active" }) {
            members.insert(
                DomainWorkspaceMember(
                    id: "member_\(UUID().uuidString.prefix(8))",
                    workspaceId: invite.workspaceId,
                    userId: currentUserId,
                    displayName: "Sira Sasitorn",
                    email: invite.email,
                    role: invite.role,
                    status: "active",
                    avatarColorHex: "4B5563"
                ),
                at: 0
            )
        }
        return workspace
    }

    func inviteMember(workspaceId: String, email: String, role: WorkspaceRole) -> WorkspaceInvite {
        let invite = WorkspaceInvite(
            id: "invite_\(UUID().uuidString.prefix(8))",
            workspaceId: workspaceId,
            email: email,
            role: role,
            status: .pending,
            expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        )
        invites.insert(invite, at: 0)
        return invite
    }

    func cancelInvite(id: String) {
        guard let idx = invites.firstIndex(where: { $0.id == id }) else { return }
        let invite = invites[idx]
        invites[idx] = WorkspaceInvite(
            id: invite.id,
            workspaceId: invite.workspaceId,
            email: invite.email,
            role: invite.role,
            status: .cancelled,
            expiresAt: invite.expiresAt
        )
    }

    func updateMemberRole(id: String, role: WorkspaceRole) throws -> DomainWorkspaceMember {
        guard let idx = members.firstIndex(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        let member = members[idx]
        if member.role == .admin, role != .admin, activeAdminCount(in: member.workspaceId) <= 1 {
            throw MockRepositoryError.lastAdmin
        }
        let updated = DomainWorkspaceMember(
            id: member.id,
            workspaceId: member.workspaceId,
            userId: member.userId,
            displayName: member.displayName,
            email: member.email,
            role: role,
            status: member.status,
            avatarColorHex: member.avatarColorHex
        )
        members[idx] = updated
        return updated
    }

    func removeMember(id: String) throws {
        guard let idx = members.firstIndex(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        let member = members[idx]
        if member.role == .admin, activeAdminCount(in: member.workspaceId) <= 1 {
            throw MockRepositoryError.lastAdmin
        }
        members[idx] = DomainWorkspaceMember(
            id: member.id,
            workspaceId: member.workspaceId,
            userId: member.userId,
            displayName: member.displayName,
            email: member.email,
            role: member.role,
            status: "removed",
            avatarColorHex: member.avatarColorHex
        )
    }

    private func activeAdminCount(in workspaceId: String) -> Int {
        members.filter { $0.workspaceId == workspaceId && $0.status == "active" && $0.role == .admin }.count
    }

    private func expirePendingInvites() {
        for idx in invites.indices where invites[idx].status == .pending && invites[idx].expiresAt <= Date() {
            let invite = invites[idx]
            invites[idx] = WorkspaceInvite(
                id: invite.id,
                workspaceId: invite.workspaceId,
                email: invite.email,
                role: invite.role,
                status: .expired,
                expiresAt: invite.expiresAt
            )
        }
    }

    private func currentRole(in workspaceId: String) -> WorkspaceRole {
        workspaces.first { $0.id == workspaceId }?.currentUserRole ?? .employee
    }

    func listProjects(workspaceId: String) -> [DomainProject] {
        projects.filter { $0.workspaceId == workspaceId && !$0.isArchived }
    }

    func createProject(_ project: DomainProject) -> DomainProject {
        projects.insert(project, at: 0)
        return project
    }

    func updateProject(_ project: DomainProject) throws -> DomainProject {
        guard let idx = projects.firstIndex(where: { $0.id == project.id }) else { throw MockRepositoryError.notFound }
        projects[idx] = project
        return project
    }

    func archiveProject(id: String) throws {
        guard let idx = projects.firstIndex(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        let project = projects[idx]
        projects[idx] = DomainProject(
            id: project.id,
            workspaceId: project.workspaceId,
            name: project.name,
            budget: project.budget,
            budgetPeriod: project.budgetPeriod,
            ownerMembershipId: project.ownerMembershipId,
            visibility: project.visibility,
            routingMode: project.routingMode,
            overBudgetBehavior: project.overBudgetBehavior,
            allowedCategoryIds: project.allowedCategoryIds,
            approvalThreshold: project.approvalThreshold,
            receiptRequiredThreshold: project.receiptRequiredThreshold,
            currentUserProjectRole: project.currentUserProjectRole,
            isArchived: true
        )
    }

    func listExpenses(filters: ExpenseFilters) -> [DomainExpense] {
        expenses.filter { expense in
            guard expense.workspaceId == filters.workspaceId else { return false }
            if let projectId = filters.projectId, expense.projectId != projectId { return false }
            if let status = filters.status, expense.status != status { return false }
            if let kind = filters.kind, expense.kind != kind { return false }
            if let searchText = filters.searchText, !searchText.isEmpty {
                let haystack = "\(expense.merchant) \(expense.businessPurpose) \(expense.categoryId)"
                if !haystack.localizedCaseInsensitiveContains(searchText) { return false }
            }
            return true
        }
    }

    func listEvents(expenseId: String) -> [ExpenseWorkflowEvent] {
        events
            .filter { $0.expenseId == expenseId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func createDraft(_ input: ExpenseDraftInput) throws -> DomainExpense {
        guard let project = projects.first(where: { $0.id == input.projectId && !$0.isArchived }) else {
            throw MockRepositoryError.notFound
        }
        guard project.workspaceId == input.workspaceId else {
            throw MockRepositoryError.crossWorkspaceSelection
        }
        guard project.currentUserProjectRole?.canSubmitExpenses == true else {
            throw MockRepositoryError.permissionDenied
        }
        guard project.allowedCategoryIds.isEmpty || project.allowedCategoryIds.contains(input.categoryId) else {
            throw MockRepositoryError.projectPolicyBlocked("This category is not allowed on the selected project.")
        }
        let expense = DomainExpense(
            id: "expense_\(UUID().uuidString.prefix(8))",
            workspaceId: input.workspaceId,
            projectId: input.projectId,
            submittedByMembershipId: "member_sira_\(input.workspaceId)",
            kind: input.kind,
            status: .draft,
            merchant: input.merchant,
            amount: input.amount,
            categoryId: input.categoryId,
            businessPurpose: input.businessPurpose,
            purchaseDate: input.purchaseDate,
            neededByDate: input.neededByDate,
            createdAt: Date(),
            submittedAt: nil,
            isArchived: false
        )
        expenses.insert(expense, at: 0)
        appendEvent(expenseId: expense.id, from: nil, to: .draft, eventType: "created", note: nil)
        return expense
    }

    func submitExpense(id: String) throws -> DomainExpense {
        guard let idx = expenses.firstIndex(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        let expense = expenses[idx]
        guard let project = projects.first(where: { $0.id == expense.projectId }) else { throw MockRepositoryError.notFound }
        guard project.workspaceId == expense.workspaceId else { throw MockRepositoryError.crossWorkspaceSelection }
        guard project.currentUserProjectRole?.canSubmitExpenses == true else { throw MockRepositoryError.permissionDenied }
        guard project.allowedCategoryIds.isEmpty || project.allowedCategoryIds.contains(expense.categoryId) else {
            throw MockRepositoryError.projectPolicyBlocked("This category is not allowed on the selected project.")
        }
        try validateBudgetPolicy(expense: expense, project: project)
        let nextStatus = ExpenseWorkflow.initialSubmittedStatus(kind: expense.kind, project: project, amount: expense.amount)
        return replaceExpense(expense, status: nextStatus, eventType: "submitted", note: nil)
    }

    func resubmitExpense(id: String) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        guard ExpenseWorkflow.canResubmit(expense) else { throw MockRepositoryError.invalidTransition }
        guard let project = projects.first(where: { $0.id == expense.projectId && !$0.isArchived }) else {
            throw MockRepositoryError.notFound
        }
        let nextStatus = ExpenseWorkflow.initialSubmittedStatus(kind: expense.kind, project: project, amount: expense.amount)
        return replaceExpense(expense, status: nextStatus, eventType: "resubmitted", note: nil)
    }

    func cancelExpense(id: String, reason: String?) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        guard ExpenseWorkflow.canCancel(expense) else { throw MockRepositoryError.invalidTransition }
        return replaceExpense(expense, status: .cancelled, eventType: "cancelled", note: reason)
    }

    func approveExpense(id: String, note: String?) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        guard let project = projects.first(where: { $0.id == expense.projectId }) else { throw MockRepositoryError.notFound }
        guard ExpenseWorkflow.canApprove(expense, role: currentRole(in: expense.workspaceId)) else {
            throw MockRepositoryError.permissionDenied
        }
        let nextStatus = ExpenseWorkflow.statusAfterManagerApproval(kind: expense.kind, project: project)
        return replaceExpense(expense, status: nextStatus, eventType: "approved", note: note)
    }

    func rejectExpense(id: String, reason: String) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        guard ExpenseWorkflow.canReject(expense, role: currentRole(in: expense.workspaceId)) else {
            throw MockRepositoryError.permissionDenied
        }
        return replaceExpense(expense, status: .rejected, eventType: "rejected", note: reason)
    }

    func confirmPurchase(id: String, input: PurchaseConfirmationInput) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        guard let project = projects.first(where: { $0.id == expense.projectId }) else { throw MockRepositoryError.notFound }
        guard ExpenseWorkflow.canConfirmPurchase(expense) else { throw MockRepositoryError.invalidTransition }
        let nextStatus = ExpenseWorkflow.statusAfterPurchaseConfirmation(project: project)
        return replaceExpense(expense, status: nextStatus, amount: input.finalAmount, eventType: "purchase_confirmed", note: input.note)
    }

    func markReimbursed(id: String, input: ReimbursementInput) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        guard ExpenseWorkflow.canMarkReimbursed(expense, role: currentRole(in: expense.workspaceId)) else {
            throw MockRepositoryError.permissionDenied
        }
        return replaceExpense(expense, status: .reimbursed, eventType: "reimbursement_sent", note: input.reference)
    }

    func archiveExpense(id: String) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        return replaceExpense(expense, status: expense.status, isArchived: true, eventType: "archived", note: nil)
    }

    func unarchiveExpense(id: String) throws -> DomainExpense {
        guard let expense = expenses.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        return replaceExpense(expense, status: expense.status == .archived ? .draft : expense.status, isArchived: false, eventType: "unarchived", note: nil)
    }

    func deleteExpense(id: String) {
        expenses.removeAll { $0.id == id }
    }

    func listAttachments(expenseId: String) -> [ExpenseAttachment] {
        attachments.filter { $0.expenseId == expenseId }
    }

    func uploadAttachment(expenseId: String, kind: ExpenseAttachment.Kind, fileName: String, contentType: String, data: Data) throws -> ExpenseAttachment {
        guard let expense = expenses.first(where: { $0.id == expenseId }) else { throw MockRepositoryError.notFound }
        let attachment = ExpenseAttachment(
            id: "attachment_\(UUID().uuidString.prefix(8))",
            workspaceId: expense.workspaceId,
            expenseId: expenseId,
            kind: kind,
            fileName: fileName,
            contentType: contentType,
            storageKey: "mock/\(expense.workspaceId)/\(expenseId)/\(fileName)",
            createdAt: Date()
        )
        attachments.insert(attachment, at: 0)
        return attachment
    }

    func deleteAttachment(id: String) {
        attachments.removeAll { $0.id == id }
    }

    func startScan(attachmentId: String) throws -> ReceiptScanResult {
        guard let attachment = attachments.first(where: { $0.id == attachmentId }) else { throw MockRepositoryError.notFound }
        let result = ReceiptScanResult(
            id: "scan_\(UUID().uuidString.prefix(8))",
            attachmentId: attachmentId,
            expenseId: attachment.expenseId,
            status: .needsReview,
            fields: [
                ReceiptScanField(id: "merchant", fieldName: "merchant", extractedValue: "Whole Foods Market", normalizedValue: "Whole Foods Market", confidence: .high, confirmedByUser: false),
                ReceiptScanField(id: "amount", fieldName: "amount", extractedValue: "47.23", normalizedValue: "4723", confidence: .high, confirmedByUser: false),
                ReceiptScanField(id: "category", fieldName: "category", extractedValue: "Meals", normalizedValue: "meals", confidence: .medium, confirmedByUser: false)
            ],
            errorMessage: nil
        )
        scans.insert(result, at: 0)
        appendEvent(expenseId: attachment.expenseId, from: nil, to: .scanProcessing, eventType: "scan_completed", note: "Mock receipt extraction ready for review.")
        return result
    }

    func getScanResult(id: String) throws -> ReceiptScanResult {
        guard let scan = scans.first(where: { $0.id == id }) else { throw MockRepositoryError.notFound }
        return scan
    }

    func confirmScanField(scanId: String, fieldId: String, normalizedValue: String) throws -> ReceiptScanResult {
        guard let idx = scans.firstIndex(where: { $0.id == scanId }) else { throw MockRepositoryError.notFound }
        let scan = scans[idx]
        let fields = scan.fields.map { field in
            field.id == fieldId
                ? ReceiptScanField(id: field.id, fieldName: field.fieldName, extractedValue: field.extractedValue, normalizedValue: normalizedValue, confidence: .manual, confirmedByUser: true)
                : field
        }
        let updated = ReceiptScanResult(id: scan.id, attachmentId: scan.attachmentId, expenseId: scan.expenseId, status: .confirmed, fields: fields, errorMessage: nil)
        scans[idx] = updated
        return updated
    }

    private func replaceExpense(_ expense: DomainExpense, status: ExpenseWorkflowStatus, amount: MoneyAmount? = nil, isArchived: Bool? = nil, eventType: String, note: String?) -> DomainExpense {
        let updated = DomainExpense(
            id: expense.id,
            workspaceId: expense.workspaceId,
            projectId: expense.projectId,
            submittedByMembershipId: expense.submittedByMembershipId,
            kind: expense.kind,
            status: status,
            merchant: expense.merchant,
            amount: amount ?? expense.amount,
            categoryId: expense.categoryId,
            businessPurpose: expense.businessPurpose,
            purchaseDate: expense.purchaseDate,
            neededByDate: expense.neededByDate,
            createdAt: expense.createdAt,
            submittedAt: expense.submittedAt ?? Date(),
            isArchived: isArchived ?? expense.isArchived
        )
        if let idx = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[idx] = updated
        }
        appendEvent(expenseId: expense.id, from: expense.status, to: status, eventType: eventType, note: note)
        return updated
    }

    private func appendEvent(expenseId: String, from: ExpenseWorkflowStatus?, to: ExpenseWorkflowStatus?, eventType: String, note: String?) {
        events.insert(
            ExpenseWorkflowEvent(
                id: "event_\(UUID().uuidString.prefix(8))",
                expenseId: expenseId,
                actorMembershipId: "member_sira",
                fromStatus: from,
                toStatus: to,
                eventType: eventType,
                note: note,
                createdAt: Date()
            ),
            at: 0
        )
    }

    private func validateBudgetPolicy(expense: DomainExpense, project: DomainProject) throws {
        let committedSpend = expenses
            .filter { existing in
                existing.projectId == project.id &&
                existing.id != expense.id &&
                !existing.isArchived &&
                [.approved, .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement, .reimbursed].contains(existing.status)
            }
            .reduce(0) { $0 + $1.amount.minorUnits }
        let projectedSpend = committedSpend + expense.amount.minorUnits
        guard projectedSpend > project.budget.minorUnits else { return }

        switch project.overBudgetBehavior {
        case .warn:
            appendEvent(expenseId: expense.id, from: expense.status, to: expense.status, eventType: "budget_warning", note: "Projected spend exceeds project budget.")
        case .escalate:
            appendEvent(expenseId: expense.id, from: expense.status, to: expense.status, eventType: "budget_escalation", note: "Projected spend exceeds project budget and requires manager review.")
        case .block:
            throw MockRepositoryError.projectPolicyBlocked("This expense would exceed the selected project's budget.")
        }
    }
}

enum MockRepositoryError: Error, LocalizedError {
    case notFound
    case lastAdmin
    case invalidTransition
    case permissionDenied
    case crossWorkspaceSelection
    case projectPolicyBlocked(String)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "That record could not be found."
        case .lastAdmin:
            return "Every workspace needs at least one admin. Add another admin before changing or removing this one."
        case .invalidTransition:
            return "That action is not available for the current expense status."
        case .permissionDenied:
            return "Your workspace role cannot perform that action."
        case .crossWorkspaceSelection:
            return "The selected project does not belong to the selected workspace."
        case .projectPolicyBlocked(let message):
            return message
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct MockAuthRepository: AuthRepository {
    let store: MockRepositoryStore

    func signIn(email: String, password: String) async throws {
        try await store.signIn(email: email, password: password)
    }

    func signOut() async throws {
        try await store.signOut()
    }

    func currentUserId() async throws -> String? {
        await store.currentUserId
    }
}

struct MockWorkspaceRepository: WorkspaceRepository {
    let store: MockRepositoryStore

    func listWorkspacesForCurrentUser() async throws -> [DomainWorkspace] {
        await store.listWorkspaces()
    }

    func listMembers(workspaceId: String) async throws -> [DomainWorkspaceMember] {
        await store.listMembers(workspaceId: workspaceId)
    }

    func listInvites(workspaceId: String) async throws -> [WorkspaceInvite] {
        await store.listInvites(workspaceId: workspaceId)
    }

    func createWorkspace(name: String, defaultCurrency: String) async throws -> DomainWorkspace {
        await store.createWorkspace(name: name, defaultCurrency: defaultCurrency)
    }

    func acceptInvite(id: String) async throws -> DomainWorkspace {
        try await store.acceptInvite(id: id)
    }

    func inviteMember(workspaceId: String, email: String, role: WorkspaceRole) async throws -> WorkspaceInvite {
        await store.inviteMember(workspaceId: workspaceId, email: email, role: role)
    }

    func cancelInvite(id: String) async throws {
        await store.cancelInvite(id: id)
    }

    func updateMemberRole(id: String, role: WorkspaceRole) async throws -> DomainWorkspaceMember {
        try await store.updateMemberRole(id: id, role: role)
    }

    func removeMember(id: String) async throws {
        try await store.removeMember(id: id)
    }
}

struct MockProjectRepository: ProjectRepository {
    let store: MockRepositoryStore

    func listProjects(workspaceId: String) async throws -> [DomainProject] {
        await store.listProjects(workspaceId: workspaceId)
    }

    func createProject(_ project: DomainProject) async throws -> DomainProject {
        await store.createProject(project)
    }

    func updateProject(_ project: DomainProject) async throws -> DomainProject {
        try await store.updateProject(project)
    }

    func archiveProject(id: String) async throws {
        try await store.archiveProject(id: id)
    }
}

struct MockExpenseRepository: ExpenseRepository {
    let store: MockRepositoryStore

    func listExpenses(filters: ExpenseFilters) async throws -> [DomainExpense] {
        await store.listExpenses(filters: filters)
    }

    func listEvents(expenseId: String) async throws -> [ExpenseWorkflowEvent] {
        await store.listEvents(expenseId: expenseId)
    }

    func createDraft(_ input: ExpenseDraftInput) async throws -> DomainExpense {
        try await store.createDraft(input)
    }

    func submitExpense(id: String) async throws -> DomainExpense {
        try await store.submitExpense(id: id)
    }

    func resubmitExpense(id: String) async throws -> DomainExpense {
        try await store.resubmitExpense(id: id)
    }

    func cancelExpense(id: String, reason: String?) async throws -> DomainExpense {
        try await store.cancelExpense(id: id, reason: reason)
    }

    func approveExpense(id: String, note: String?) async throws -> DomainExpense {
        try await store.approveExpense(id: id, note: note)
    }

    func rejectExpense(id: String, reason: String) async throws -> DomainExpense {
        try await store.rejectExpense(id: id, reason: reason)
    }

    func confirmPurchase(id: String, input: PurchaseConfirmationInput) async throws -> DomainExpense {
        try await store.confirmPurchase(id: id, input: input)
    }

    func markReimbursed(id: String, input: ReimbursementInput) async throws -> DomainExpense {
        try await store.markReimbursed(id: id, input: input)
    }

    func archiveExpense(id: String) async throws -> DomainExpense {
        try await store.archiveExpense(id: id)
    }

    func unarchiveExpense(id: String) async throws -> DomainExpense {
        try await store.unarchiveExpense(id: id)
    }

    func deleteExpense(id: String) async throws {
        await store.deleteExpense(id: id)
    }
}

struct MockAttachmentRepository: AttachmentRepository {
    let store: MockRepositoryStore

    func listAttachments(expenseId: String) async throws -> [ExpenseAttachment] {
        await store.listAttachments(expenseId: expenseId)
    }

    func uploadAttachment(expenseId: String, kind: ExpenseAttachment.Kind, fileName: String, contentType: String, data: Data) async throws -> ExpenseAttachment {
        try await store.uploadAttachment(expenseId: expenseId, kind: kind, fileName: fileName, contentType: contentType, data: data)
    }

    func deleteAttachment(id: String) async throws {
        await store.deleteAttachment(id: id)
    }
}

struct MockReceiptScanRepository: ReceiptScanRepository {
    let store: MockRepositoryStore

    func startScan(attachmentId: String) async throws -> ReceiptScanResult {
        try await store.startScan(attachmentId: attachmentId)
    }

    func getScanResult(id: String) async throws -> ReceiptScanResult {
        try await store.getScanResult(id: id)
    }

    func confirmScanField(scanId: String, fieldId: String, normalizedValue: String) async throws -> ReceiptScanResult {
        try await store.confirmScanField(scanId: scanId, fieldId: fieldId, normalizedValue: normalizedValue)
    }
}

struct MockRepositoryContainer: Sendable {
    let auth: any AuthRepository
    let workspaces: any WorkspaceRepository
    let projects: any ProjectRepository
    let expenses: any ExpenseRepository
    let attachments: any AttachmentRepository
    let receiptScans: any ReceiptScanRepository

    static func make() -> MockRepositoryContainer {
        let store = MockRepositoryStore()
        return MockRepositoryContainer(
            auth: MockAuthRepository(store: store),
            workspaces: MockWorkspaceRepository(store: store),
            projects: MockProjectRepository(store: store),
            expenses: MockExpenseRepository(store: store),
            attachments: MockAttachmentRepository(store: store),
            receiptScans: MockReceiptScanRepository(store: store)
        )
    }
}

private extension ExpenseStatus {
    var workflowStatus: ExpenseWorkflowStatus {
        switch self {
        case .pending: return .pendingManagerApproval
        case .approved: return .approved
        case .rejected: return .rejected
        case .purchased: return .readyForReimbursement
        case .reimbursed: return .reimbursed
        }
    }
}

private extension MemberRole {
    var workspaceRole: WorkspaceRole {
        switch self {
        case .employee, .submitter: return .employee
        case .approver, .manager: return .manager
        case .admin: return .admin
        }
    }
}

private extension Color {
    var hexString: String {
        guard let components = UIColor(self).cgColor.components else { return "878E9F" }
        let redComponent = components[safe: 0] ?? 0
        let greenComponent = components[safe: 1] ?? redComponent
        let blueComponent = components[safe: 2] ?? redComponent
        let red = Int(redComponent * 255)
        let green = Int(greenComponent * 255)
        let blue = Int(blueComponent * 255)
        return String(format: "%02X%02X%02X", red, green, blue)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
