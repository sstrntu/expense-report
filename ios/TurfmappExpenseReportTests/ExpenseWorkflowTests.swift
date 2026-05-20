import XCTest
@testable import TurfmappExpenseReport

final class ExpenseWorkflowTests: XCTestCase {
    func testPreApprovalUnderThresholdUsesProjectRouting() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .managerOnly),
                amount: money(50)
            ),
            .approved
        )
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .managerThenFinance),
                amount: money(50)
            ),
            .pendingFinanceReview
        )
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .autoReimburse),
                amount: money(50)
            ),
            .readyForReimbursement
        )
    }

    func testSubmittedExpenseOverThresholdRequiresManagerApproval() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .autoApproveThenFinance),
                amount: money(150)
            ),
            .pendingManagerApproval
        )
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .reimbursementClaim,
                project: project(routingMode: .financeOnly),
                amount: money(150)
            ),
            .pendingManagerApproval
        )
    }

    func testReimbursementClaimUnderThresholdSkipsToFinanceReview() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .reimbursementClaim,
                project: project(routingMode: .managerOnly),
                amount: money(50)
            ),
            .pendingFinanceReview
        )
    }

    func testStatusAfterManagerApprovalRoutesByExpenseKindAndProjectPolicy() {
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterManagerApproval(
                kind: .preApproval,
                project: project(routingMode: .managerThenFinance)
            ),
            .approved
        )
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterManagerApproval(
                kind: .reimbursementClaim,
                project: project(routingMode: .managerOnly)
            ),
            .readyForReimbursement
        )
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterManagerApproval(
                kind: .reimbursementClaim,
                project: project(routingMode: .managerThenFinance)
            ),
            .pendingFinanceReview
        )
    }

    func testPurchaseConfirmationRoutesToFinanceWhenRequired() {
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterPurchaseConfirmation(
                project: project(routingMode: .managerOnly)
            ),
            .readyForReimbursement
        )
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterPurchaseConfirmation(
                project: project(routingMode: .autoApproveThenFinance)
            ),
            .pendingFinanceReview
        )
    }

    func testAvailableActionsDependOnStatusAndKind() {
        let approvedPreApproval = expense(kind: .preApproval, status: .approved)
        let approvedClaim = expense(kind: .reimbursementClaim, status: .approved)
        let pendingManager = expense(kind: .reimbursementClaim, status: .pendingManagerApproval)
        let pendingFinance = expense(kind: .reimbursementClaim, status: .pendingFinanceReview)
        let rejected = expense(kind: .reimbursementClaim, status: .rejected)
        let draft = expense(kind: .preApproval, status: .draft)

        XCTAssertTrue(ExpenseWorkflow.canConfirmPurchase(approvedPreApproval))
        XCTAssertFalse(ExpenseWorkflow.canConfirmPurchase(approvedClaim))
        XCTAssertTrue(ExpenseWorkflow.canApprove(pendingManager))
        XCTAssertTrue(ExpenseWorkflow.canReject(pendingManager))
        XCTAssertTrue(ExpenseWorkflow.canReject(pendingFinance))
        XCTAssertTrue(ExpenseWorkflow.canResubmit(rejected))
        XCTAssertFalse(ExpenseWorkflow.canCancel(draft))
    }

    func testRoleGatedActionsRequireMatchingWorkspacePermission() {
        let pendingManager = expense(kind: .preApproval, status: .pendingManagerApproval)
        let pendingFinance = expense(kind: .reimbursementClaim, status: .pendingFinanceReview)
        let readyToPay = expense(kind: .reimbursementClaim, status: .readyForReimbursement)

        XCTAssertTrue(ExpenseWorkflow.canApprove(pendingManager, role: .manager))
        XCTAssertFalse(ExpenseWorkflow.canApprove(pendingManager, role: .finance))
        XCTAssertTrue(ExpenseWorkflow.canReject(pendingManager, role: .admin))
        XCTAssertFalse(ExpenseWorkflow.canReject(pendingManager, role: .employee))
        XCTAssertTrue(ExpenseWorkflow.canReject(pendingFinance, role: .finance))
        XCTAssertFalse(ExpenseWorkflow.canReject(pendingFinance, role: .manager))
        XCTAssertTrue(ExpenseWorkflow.canMarkReimbursed(readyToPay, role: .finance))
        XCTAssertFalse(ExpenseWorkflow.canMarkReimbursed(readyToPay, role: .manager))
    }
}

private extension ExpenseWorkflowTests {
    func money(_ majorUnits: Int) -> MoneyAmount {
        MoneyAmount(minorUnits: majorUnits * 100, currency: "USD")
    }

    func project(routingMode: ProjectRoutingMode, threshold: Int = 100) -> DomainProject {
        DomainProject(
            id: "project_test",
            workspaceId: "workspace_test",
            name: "Test Project",
            budget: money(10_000),
            budgetPeriod: "monthly",
            ownerMembershipId: "member_owner",
            visibility: "workspace",
            routingMode: routingMode,
            overBudgetBehavior: .warn,
            allowedCategoryIds: ["travel", "meals"],
            approvalThreshold: money(threshold),
            receiptRequiredThreshold: money(75),
            currentUserProjectRole: .projectAdmin,
            isArchived: false
        )
    }

    func expense(kind: ExpenseKind, status: ExpenseWorkflowStatus) -> DomainExpense {
        DomainExpense(
            id: "expense_test",
            workspaceId: "workspace_test",
            projectId: "project_test",
            submittedByMembershipId: "member_submitter",
            kind: kind,
            status: status,
            merchant: "Test Merchant",
            amount: money(50),
            categoryId: "travel",
            businessPurpose: "Client meeting",
            purchaseDate: nil,
            neededByDate: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            submittedAt: Date(timeIntervalSince1970: 0),
            isArchived: status == .archived
        )
    }
}
