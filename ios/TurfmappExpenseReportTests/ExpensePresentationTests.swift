import XCTest
@testable import TurfmappExpenseReport

/// Tests for `DomainExpense` presentation helpers: category label formatting,
/// category icon mapping, project name lookup, and invite email validation.
final class ExpensePresentationTests: XCTestCase {

    // MARK: - categoryLabel

    func testCategoryLabelCapitalizesSimpleId() {
        XCTAssertEqual(expense(categoryId: "meals").categoryLabel, "Meals")
        XCTAssertEqual(expense(categoryId: "travel").categoryLabel, "Travel")
        XCTAssertEqual(expense(categoryId: "software").categoryLabel, "Software")
        XCTAssertEqual(expense(categoryId: "office").categoryLabel, "Office")
        XCTAssertEqual(expense(categoryId: "other").categoryLabel, "Other")
    }

    func testCategoryLabelCapitalizesEachWordForUnderscoreIds() {
        XCTAssertEqual(expense(categoryId: "team_lunch").categoryLabel, "Team Lunch")
        XCTAssertEqual(expense(categoryId: "business_travel").categoryLabel, "Business Travel")
    }

    func testCategoryLabelPreservesAlreadyCapitalized() {
        XCTAssertEqual(expense(categoryId: "Meals").categoryLabel, "Meals")
    }

    // MARK: - icon

    func testKnownCategoryIdsMapToExpectedEmoji() {
        XCTAssertEqual(expense(categoryId: "meals").icon, "🍱")
        XCTAssertEqual(expense(categoryId: "travel").icon, "✈️")
        XCTAssertEqual(expense(categoryId: "software").icon, "💻")
        XCTAssertEqual(expense(categoryId: "office").icon, "🏢")
    }

    func testUnknownCategoryIdFallsBackToReceiptEmoji() {
        XCTAssertEqual(expense(categoryId: "other").icon, "🧾")
        XCTAssertEqual(expense(categoryId: "custom_category").icon, "🧾")
        XCTAssertEqual(expense(categoryId: "xyz").icon, "🧾")
    }

    // MARK: - projectName(in:)

    func testProjectNameReturnsMatchingProjectByExpenseProjectId() {
        let project = testProject(id: "p1", name: "Product Launch")
        let e = expense(projectId: "p1")
        XCTAssertEqual(e.projectName(in: [project]), "Product Launch")
    }

    func testProjectNameFallsBackWhenNoMatchFound() {
        let project = testProject(id: "p2", name: "Other Project")
        let e = expense(projectId: "p1")
        XCTAssertEqual(e.projectName(in: [project]), "Unknown project")
        XCTAssertEqual(e.projectName(in: []), "Unknown project")
    }

    func testProjectNamePicksFirstMatchingId() {
        let p1 = testProject(id: "p1", name: "First")
        let p2 = testProject(id: "p1", name: "Duplicate")
        let e = expense(projectId: "p1")
        XCTAssertEqual(e.projectName(in: [p1, p2]), "First")
    }

    // MARK: - Invite email validation (mirrors InviteMemberSheet.canSend)

    func testValidEmailsPass() {
        XCTAssertTrue(isValidInviteEmail("sira@turfmapp.com"))
        XCTAssertTrue(isValidInviteEmail("user@example.co.uk"))
        XCTAssertTrue(isValidInviteEmail("a@b.io"))
        XCTAssertTrue(isValidInviteEmail("  sira@turfmapp.com  ")) // leading/trailing whitespace
    }

    func testEmptyStringFails() {
        XCTAssertFalse(isValidInviteEmail(""))
        XCTAssertFalse(isValidInviteEmail("   "))
    }

    func testMissingAtSignFails() {
        XCTAssertFalse(isValidInviteEmail("notanemail"))
        XCTAssertFalse(isValidInviteEmail("nodomain.com"))
    }

    func testAtSignAtStartFails() {
        XCTAssertFalse(isValidInviteEmail("@domain.com"))
    }

    func testAtSignAtEndFails() {
        XCTAssertFalse(isValidInviteEmail("user@"))
    }

    func testNoDotInDomainFails() {
        XCTAssertFalse(isValidInviteEmail("user@localhost"))
    }

    func testMultipleAtSignsPassWhenDomainHasDot() {
        // Technically unusual but the rule only checks for "@" presence and "." after it
        XCTAssertTrue(isValidInviteEmail("a@b@c.com"))
    }
}

// MARK: - Helpers

private extension ExpensePresentationTests {
    func expense(categoryId: String = "other", projectId: String = "p1") -> DomainExpense {
        DomainExpense(
            id: "e1",
            workspaceId: "ws1",
            projectId: projectId,
            submittedByMembershipId: "m1",
            kind: .reimbursementClaim,
            status: .pendingManagerApproval,
            merchant: "Test",
            amount: MoneyAmount(minorUnits: 1000, currency: "USD"),
            categoryId: categoryId,
            businessPurpose: "Test",
            purchaseDate: nil,
            neededByDate: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            submittedAt: nil,
            isArchived: false
        )
    }

    func testProject(id: String, name: String) -> DomainProject {
        DomainProject(
            id: id,
            workspaceId: "ws1",
            name: name,
            budget: MoneyAmount(minorUnits: 1_000_000, currency: "USD"),
            budgetPeriod: "monthly",
            ownerMembershipId: "m1",
            visibility: "workspace",
            routingMode: .managerOnly,
            overBudgetBehavior: .warn,
            allowedCategoryIds: [],
            approvalThreshold: MoneyAmount(minorUnits: 10_000, currency: "USD"),
            receiptRequiredThreshold: MoneyAmount(minorUnits: 7500, currency: "USD"),
            currentUserProjectRole: .submitter,
            isArchived: false
        )
    }

    /// Mirrors `InviteMemberSheet.canSend`.
    func isValidInviteEmail(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"),
              at != trimmed.startIndex,
              at != trimmed.index(before: trimmed.endIndex) else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".")
    }
}
