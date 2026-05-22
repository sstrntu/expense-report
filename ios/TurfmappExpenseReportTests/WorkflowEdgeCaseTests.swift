import XCTest
@testable import TurfmappExpenseReport

/// Covers `ExpenseWorkflow` cases not exercised by `ExpenseWorkflowTests`:
/// - `canCancel` for every status in the state machine
/// - `canMarkReimbursed` without a role argument
/// - `financeOnly` routing (auto-approval path goes straight to finance)
/// - `autoReimburse` routing (no finance step at all)
/// - Threshold boundary conditions (exactly at threshold vs. one cent over)
final class WorkflowEdgeCaseTests: XCTestCase {

    // MARK: - canCancel — full state machine

    func testCancellableStatuses() {
        let cancellable: [ExpenseWorkflowStatus] = [
            .submitted, .scanProcessing, .pendingManagerApproval, .pendingFinanceReview, .approved
        ]
        for status in cancellable {
            XCTAssertTrue(
                ExpenseWorkflow.canCancel(expense(status: status)),
                "\(status) should be cancellable"
            )
        }
    }

    func testNonCancellableStatuses() {
        let nonCancellable: [ExpenseWorkflowStatus] = [
            .draft, .scanFailed, .rejected, .purchaseConfirmed,
            .readyForReimbursement, .reimbursed, .cancelled, .archived
        ]
        for status in nonCancellable {
            XCTAssertFalse(
                ExpenseWorkflow.canCancel(expense(status: status)),
                "\(status) should not be cancellable"
            )
        }
    }

    // MARK: - canMarkReimbursed (without role)

    func testCanMarkReimbursedForReadyAndPendingFinance() {
        XCTAssertTrue(ExpenseWorkflow.canMarkReimbursed(expense(status: .readyForReimbursement)))
        XCTAssertTrue(ExpenseWorkflow.canMarkReimbursed(expense(status: .pendingFinanceReview)))
    }

    func testCannotMarkReimbursedForOtherStatuses() {
        let ineligible: [ExpenseWorkflowStatus] = [
            .draft, .submitted, .pendingManagerApproval, .approved,
            .purchaseConfirmed, .reimbursed, .rejected, .cancelled
        ]
        for status in ineligible {
            XCTAssertFalse(
                ExpenseWorkflow.canMarkReimbursed(expense(status: status)),
                "\(status) should not allow reimbursement marking"
            )
        }
    }

    // MARK: - financeOnly routing

    func testFinanceOnlyRoutesStraightToFinanceReviewUnderThreshold() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .financeOnly),
                amount: money(50)
            ),
            .pendingFinanceReview
        )
    }

    func testFinanceOnlyStillRequiresManagerApprovalOverThreshold() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .financeOnly),
                amount: money(150)   // threshold is 100
            ),
            .pendingManagerApproval
        )
    }

    func testFinanceOnlyManagerApprovalLeadsToFinanceReview() {
        // After a manager approves a claim on a finance-only project, it goes to finance.
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterManagerApproval(
                kind: .reimbursementClaim,
                project: project(routingMode: .financeOnly)
            ),
            .pendingFinanceReview
        )
    }

    // MARK: - autoReimburse routing

    func testAutoReimburseRoutesDirectlyToReadyUnderThreshold() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .autoReimburse),
                amount: money(50)
            ),
            .readyForReimbursement
        )
    }

    func testAutoReimburseAfterManagerApprovalSkipsFinance() {
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterManagerApproval(
                kind: .reimbursementClaim,
                project: project(routingMode: .autoReimburse)
            ),
            .readyForReimbursement
        )
    }

    func testAutoReimbursePurchaseConfirmationSkipsFinance() {
        XCTAssertEqual(
            ExpenseWorkflow.statusAfterPurchaseConfirmation(project: project(routingMode: .autoReimburse)),
            .readyForReimbursement
        )
    }

    // MARK: - Threshold boundary conditions

    func testExactlyAtThresholdIsAutoApproved() {
        // amount == threshold → auto-approve path (not manager queue)
        XCTAssertNotEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .managerOnly, threshold: 100),
                amount: money(100)   // exactly at threshold
            ),
            .pendingManagerApproval
        )
    }

    func testOneMinorUnitOverThresholdRequiresManagerApproval() {
        let justOver = MoneyAmount(minorUnits: 10001, currency: "USD") // $100.01
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .managerOnly, threshold: 100),
                amount: justOver
            ),
            .pendingManagerApproval
        )
    }

    // MARK: - autoApproveThenFinance routing

    func testAutoApproveThenFinanceSendsToFinanceUnderThreshold() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .autoApproveThenFinance),
                amount: money(50)
            ),
            .pendingFinanceReview
        )
    }

    func testAutoApproveThenFinanceRequiresManagerApprovalOverThreshold() {
        XCTAssertEqual(
            ExpenseWorkflow.initialSubmittedStatus(
                kind: .preApproval,
                project: project(routingMode: .autoApproveThenFinance),
                amount: money(150)
            ),
            .pendingManagerApproval
        )
    }
}

// MARK: - Helpers

private extension WorkflowEdgeCaseTests {

    func money(_ majorUnits: Int) -> MoneyAmount {
        MoneyAmount(minorUnits: majorUnits * 100, currency: "USD")
    }

    func project(routingMode: ProjectRoutingMode, threshold: Int = 100) -> DomainProject {
        DomainProject(
            id: "p1", workspaceId: "ws1", name: "Test",
            budget: money(10_000),
            budgetPeriod: "monthly", ownerMembershipId: "m_owner",
            visibility: "workspace", routingMode: routingMode,
            overBudgetBehavior: .warn, allowedCategoryIds: [],
            approvalThreshold: money(threshold),
            receiptRequiredThreshold: money(75),
            currentUserProjectRole: .projectAdmin, isArchived: false
        )
    }

    func expense(status: ExpenseWorkflowStatus, kind: ExpenseKind = .reimbursementClaim) -> DomainExpense {
        DomainExpense(
            id: "e1", workspaceId: "ws1", projectId: "p1",
            submittedByMembershipId: "m1", kind: kind,
            status: status, merchant: "Test",
            amount: money(50),
            categoryId: "other", businessPurpose: "Test",
            purchaseDate: nil, neededByDate: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            submittedAt: Date(timeIntervalSince1970: 0),
            isArchived: status == .archived
        )
    }
}
