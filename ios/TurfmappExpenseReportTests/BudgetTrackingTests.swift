import XCTest
@testable import TurfmappExpenseReport

/// Tests for the project budget tracking logic used in `DomainProjectRow`.
/// The helper functions mirror the private `budgetAmount(of:)`, `paid`,
/// `pending`, and `isOverBudget` properties so they can be exercised as
/// pure functions without instantiating a SwiftUI view.
final class BudgetTrackingTests: XCTestCase {

    private static let paidStatuses: Set<ExpenseWorkflowStatus> = [.reimbursed]
    private static let pendingStatuses: Set<ExpenseWorkflowStatus> = [
        .submitted, .pendingManagerApproval, .approved,
        .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement
    ]

    // MARK: - budgetAmount(of:)

    func testSameCurrencyExpenseContributesNativeAmount() {
        let p = project(currency: "USD")
        let e = expense(amount: money(200, "USD"), amountInBase: nil)
        XCTAssertEqual(budgetAmount(of: e, project: p), 200.00)
    }

    func testForeignExpenseWithSnapshotInBudgetCurrencyUsesSnapshot() {
        let p = project(currency: "USD")
        let e = expense(amount: money(7100, "THB"), amountInBase: money(200, "USD"))
        XCTAssertEqual(budgetAmount(of: e, project: p), 200.00)
    }

    func testForeignExpenseWithSnapshotInWrongCurrencyIsSkipped() {
        // Budget is USD, snapshot is EUR — no usable conversion path, skipped.
        let p = project(currency: "USD")
        let e = expense(amount: money(7100, "THB"), amountInBase: money(186, "EUR"))
        XCTAssertNil(budgetAmount(of: e, project: p))
    }

    func testForeignExpenseWithNoSnapshotIsSkipped() {
        let p = project(currency: "USD")
        let e = expense(amount: money(7100, "THB"), amountInBase: nil)
        XCTAssertNil(budgetAmount(of: e, project: p))
    }

    // MARK: - paid / pending totals

    func testPaidSumsReimbursedExpensesOnly() {
        let p = project(currency: "USD", budgetMajor: 1000)
        let expenses = [
            expense(amount: money(300, "USD"), status: .reimbursed),
            expense(amount: money(200, "USD"), status: .approved),          // pending
            expense(amount: money(100, "USD"), status: .rejected),          // not counted
        ]
        XCTAssertEqual(paid(expenses, project: p), 300.00)
    }

    func testPendingSumsInFlightExpenses() {
        let p = project(currency: "USD", budgetMajor: 1000)
        let inFlight: [ExpenseWorkflowStatus] = [
            .submitted, .pendingManagerApproval, .approved,
            .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement
        ]
        let expenses = inFlight.map { expense(amount: money(100, "USD"), status: $0) }
        XCTAssertEqual(pending(expenses, project: p), Double(inFlight.count) * 100.0)
    }

    func testDraftAndRejectedAndCancelledAreNotCounted() {
        let p = project(currency: "USD", budgetMajor: 1000)
        let ignored: [ExpenseWorkflowStatus] = [.draft, .rejected, .cancelled, .archived]
        let expenses = ignored.map { expense(amount: money(500, "USD"), status: $0) }
        XCTAssertEqual(paid(expenses, project: p), 0)
        XCTAssertEqual(pending(expenses, project: p), 0)
    }

    func testForeignExpenseWithNoSnapshotIsExcludedFromTotals() {
        let p = project(currency: "USD", budgetMajor: 1000)
        let e = expense(amount: money(3550, "THB"), amountInBase: nil, status: .reimbursed)
        XCTAssertEqual(paid([e], project: p), 0)
    }

    // MARK: - isOverBudget

    func testNotOverBudgetWhenCommittedUnderBudget() {
        let p = project(currency: "USD", budgetMajor: 1000)
        let expenses = [
            expense(amount: money(400, "USD"), status: .reimbursed),
            expense(amount: money(300, "USD"), status: .approved),
        ]
        XCTAssertFalse(isOverBudget(expenses, project: p))
    }

    func testOverBudgetWhenCommittedExceedsBudget() {
        let p = project(currency: "USD", budgetMajor: 1000)
        let expenses = [
            expense(amount: money(700, "USD"), status: .reimbursed),
            expense(amount: money(400, "USD"), status: .approved),   // 1100 total
        ]
        XCTAssertTrue(isOverBudget(expenses, project: p))
    }

    func testNeverOverBudgetWhenBudgetIsZero() {
        // Zero budget means "no limit" — should never flag as over budget.
        let p = project(currency: "USD", budgetMajor: 0)
        let expenses = [expense(amount: money(999_999, "USD"), status: .reimbursed)]
        XCTAssertFalse(isOverBudget(expenses, project: p))
    }

    func testExactlyAtBudgetIsNotOverBudget() {
        let p = project(currency: "USD", budgetMajor: 500)
        let expenses = [expense(amount: money(500, "USD"), status: .reimbursed)]
        XCTAssertFalse(isOverBudget(expenses, project: p))
    }

    func testOneMinorUnitOverBudgetIsOverBudget() {
        let p = project(currency: "USD", budgetMajor: 500)
        // $500.01 committed
        let e = DomainExpense(
            id: "e1", workspaceId: "ws1", projectId: "p1",
            submittedByMembershipId: "m1", kind: .reimbursementClaim,
            status: .reimbursed, merchant: "Test",
            amount: MoneyAmount(minorUnits: 50001, currency: "USD"),
            categoryId: "other", businessPurpose: "Test",
            purchaseDate: nil, neededByDate: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            submittedAt: nil, isArchived: false
        )
        XCTAssertTrue(isOverBudget([e], project: p))
    }

    // MARK: - Multi-currency budget

    func testForeignExpenseWithSnapshotContributesToBudget() {
        let p = project(currency: "USD", budgetMajor: 1000)
        let expenses = [
            expense(amount: money(7100, "THB"), amountInBase: money(200, "USD"), status: .reimbursed),
            expense(amount: money(300, "USD"), amountInBase: nil, status: .approved),
        ]
        // 200 paid + 300 pending = 500 committed; budget 1000
        XCTAssertEqual(paid(expenses, project: p), 200)
        XCTAssertEqual(pending(expenses, project: p), 300)
        XCTAssertFalse(isOverBudget(expenses, project: p))
    }
}

// MARK: - Helpers

private extension BudgetTrackingTests {

    func money(_ majorUnits: Int, _ currency: String) -> MoneyAmount {
        MoneyAmount(minorUnits: majorUnits * 100, currency: currency)
    }

    func project(currency: String, budgetMajor: Int = 1000) -> DomainProject {
        DomainProject(
            id: "p1", workspaceId: "ws1", name: "Test Project",
            budget: money(budgetMajor, currency),
            budgetPeriod: "monthly", ownerMembershipId: "m_owner",
            visibility: "workspace", routingMode: .managerOnly,
            overBudgetBehavior: .warn, allowedCategoryIds: [],
            approvalThreshold: money(100, currency),
            receiptRequiredThreshold: money(75, currency),
            currentUserProjectRole: .submitter, isArchived: false
        )
    }

    func expense(
        amount: MoneyAmount,
        amountInBase: MoneyAmount? = nil,
        status: ExpenseWorkflowStatus = .reimbursed
    ) -> DomainExpense {
        DomainExpense(
            id: UUID().uuidString, workspaceId: "ws1", projectId: "p1",
            submittedByMembershipId: "m1", kind: .reimbursementClaim,
            status: status, merchant: "Test",
            amount: amount, amountInBase: amountInBase,
            fxRate: nil, fxRateAsOf: nil, fxSource: nil,
            categoryId: "other", businessPurpose: "Test",
            purchaseDate: nil, neededByDate: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            submittedAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
    }

    /// Mirrors `DomainProjectRow.budgetAmount(of:)`.
    func budgetAmount(of expense: DomainExpense, project: DomainProject) -> Double? {
        let base = project.budget.currency
        if expense.amount.currency == base { return expense.amount.decimalValue }
        if let inBase = expense.amountInBase, inBase.currency == base { return inBase.decimalValue }
        return nil
    }

    func paid(_ expenses: [DomainExpense], project: DomainProject) -> Double {
        expenses
            .filter { Self.paidStatuses.contains($0.status) }
            .compactMap { budgetAmount(of: $0, project: project) }
            .reduce(0, +)
    }

    func pending(_ expenses: [DomainExpense], project: DomainProject) -> Double {
        expenses
            .filter { Self.pendingStatuses.contains($0.status) }
            .compactMap { budgetAmount(of: $0, project: project) }
            .reduce(0, +)
    }

    func isOverBudget(_ expenses: [DomainExpense], project: DomainProject) -> Bool {
        let committed = paid(expenses, project: project) + pending(expenses, project: project)
        let budget = project.budget.decimalValue
        return committed > budget && budget > 0
    }
}
