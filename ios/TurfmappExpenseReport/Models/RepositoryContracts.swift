import Foundation

struct ExpenseFilters: Codable, Hashable, Sendable {
    var workspaceId: String
    var projectId: String?
    var status: ExpenseWorkflowStatus?
    var kind: ExpenseKind?
    var searchText: String?
    var dateRange: ClosedRange<Date>?
}

struct ExpenseDraftInput: Codable, Hashable, Sendable {
    let workspaceId: String
    let projectId: String
    let kind: ExpenseKind
    let merchant: String
    let amount: MoneyAmount
    let categoryId: String
    let businessPurpose: String
    let purchaseDate: Date?
    let neededByDate: Date?
}

struct PurchaseConfirmationInput: Codable, Hashable, Sendable {
    let finalAmount: MoneyAmount
    let purchaseDate: Date
    let receiptAttachmentId: String?
    let note: String?
}

struct ReimbursementInput: Codable, Hashable, Sendable {
    let amount: MoneyAmount
    let paymentMethod: ReimbursementPaymentMethod
    let paidAt: Date
    let reference: String?
    let proofAttachmentId: String?
}

struct PendingReceiptUpload: Codable, Hashable, Sendable {
    let kind: ExpenseAttachment.Kind
    let fileName: String
    let contentType: String
    let data: Data
}

protocol AuthRepository: Sendable {
    func signIn(email: String, password: String) async throws
    func signOut() async throws
    func currentUserId() async throws -> String?
}

protocol WorkspaceRepository: Sendable {
    func listWorkspacesForCurrentUser() async throws -> [DomainWorkspace]
    func listMembers(workspaceId: String) async throws -> [DomainWorkspaceMember]
    func listInvites(workspaceId: String) async throws -> [WorkspaceInvite]
    func createWorkspace(name: String, defaultCurrency: String) async throws -> DomainWorkspace
    func acceptInvite(id: String) async throws -> DomainWorkspace
    func inviteMember(workspaceId: String, email: String, role: WorkspaceRole) async throws -> WorkspaceInvite
    func cancelInvite(id: String) async throws
    func updateMemberRole(id: String, role: WorkspaceRole) async throws -> DomainWorkspaceMember
    func removeMember(id: String) async throws
}

protocol ProjectRepository: Sendable {
    func listProjects(workspaceId: String) async throws -> [DomainProject]
    func createProject(_ project: DomainProject) async throws -> DomainProject
    func updateProject(_ project: DomainProject) async throws -> DomainProject
    func archiveProject(id: String) async throws
}

protocol ExpenseRepository: Sendable {
    func listExpenses(filters: ExpenseFilters) async throws -> [DomainExpense]
    func listEvents(expenseId: String) async throws -> [ExpenseWorkflowEvent]
    func createDraft(_ input: ExpenseDraftInput) async throws -> DomainExpense
    func submitExpense(id: String) async throws -> DomainExpense
    func resubmitExpense(id: String) async throws -> DomainExpense
    func cancelExpense(id: String, reason: String?) async throws -> DomainExpense
    func approveExpense(id: String, note: String?) async throws -> DomainExpense
    func rejectExpense(id: String, reason: String) async throws -> DomainExpense
    func confirmPurchase(id: String, input: PurchaseConfirmationInput) async throws -> DomainExpense
    func markReimbursed(id: String, input: ReimbursementInput) async throws -> DomainExpense
    func archiveExpense(id: String) async throws -> DomainExpense
    func unarchiveExpense(id: String) async throws -> DomainExpense
    func deleteExpense(id: String) async throws
}

protocol AttachmentRepository: Sendable {
    func listAttachments(expenseId: String) async throws -> [ExpenseAttachment]
    func uploadAttachment(expenseId: String, kind: ExpenseAttachment.Kind, fileName: String, contentType: String, data: Data) async throws -> ExpenseAttachment
    func deleteAttachment(id: String) async throws
}

protocol ReceiptScanRepository: Sendable {
    func startScan(attachmentId: String) async throws -> ReceiptScanResult
    func getScanResult(id: String) async throws -> ReceiptScanResult
    func confirmScanField(scanId: String, fieldId: String, normalizedValue: String) async throws -> ReceiptScanResult
}

protocol NotificationRepository: Sendable {
    func listNotifications(workspaceId: String) async throws -> [DomainNotification]
    func markNotificationRead(id: String) async throws
    func updatePreferences(_ preferences: [NotificationPreference]) async throws
}

protocol ReportRepository: Sendable {
    func preview(filters: ReportFilters) async throws -> [DomainExpense]
    func export(filters: ReportFilters, format: ReportExportFormat) async throws -> URL
}
