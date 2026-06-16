import XCTest
@testable import TurfmappExpenseReport

final class PermissionMatrixTests: XCTestCase {
    func testWorkspaceRolesExposeExpectedWorkflowPermissions() {
        XCTAssertFalse(WorkspaceRole.employee.canApproveExpenses)
        XCTAssertFalse(WorkspaceRole.employee.canReimburseExpenses)

        XCTAssertTrue(WorkspaceRole.manager.canApproveExpenses)
        XCTAssertFalse(WorkspaceRole.manager.canReimburseExpenses)

        XCTAssertFalse(WorkspaceRole.finance.canApproveExpenses)
        XCTAssertTrue(WorkspaceRole.finance.canReimburseExpenses)

        XCTAssertTrue(WorkspaceRole.admin.canApproveExpenses)
        XCTAssertTrue(WorkspaceRole.admin.canReimburseExpenses)
    }

    func testProjectSubmitPermissionExcludesViewOnlyMembers() {
        XCTAssertFalse(ProjectRole.viewer.canSubmitExpenses)
        XCTAssertTrue(ProjectRole.submitter.canSubmitExpenses)
        XCTAssertTrue(ProjectRole.approver.canSubmitExpenses)
        XCTAssertTrue(ProjectRole.finance.canSubmitExpenses)
        XCTAssertTrue(ProjectRole.projectAdmin.canSubmitExpenses)
    }

    // MARK: – Submitter-gated actions

    func testCancelIsLimitedToSubmitterInCancellableStates() {
        let pending = expense(status: .pendingManagerApproval)

        XCTAssertTrue(ExpenseWorkflow.canCancel(pending, currentMembershipId: "member_submitter"))
        XCTAssertFalse(ExpenseWorkflow.canCancel(pending, currentMembershipId: "member_other"),
                       "Non-submitters must not see a cancel action the server would reject")
        XCTAssertFalse(ExpenseWorkflow.canCancel(pending, currentMembershipId: nil),
                       "Unknown membership (mid-refresh) must fail closed")

        let paid = expense(status: .reimbursed)
        XCTAssertFalse(ExpenseWorkflow.canCancel(paid, currentMembershipId: "member_submitter"),
                       "Reimbursed expenses are no longer cancellable even by the submitter")
    }

    func testResubmitIsLimitedToSubmitterOfRejectedExpense() {
        let rejected = expense(status: .rejected)

        XCTAssertTrue(ExpenseWorkflow.canResubmit(rejected, currentMembershipId: "member_submitter"))
        XCTAssertFalse(ExpenseWorkflow.canResubmit(rejected, currentMembershipId: "member_other"))
        XCTAssertFalse(ExpenseWorkflow.canResubmit(rejected, currentMembershipId: nil))

        let pending = expense(status: .pendingManagerApproval)
        XCTAssertFalse(ExpenseWorkflow.canResubmit(pending, currentMembershipId: "member_submitter"),
                       "Only rejected expenses can be resubmitted")
    }

    private func expense(status: ExpenseWorkflowStatus) -> DomainExpense {
        DomainExpense(
            id: "expense_test",
            workspaceId: "workspace_test",
            projectId: "project_test",
            submittedByMembershipId: "member_submitter",
            kind: .preApproval,
            status: status,
            merchant: "Test Merchant",
            amount: MoneyAmount(minorUnits: 5000, currency: "USD"),
            categoryId: "travel",
            businessPurpose: "Client meeting",
            purchaseDate: nil,
            neededByDate: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            submittedAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
    }
}
