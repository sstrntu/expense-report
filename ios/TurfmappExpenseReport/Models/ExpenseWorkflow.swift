import Foundation

enum ExpenseWorkflow {
    static func initialSubmittedStatus(kind: ExpenseKind, project: DomainProject, amount: MoneyAmount) -> ExpenseWorkflowStatus {
        switch kind {
        case .preApproval:
            return amount.minorUnits <= project.approvalThreshold.minorUnits
                ? statusAfterAutoApproval(project: project)
                : .pendingManagerApproval
        case .reimbursementClaim:
            return amount.minorUnits <= project.approvalThreshold.minorUnits
                ? .pendingFinanceReview
                : .pendingManagerApproval
        }
    }

    static func statusAfterManagerApproval(kind: ExpenseKind, project: DomainProject) -> ExpenseWorkflowStatus {
        switch kind {
        case .preApproval:
            return .approved
        case .reimbursementClaim:
            switch project.routingMode {
            case .managerOnly, .autoReimburse:
                return .readyForReimbursement
            case .financeOnly, .managerThenFinance, .autoApproveThenFinance:
                return .pendingFinanceReview
            }
        }
    }

    static func statusAfterPurchaseConfirmation(project: DomainProject) -> ExpenseWorkflowStatus {
        switch project.routingMode {
        case .managerOnly, .autoReimburse:
            return .readyForReimbursement
        case .financeOnly, .managerThenFinance, .autoApproveThenFinance:
            return .pendingFinanceReview
        }
    }

    static func canConfirmPurchase(_ expense: DomainExpense) -> Bool {
        expense.kind == .preApproval && expense.status == .approved
    }

    /// Authorization-aware overload: only the submitter can confirm their own
    /// purchase. Server-side RLS ("submitters can update own draft expenses")
    /// already enforces this, but the iOS UI previously exposed the action to
    /// anyone with reviewer/finance visibility — confusing UX and a foot-gun.
    static func canConfirmPurchase(_ expense: DomainExpense, currentMembershipId: String?) -> Bool {
        guard canConfirmPurchase(expense) else { return false }
        guard let me = currentMembershipId else { return false }
        return expense.submittedByMembershipId == me
    }

    static func canApprove(_ expense: DomainExpense) -> Bool {
        expense.status == .pendingManagerApproval
    }

    static func canApprove(_ expense: DomainExpense, role: WorkspaceRole) -> Bool {
        canApprove(expense) && role.canApproveExpenses
    }

    static func canReject(_ expense: DomainExpense) -> Bool {
        expense.status == .pendingManagerApproval || expense.status == .pendingFinanceReview
    }

    static func canResubmit(_ expense: DomainExpense) -> Bool {
        expense.status == .rejected
    }

    static func canCancel(_ expense: DomainExpense) -> Bool {
        switch expense.status {
        case .submitted, .scanProcessing, .pendingManagerApproval, .pendingFinanceReview, .approved:
            return true
        default:
            return false
        }
    }

    static func canReject(_ expense: DomainExpense, role: WorkspaceRole) -> Bool {
        switch expense.status {
        case .pendingManagerApproval:
            return role.canApproveExpenses
        case .pendingFinanceReview:
            return role.canReimburseExpenses
        default:
            return false
        }
    }

    static func canMarkReimbursed(_ expense: DomainExpense) -> Bool {
        expense.status == .readyForReimbursement || expense.status == .pendingFinanceReview
    }

    static func canMarkReimbursed(_ expense: DomainExpense, role: WorkspaceRole) -> Bool {
        canMarkReimbursed(expense) && role.canReimburseExpenses
    }

    private static func statusAfterAutoApproval(project: DomainProject) -> ExpenseWorkflowStatus {
        switch project.routingMode {
        case .managerOnly:
            return .approved
        case .financeOnly, .managerThenFinance, .autoApproveThenFinance:
            return .pendingFinanceReview
        case .autoReimburse:
            return .readyForReimbursement
        }
    }
}

extension WorkspaceRole {
    var canApproveExpenses: Bool {
        self == .manager || self == .admin
    }

    var canReimburseExpenses: Bool {
        self == .finance || self == .admin
    }
}

extension ProjectRole {
    var canSubmitExpenses: Bool {
        switch self {
        case .submitter, .approver, .finance, .projectAdmin:
            return true
        case .viewer:
            return false
        }
    }
}
