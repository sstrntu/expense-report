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
}
