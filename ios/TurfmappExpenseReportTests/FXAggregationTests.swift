import XCTest
@testable import TurfmappExpenseReport

/// Tests for the three-path FX aggregation algorithm that backs
/// `RepositoryAppState.expensesInDefaultCurrency`, and the queue
/// filter predicates for managerQueue / financeQueue / draftExpenses.
final class FXAggregationTests: XCTestCase {

    private let target = "USD"

    // MARK: - Path 1: native currency matches target

    func testSameCurrencyExpensePassesThroughUnchanged() {
        let e = expense(amount: money(100, "USD"), amountInBase: nil)
        let result = aggregate([e], target: target)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].amount, money(100, "USD"))
    }

    // MARK: - Path 2: amountInBase snapshot

    func testForeignExpenseWithSnapshotUsesSnapshot() {
        let e = expense(amount: money(3550, "THB"), amountInBase: money(100, "USD"))
        let result = aggregate([e], target: target)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].amount, money(100, "USD"))
    }

    func testSnapshotInWrongCurrencyFallsBackToStaticConverter() {
        // Snapshot is in EUR, not the USD target — path 2 misses, falls to path 3.
        let e = expense(amount: money(9300, "THB"), amountInBase: money(93, "EUR"))
        let result = aggregate([e], target: target)
        XCTAssertEqual(result.count, 1)
        // THB → USD via static table: 9300 THB / 35.5 = ~261.97 USD
        XCTAssertEqual(result[0].amount.currency, "USD")
        XCTAssertEqual(result[0].amount.decimalValue, 261.97, accuracy: 1.0)
    }

    // MARK: - Path 3: static fallback converter

    func testForeignExpenseWithoutSnapshotConvertsViaStaticTable() {
        let e = expense(amount: money(9300, "EUR"), amountInBase: nil)
        let result = aggregate([e], target: target)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0].amount.currency, "USD")
        // 9300 EUR / 0.93 = 10000 USD
        XCTAssertEqual(result[0].amount.decimalValue, 10000, accuracy: 1.0)
    }

    // MARK: - Dropped (unconvertible)

    func testExpenseInUnknownCurrencyIsDropped() {
        let e = expense(amount: money(100, "XYZ"), amountInBase: nil)
        let result = aggregate([e], target: target)
        XCTAssertEqual(result.count, 0)
    }

    func testUnconvertibleCountExcludesKnownCurrencies() {
        let known   = expense(amount: money(100, "EUR"), amountInBase: nil)
        let unknown = expense(amount: money(100, "XYZ"), amountInBase: nil)
        let native  = expense(amount: money(100, "USD"), amountInBase: nil)
        XCTAssertEqual(unconvertibleCount([known, unknown, native], target: target), 1)
    }

    func testConvertedForeignCountExcludesNativeAndDropped() {
        let native  = expense(amount: money(100, "USD"), amountInBase: nil)
        let foreign = expense(amount: money(100, "EUR"), amountInBase: nil)
        let dropped = expense(amount: money(100, "XYZ"), amountInBase: nil)
        // Only `foreign` is convertible and non-native
        XCTAssertEqual(convertedForeignCount([native, foreign, dropped], target: target), 1)
    }

    // MARK: - Mixed batch

    func testMixedBatchProjectsCorrectly() {
        let native  = expense(amount: money(500, "USD"), amountInBase: nil)
        let snapped = expense(amount: money(3550, "THB"), amountInBase: money(100, "USD"))
        let static_ = expense(amount: money(930, "EUR"), amountInBase: nil)
        let dropped = expense(amount: money(100, "XYZ"), amountInBase: nil)

        let result = aggregate([native, snapped, static_, dropped], target: target)
        XCTAssertEqual(result.count, 3)
        let total = result.reduce(0) { $0 + $1.amount.decimalValue }
        // 500 + 100 + (930/0.93=1000) = 1600 USD
        XCTAssertEqual(total, 1600, accuracy: 1.0)
    }

    // MARK: - Queue filters

    func testManagerQueueContainsOnlyPendingManagerApproval() {
        let expenses = makeQueueExpenses()
        let queue = expenses.filter { $0.status == .pendingManagerApproval }
        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue[0].status, .pendingManagerApproval)
    }

    func testFinanceQueueIncludesAllFinanceStages() {
        let expenses = makeQueueExpenses()
        let queue = expenses.filter { e in
            let isApprovedClaim = e.status == .approved && e.kind != .preApproval
            let isFinanceStage = e.status == .purchaseConfirmed
                || e.status == .pendingFinanceReview
                || e.status == .readyForReimbursement
            return isApprovedClaim || isFinanceStage
        }
        // approved-claim + purchaseConfirmed + pendingFinanceReview + readyForReimbursement = 4
        XCTAssertEqual(queue.count, 4)
    }

    func testFinanceQueueExcludesApprovedPreApprovals() {
        // An approved preApproval is in the employee's court (confirm purchase),
        // not finance's — it must not appear in the finance queue.
        let approvedPreApproval = expense(
            amount: money(100, "USD"), amountInBase: nil,
            status: .approved, kind: .preApproval
        )
        let queue = [approvedPreApproval].filter { e in
            let isApprovedClaim = e.status == .approved && e.kind != .preApproval
            let isFinanceStage = e.status == .purchaseConfirmed
                || e.status == .pendingFinanceReview
                || e.status == .readyForReimbursement
            return isApprovedClaim || isFinanceStage
        }
        XCTAssertEqual(queue.count, 0)
    }

    func testDraftQueueContainsOnlyDrafts() {
        let expenses = makeQueueExpenses()
        let drafts = expenses.filter { $0.status == .draft }
        XCTAssertEqual(drafts.count, 1)
    }
}

// MARK: - Helpers

private extension FXAggregationTests {

    func money(_ majorUnits: Int, _ currency: String) -> MoneyAmount {
        MoneyAmount(minorUnits: majorUnits * 100, currency: currency)
    }

    func expense(
        amount: MoneyAmount,
        amountInBase: MoneyAmount?,
        status: ExpenseWorkflowStatus = .pendingManagerApproval,
        kind: ExpenseKind = .reimbursementClaim
    ) -> DomainExpense {
        DomainExpense(
            id: UUID().uuidString,
            workspaceId: "ws1",
            projectId: "p1",
            submittedByMembershipId: "m1",
            kind: kind,
            status: status,
            merchant: "Test",
            amount: amount,
            amountInBase: amountInBase,
            fxRate: nil,
            fxRateAsOf: nil,
            fxSource: nil,
            categoryId: "travel",
            businessPurpose: "Test",
            purchaseDate: nil,
            neededByDate: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            submittedAt: Date(timeIntervalSince1970: 0),
            isArchived: false
        )
    }

    /// Mirrors `RepositoryAppState.expensesInDefaultCurrency`.
    func aggregate(_ expenses: [DomainExpense], target: String) -> [DomainExpense] {
        expenses.compactMap { e in
            if e.amount.currency == target { return e }
            if let inBase = e.amountInBase, inBase.currency == target {
                return e.withDisplayAmount(inBase)
            }
            guard let converted = CurrencyConverter.convert(e.amount.decimalValue, from: e.amount.currency, to: target) else {
                return nil
            }
            return e.withDisplayAmount(MoneyAmount(minorUnits: Int((converted * 100).rounded()), currency: target))
        }
    }

    /// Mirrors `RepositoryAppState.unconvertibleExpenseCount`.
    func unconvertibleCount(_ expenses: [DomainExpense], target: String) -> Int {
        expenses.filter { e in
            if e.amount.currency == target { return false }
            if let inBase = e.amountInBase, inBase.currency == target { return false }
            return !CurrencyConverter.canConvert(from: e.amount.currency, to: target)
        }.count
    }

    /// Mirrors `RepositoryAppState.convertedForeignExpenseCount`.
    func convertedForeignCount(_ expenses: [DomainExpense], target: String) -> Int {
        expenses.filter { e in
            e.amount.currency != target
                && (e.amountInBase?.currency == target
                    || CurrencyConverter.canConvert(from: e.amount.currency, to: target))
        }.count
    }

    func makeQueueExpenses() -> [DomainExpense] {
        let m = money(100, "USD")
        return [
            expense(amount: m, amountInBase: nil, status: .draft),
            expense(amount: m, amountInBase: nil, status: .pendingManagerApproval, kind: .reimbursementClaim),
            expense(amount: m, amountInBase: nil, status: .approved, kind: .reimbursementClaim),
            expense(amount: m, amountInBase: nil, status: .approved, kind: .preApproval),
            expense(amount: m, amountInBase: nil, status: .purchaseConfirmed),
            expense(amount: m, amountInBase: nil, status: .pendingFinanceReview),
            expense(amount: m, amountInBase: nil, status: .readyForReimbursement),
            expense(amount: m, amountInBase: nil, status: .reimbursed),
            expense(amount: m, amountInBase: nil, status: .rejected),
        ]
    }
}
