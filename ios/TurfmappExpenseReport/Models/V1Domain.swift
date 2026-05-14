import Foundation

enum ExpenseKind: String, Codable, CaseIterable, Hashable, Sendable {
    case preApproval = "pre_approval"
    case reimbursementClaim = "reimbursement_claim"

    var label: String {
        switch self {
        case .preApproval: return "Pre-approval"
        case .reimbursementClaim: return "Reimbursement"
        }
    }
}

enum ExpenseWorkflowStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case draft
    case submitted
    case scanProcessing = "scan_processing"
    case scanFailed = "scan_failed"
    case pendingManagerApproval = "pending_manager_approval"
    case pendingFinanceReview = "pending_finance_review"
    case approved
    case rejected
    case purchaseConfirmed = "purchase_confirmed"
    case readyForReimbursement = "ready_for_reimbursement"
    case reimbursed
    case cancelled
    case archived

    var displayLabel: String {
        switch self {
        case .draft: return "Draft"
        case .submitted: return "Submitted"
        case .scanProcessing: return "Scanning receipt"
        case .scanFailed: return "Scan failed"
        case .pendingManagerApproval: return "Awaiting approval"
        case .pendingFinanceReview: return "Finance review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        case .purchaseConfirmed: return "Awaiting reimbursement"
        case .readyForReimbursement: return "Ready to pay"
        case .reimbursed: return "Reimbursed"
        case .cancelled: return "Cancelled"
        case .archived: return "Archived"
        }
    }
}

enum WorkspaceRole: String, Codable, CaseIterable, Hashable, Sendable {
    case employee
    case manager
    case finance
    case admin
}

enum ProjectRole: String, Codable, CaseIterable, Hashable, Sendable {
    case viewer
    case submitter
    case approver
    case finance
    case projectAdmin = "project_admin"
}

enum ProjectRoutingMode: String, Codable, CaseIterable, Hashable, Sendable {
    case managerOnly = "manager_only"
    case financeOnly = "finance_only"
    case managerThenFinance = "manager_then_finance"
    case autoApproveThenFinance = "auto_approve_then_finance"
    case autoReimburse = "auto_reimburse"
}

enum OverBudgetBehavior: String, Codable, CaseIterable, Hashable, Sendable {
    case warn
    case escalate
    case block
}

enum ReceiptScanStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case notStarted = "not_started"
    case uploading
    case processing
    case needsReview = "needs_review"
    case confirmed
    case failed
}

enum ScanFieldConfidence: String, Codable, CaseIterable, Hashable, Sendable {
    case high
    case medium
    case low
    case manual
}

enum ReimbursementPaymentMethod: String, Codable, CaseIterable, Hashable, Sendable {
    case bankTransfer = "bank_transfer"
    case qrCode = "qr_code"
    case cash
    case card
    case cheque
    case other
}

struct MoneyAmount: Codable, Hashable, Sendable {
    let minorUnits: Int
    let currency: String
}

struct DomainWorkspace: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let abbr: String
    let brandColorHex: String
    let defaultCurrency: String
    let currentUserRole: WorkspaceRole
}

struct DomainWorkspaceMember: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let workspaceId: String
    let userId: String
    let displayName: String
    let email: String
    let role: WorkspaceRole
    let status: String
    let avatarColorHex: String
}

struct DomainProject: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let workspaceId: String
    let name: String
    let budget: MoneyAmount
    let budgetPeriod: String
    let ownerMembershipId: String
    let visibility: String
    let routingMode: ProjectRoutingMode
    let overBudgetBehavior: OverBudgetBehavior
    let allowedCategoryIds: [String]
    let approvalThreshold: MoneyAmount
    let receiptRequiredThreshold: MoneyAmount
    let currentUserProjectRole: ProjectRole?
    let isArchived: Bool
}

struct DomainExpense: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let workspaceId: String
    let projectId: String
    let submittedByMembershipId: String
    let kind: ExpenseKind
    let status: ExpenseWorkflowStatus
    let merchant: String
    let amount: MoneyAmount
    let categoryId: String
    let businessPurpose: String
    let purchaseDate: Date?
    let neededByDate: Date?
    let createdAt: Date
    let submittedAt: Date?
    let isArchived: Bool
}

struct ExpenseWorkflowEvent: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let expenseId: String
    let actorMembershipId: String
    let fromStatus: ExpenseWorkflowStatus?
    let toStatus: ExpenseWorkflowStatus?
    let eventType: String
    let note: String?
    let createdAt: Date
}

struct ExpenseAttachment: Identifiable, Codable, Hashable, Sendable {
    enum Kind: String, Codable, Hashable, Sendable {
        case submittedReceipt = "submitted_receipt"
        case purchaseReceipt = "purchase_receipt"
        case reimbursementProof = "reimbursement_proof"
        case supportingDocument = "supporting_document"
    }

    let id: String
    let workspaceId: String
    let expenseId: String
    let kind: Kind
    let fileName: String
    let contentType: String
    let storageKey: String
    let createdAt: Date
}

struct ReceiptScanField: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let fieldName: String
    let extractedValue: String
    let normalizedValue: String?
    let confidence: ScanFieldConfidence
    let confirmedByUser: Bool
}

struct ReceiptScanResult: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let attachmentId: String
    let expenseId: String
    let status: ReceiptScanStatus
    let fields: [ReceiptScanField]
    let errorMessage: String?
}

struct WorkspaceInvite: Identifiable, Codable, Hashable, Sendable {
    enum Status: String, Codable, Hashable, Sendable {
        case pending
        case accepted
        case expired
        case cancelled
    }

    let id: String
    let workspaceId: String
    let email: String
    let role: WorkspaceRole
    let status: Status
    let expiresAt: Date
}

enum NotificationEventType: String, Codable, CaseIterable, Hashable, Sendable {
    case expenseSubmitted = "expense_submitted"
    case expenseApproved = "expense_approved"
    case expenseRejected = "expense_rejected"
    case purchaseConfirmed = "purchase_confirmed"
    case reimbursementSent = "reimbursement_sent"
    case workspaceInvite = "workspace_invite"
    case projectBudgetWarning = "project_budget_warning"
}

enum NotificationChannel: String, Codable, CaseIterable, Hashable, Sendable {
    case inApp = "in_app"
    case email
    case push
}

struct DomainNotification: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let workspaceId: String
    let recipientMembershipId: String
    let eventType: NotificationEventType
    let channel: NotificationChannel
    let title: String
    let body: String
    let deepLinkRoute: String
    let isRead: Bool
    let createdAt: Date
}

struct NotificationPreference: Codable, Hashable, Sendable {
    let membershipId: String
    let eventType: NotificationEventType
    let enabledChannels: [NotificationChannel]
}

struct ReportFilters: Codable, Hashable, Sendable {
    let workspaceId: String
    let projectIds: [String]
    let memberIds: [String]
    let statuses: [ExpenseWorkflowStatus]
    let categoryIds: [String]
    let dateRange: ClosedRange<Date>?
}

enum ReportExportFormat: String, Codable, CaseIterable, Hashable, Sendable {
    case csv
    case pdf
    case receiptBundle = "receipt_bundle"
}
