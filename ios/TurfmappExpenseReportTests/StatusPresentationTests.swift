import XCTest
@testable import TurfmappExpenseReport

/// Tests for `ExpenseWorkflowStatus` display properties: icon cluster groupings,
/// nextOwnerLabel routing, and legacyStatus mapping.
/// Note: tint (Color) is excluded — SwiftUI Color equality is presentation-only.
final class StatusPresentationTests: XCTestCase {

    // MARK: - icon

    func testDraftHasDocIcon() {
        XCTAssertEqual(ExpenseWorkflowStatus.draft.icon, "doc")
    }

    func testInFlightStatusesShareClockIcon() {
        XCTAssertEqual(ExpenseWorkflowStatus.submitted.icon, "clock")
        XCTAssertEqual(ExpenseWorkflowStatus.scanProcessing.icon, "clock")
        XCTAssertEqual(ExpenseWorkflowStatus.pendingManagerApproval.icon, "clock")
    }

    func testApprovedHasCheckmarkIcon() {
        XCTAssertEqual(ExpenseWorkflowStatus.approved.icon, "checkmark")
    }

    func testFinanceStageStatusesShareCreditCardIcon() {
        XCTAssertEqual(ExpenseWorkflowStatus.pendingFinanceReview.icon, "creditcard")
        XCTAssertEqual(ExpenseWorkflowStatus.purchaseConfirmed.icon, "creditcard")
        XCTAssertEqual(ExpenseWorkflowStatus.readyForReimbursement.icon, "creditcard")
    }

    func testReimbursedHasCheckCircleIcon() {
        XCTAssertEqual(ExpenseWorkflowStatus.reimbursed.icon, "checkmark.circle")
    }

    func testTerminalNegativeStatusesShareXmarkIcon() {
        XCTAssertEqual(ExpenseWorkflowStatus.rejected.icon, "xmark")
        XCTAssertEqual(ExpenseWorkflowStatus.cancelled.icon, "xmark")
        XCTAssertEqual(ExpenseWorkflowStatus.scanFailed.icon, "xmark")
    }

    func testArchivedHasArchiveboxIcon() {
        XCTAssertEqual(ExpenseWorkflowStatus.archived.icon, "archivebox")
    }

    // MARK: - nextOwnerLabel

    func testSystemIsNextOwnerDuringScanning() {
        XCTAssertEqual(ExpenseWorkflowStatus.submitted.nextOwnerLabel, "System")
        XCTAssertEqual(ExpenseWorkflowStatus.scanProcessing.nextOwnerLabel, "System")
    }

    func testManagerIsNextOwnerWhenPendingApproval() {
        XCTAssertEqual(ExpenseWorkflowStatus.pendingManagerApproval.nextOwnerLabel, "Manager")
    }

    func testEmployeeIsNextOwnerAfterApproval() {
        // The employee must confirm the purchase on an approved pre-approval.
        XCTAssertEqual(ExpenseWorkflowStatus.approved.nextOwnerLabel, "Employee")
    }

    func testFinanceIsNextOwnerDuringFinanceStages() {
        XCTAssertEqual(ExpenseWorkflowStatus.pendingFinanceReview.nextOwnerLabel, "Finance")
        XCTAssertEqual(ExpenseWorkflowStatus.purchaseConfirmed.nextOwnerLabel, "Finance")
        XCTAssertEqual(ExpenseWorkflowStatus.readyForReimbursement.nextOwnerLabel, "Finance")
    }

    func testTerminalStatusesHaveNoNextOwner() {
        let terminals: [ExpenseWorkflowStatus] = [
            .draft, .rejected, .cancelled, .reimbursed, .scanFailed, .archived
        ]
        for status in terminals {
            XCTAssertNil(status.nextOwnerLabel, "\(status) should have no next owner")
        }
    }

    // MARK: - legacyStatus

    func testPreSubmitAndPendingMapToLegacyPending() {
        let pending: [ExpenseWorkflowStatus] = [
            .draft, .submitted, .scanProcessing, .scanFailed, .pendingManagerApproval
        ]
        for status in pending {
            XCTAssertEqual(status.legacyStatus, .pending, "\(status) should map to legacy pending")
        }
    }

    func testApprovedMapsToLegacyApproved() {
        XCTAssertEqual(ExpenseWorkflowStatus.approved.legacyStatus, .approved)
    }

    func testRejectedAndCancelledMapToLegacyRejected() {
        XCTAssertEqual(ExpenseWorkflowStatus.rejected.legacyStatus, .rejected)
        XCTAssertEqual(ExpenseWorkflowStatus.cancelled.legacyStatus, .rejected)
    }

    func testFinanceStagesMapsToLegacyPurchased() {
        let purchased: [ExpenseWorkflowStatus] = [
            .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement
        ]
        for status in purchased {
            XCTAssertEqual(status.legacyStatus, .purchased, "\(status) should map to legacy purchased")
        }
    }

    func testReimbursedAndArchivedMapToLegacyReimbursed() {
        XCTAssertEqual(ExpenseWorkflowStatus.reimbursed.legacyStatus, .reimbursed)
        XCTAssertEqual(ExpenseWorkflowStatus.archived.legacyStatus, .reimbursed)
    }
}
