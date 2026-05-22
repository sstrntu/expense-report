import XCTest
@testable import TurfmappExpenseReport

final class MoneyAmountTests: XCTestCase {

    // MARK: - decimalValue

    func testDecimalValueDividesMinorUnitsByHundred() {
        XCTAssertEqual(MoneyAmount(minorUnits: 1000, currency: "USD").decimalValue, 10.00)
        XCTAssertEqual(MoneyAmount(minorUnits: 999,  currency: "USD").decimalValue, 9.99)
        XCTAssertEqual(MoneyAmount(minorUnits: 1,    currency: "USD").decimalValue, 0.01)
        XCTAssertEqual(MoneyAmount(minorUnits: 0,    currency: "USD").decimalValue, 0.00)
    }

    func testDecimalValuePreservesLargeAmounts() {
        XCTAssertEqual(MoneyAmount(minorUnits: 1_000_000_00, currency: "USD").decimalValue, 1_000_000.00)
    }

    // MARK: - DomainExpense.isConverted

    func testIsConvertedFalseWhenNoSnapshot() {
        let e = expense(amount: money(100, "USD"), amountInBase: nil)
        XCTAssertFalse(e.isConverted)
    }

    func testIsConvertedFalseWhenSnapshotMatchesNativeCurrency() {
        let e = expense(amount: money(100, "USD"), amountInBase: money(100, "USD"))
        XCTAssertFalse(e.isConverted)
    }

    func testIsConvertedTrueWhenSnapshotDiffersFromNative() {
        let e = expense(amount: money(3550, "THB"), amountInBase: money(100, "USD"))
        XCTAssertTrue(e.isConverted)
    }

    // MARK: - withDisplayAmount

    func testWithDisplayAmountReplacesAmountOnly() {
        let original = expense(amount: money(3550, "THB"), amountInBase: money(100, "USD"))
        let projected = original.withDisplayAmount(money(100, "USD"))
        XCTAssertEqual(projected.amount, money(100, "USD"))
        // Original snapshot is preserved
        XCTAssertEqual(projected.amountInBase, money(100, "USD"))
        // Identity fields unchanged
        XCTAssertEqual(projected.id, original.id)
        XCTAssertEqual(projected.merchant, original.merchant)
        XCTAssertEqual(projected.status, original.status)
    }
}

// MARK: - Helpers

private func money(_ majorUnits: Int, _ currency: String) -> MoneyAmount {
    MoneyAmount(minorUnits: majorUnits * 100, currency: currency)
}

private func expense(amount: MoneyAmount, amountInBase: MoneyAmount?) -> DomainExpense {
    DomainExpense(
        id: "e1",
        workspaceId: "ws1",
        projectId: "p1",
        submittedByMembershipId: "m1",
        kind: .reimbursementClaim,
        status: .pendingManagerApproval,
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
