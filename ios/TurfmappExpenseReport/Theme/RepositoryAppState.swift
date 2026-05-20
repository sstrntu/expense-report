import Foundation

@MainActor
final class RepositoryAppState: ObservableObject {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var loadState: LoadState = .idle
    @Published private(set) var workspaces: [DomainWorkspace] = []
    @Published private(set) var selectedWorkspace: DomainWorkspace?
    @Published private(set) var projects: [DomainProject] = []
    @Published private(set) var expenses: [DomainExpense] = []
    @Published private(set) var eventsByExpenseId: [String: [ExpenseWorkflowEvent]] = [:]
    @Published private(set) var members: [DomainWorkspaceMember] = []
    @Published private(set) var invites: [WorkspaceInvite] = []
    @Published private(set) var categories: [DomainCategory] = []
    @Published private(set) var notifications: [DomainNotification] = []
    @Published private(set) var currentUserProfile: DomainUserProfile?
    @Published private(set) var lastError: String?
    @Published private(set) var isOfflineMode = false
    @Published private(set) var pendingOfflineDraftCount = 0

    private let authRepository: any AuthRepository
    private let workspaceRepository: any WorkspaceRepository
    private let projectRepository: any ProjectRepository
    private let expenseRepository: any ExpenseRepository
    private let attachmentRepository: any AttachmentRepository
    private let receiptScanRepository: any ReceiptScanRepository
    private let selectedWorkspaceDefaultsKey = "selectedWorkspaceId"

    init(container: RepositoryContainer = .configured()) {
        authRepository = container.auth
        workspaceRepository = container.workspaces
        projectRepository = container.projects
        expenseRepository = container.expenses
        attachmentRepository = container.attachments
        receiptScanRepository = container.receiptScans
    }

    var managerQueue: [DomainExpense] {
        expenses.filter { $0.status == .pendingManagerApproval }
    }

    var financeQueue: [DomainExpense] {
        expenses.filter { $0.status == .pendingFinanceReview || $0.status == .readyForReimbursement }
    }

    var draftExpenses: [DomainExpense] {
        expenses.filter { $0.status == .draft }
    }

    /// ISO code the dashboards aggregate in (the workspace default).
    var aggregationCurrency: String {
        selectedWorkspace?.defaultCurrency ?? "USD"
    }

    /// Expenses matching the workspace's default currency (the only ones we
    /// add together). No exchange-rate conversion happens.
    var expensesInDefaultCurrency: [DomainExpense] {
        expenses.filter { $0.amount.currency == aggregationCurrency }
    }

    /// Count of expenses in a non-default currency — used to surface a
    /// "+N excluded" footnote on dashboards.
    var foreignCurrencyExpenseCount: Int {
        expenses.filter { $0.amount.currency != aggregationCurrency }.count
    }

    func categoryName(forId id: String) -> String {
        categories.first { $0.id == id }?.name ?? id.capitalized
    }

    func bootstrap() async {
        await loadCurrentUserProfile()
        await loadWorkspaces(selecting: selectedWorkspace?.id ?? UserDefaults.standard.string(forKey: selectedWorkspaceDefaultsKey))
    }

    private func loadCurrentUserProfile() async {
        currentUserProfile = (try? await authRepository.currentUserProfile()) ?? nil
    }

    @discardableResult
    func setUserAvatar(data: Data, contentType: String, fileExtension: String) async -> Bool {
        do {
            lastError = nil
            guard let uid = try await authRepository.currentUserId() else {
                throw SupabaseRepositoryError.missingSession
            }
            let path = "users/\(uid)/\(UUID().uuidString).\(fileExtension)"
            let url = try await authRepository.uploadBrandingImage(path: path, contentType: contentType, data: data)
            try await authRepository.updateAvatarUrl(url)
            if let p = currentUserProfile {
                currentUserProfile = DomainUserProfile(id: p.id, email: p.email, displayName: p.displayName, avatarUrl: url)
            } else {
                await loadCurrentUserProfile()
            }
            return true
        } catch {
            setError(error)
            return false
        }
    }

    @discardableResult
    func updateWorkspace(name: String, defaultCurrency: String) async -> Bool {
        guard let wsid = selectedWorkspace?.id else { return false }
        do {
            lastError = nil
            _ = try await workspaceRepository.updateWorkspace(workspaceId: wsid, name: name, defaultCurrency: defaultCurrency)
            await loadWorkspaces(selecting: wsid)
            return true
        } catch {
            setError(error)
            return false
        }
    }

    @discardableResult
    func setWorkspaceLogo(data: Data, contentType: String, fileExtension: String) async -> Bool {
        guard let wsid = selectedWorkspace?.id else { return false }
        do {
            lastError = nil
            let path = "workspaces/\(wsid)/\(UUID().uuidString).\(fileExtension)"
            let url = try await authRepository.uploadBrandingImage(path: path, contentType: contentType, data: data)
            _ = try await workspaceRepository.updateWorkspaceLogo(workspaceId: wsid, logoUrl: url)
            await loadWorkspaces(selecting: wsid)
            return true
        } catch {
            setError(error)
            return false
        }
    }

    func markNotificationRead(id: String) async {
        do {
            try await workspaceRepository.markNotificationRead(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func updateDisplayName(_ name: String) async -> Bool {
        do {
            lastError = nil
            try await authRepository.updateDisplayName(name)
            // Refresh the cached profile so the UI re-renders with the new
            // displayName / initials immediately, without a full bootstrap.
            if let p = currentUserProfile {
                currentUserProfile = DomainUserProfile(
                    id: p.id,
                    email: p.email,
                    displayName: name,
                    avatarUrl: p.avatarUrl
                )
            } else {
                await loadCurrentUserProfile()
            }
            return true
        } catch {
            setError(error)
            return false
        }
    }

    @discardableResult
    func updatePassword(_ newPassword: String) async -> Bool {
        do {
            lastError = nil
            try await authRepository.updatePassword(newPassword)
            return true
        } catch {
            setError(error)
            return false
        }
    }

    @discardableResult
    func signOutAllSessions() async -> Bool {
        do {
            lastError = nil
            try await authRepository.signOutAllSessions()
            return true
        } catch {
            setError(error)
            return false
        }
    }

    @discardableResult
    func requestPasswordReset(email: String) async -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastError = "Enter your email first."
            return false
        }
        do {
            lastError = nil
            try await authRepository.sendPasswordResetEmail(trimmed)
            return true
        } catch {
            setError(error)
            return false
        }
    }

    func signIn(email: String, password: String) async {
        do {
            lastError = nil
            try await authRepository.signIn(email: email, password: password)
            await loadCurrentUserProfile()
            await loadWorkspaces(selecting: selectedWorkspace?.id)
        } catch {
            setError(error)
        }
    }

    func signUp(email: String, password: String) async {
        do {
            lastError = nil
            try await authRepository.signUp(email: email, password: password)
            if try await authRepository.currentUserId() != nil {
                await loadCurrentUserProfile()
                await loadWorkspaces(selecting: selectedWorkspace?.id)
            }
        } catch {
            setError(error)
        }
    }

    func selectWorkspace(id: String) async {
        lastError = nil
        UserDefaults.standard.set(id, forKey: selectedWorkspaceDefaultsKey)
        await loadWorkspaces(selecting: id)
    }

    func createWorkspace(name: String, defaultCurrency: String = "USD") async {
        do {
            lastError = nil
            let workspace = try await workspaceRepository.createWorkspace(name: name, defaultCurrency: defaultCurrency)
            UserDefaults.standard.set(workspace.id, forKey: selectedWorkspaceDefaultsKey)
            await loadWorkspaces(selecting: workspace.id)
        } catch {
            setError(error)
        }
    }

    func acceptInvite(id: String) async {
        do {
            lastError = nil
            let workspace = try await workspaceRepository.acceptInvite(id: id)
            UserDefaults.standard.set(workspace.id, forKey: selectedWorkspaceDefaultsKey)
            await loadWorkspaces(selecting: workspace.id)
        } catch {
            setError(error)
        }
    }

    @discardableResult
    func createAndSubmitExpense(_ input: ExpenseDraftInput, receipt: PendingReceiptUpload? = nil) async -> Bool {
        do {
            lastError = nil
            let draft = try await expenseRepository.createDraft(input)
            if let receipt {
                let attachment = try await attachmentRepository.uploadAttachment(
                    expenseId: draft.id,
                    kind: receipt.kind,
                    fileName: receipt.fileName,
                    contentType: receipt.contentType,
                    data: receipt.data
                )
                _ = try await receiptScanRepository.startScan(attachmentId: attachment.id)
            }
            _ = try await expenseRepository.submitExpense(id: draft.id)
            await reloadSelectedWorkspaceData()
            return true
        } catch {
            setError(error)
            return false
        }
    }

    /// Updates an existing draft (e.g. created during a receipt scan) with the
    /// final fields and submits it, instead of creating a duplicate expense.
    @discardableResult
    func updateDraftAndSubmit(id: String, _ input: ExpenseDraftInput) async -> Bool {
        do {
            lastError = nil
            _ = try await expenseRepository.updateDraft(id: id, input)
            _ = try await expenseRepository.submitExpense(id: id)
            await reloadSelectedWorkspaceData()
            return true
        } catch {
            setError(error)
            return false
        }
    }

    @discardableResult
    func updateDraftOnly(id: String, _ input: ExpenseDraftInput) async -> Bool {
        do {
            lastError = nil
            _ = try await expenseRepository.updateDraft(id: id, input)
            await reloadSelectedWorkspaceData()
            return true
        } catch {
            setError(error)
            return false
        }
    }

    struct ReceiptScanOutcome {
        let draftId: String
        let result: ReceiptScanResult
    }

    /// Creates a backing draft, uploads the receipt, and runs the AI scan so
    /// the result can prefill the form before the user submits.
    func scanReceipt(input: ExpenseDraftInput, fileName: String, contentType: String, data: Data) async -> ReceiptScanOutcome? {
        do {
            lastError = nil
            let draft = try await expenseRepository.createDraft(input)
            let attachment = try await attachmentRepository.uploadAttachment(
                expenseId: draft.id,
                kind: .submittedReceipt,
                fileName: fileName,
                contentType: contentType,
                data: data
            )
            let result = try await receiptScanRepository.startScan(attachmentId: attachment.id)
            await reloadSelectedWorkspaceData()
            return ReceiptScanOutcome(draftId: draft.id, result: result)
        } catch {
            setError(error)
            return nil
        }
    }

    func uploadAttachment(expenseId: String, upload: PendingReceiptUpload) async -> ExpenseAttachment? {
        do {
            lastError = nil
            let attachment = try await attachmentRepository.uploadAttachment(
                expenseId: expenseId,
                kind: upload.kind,
                fileName: upload.fileName,
                contentType: upload.contentType,
                data: upload.data
            )
            await reloadSelectedWorkspaceData()
            return attachment
        } catch {
            setError(error)
            return nil
        }
    }

    @discardableResult
    func createDraft(_ input: ExpenseDraftInput) async -> Bool {
        do {
            lastError = nil
            _ = try await expenseRepository.createDraft(input)
            await reloadSelectedWorkspaceData()
            return true
        } catch {
            setError(error)
            return false
        }
    }

    func createProject(_ project: DomainProject) async {
        do {
            _ = try await projectRepository.createProject(project)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func updateProject(_ project: DomainProject) async {
        do {
            lastError = nil
            _ = try await projectRepository.updateProject(project)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func archiveProject(id: String) async {
        do {
            lastError = nil
            try await projectRepository.archiveProject(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func inviteMember(email: String, role: WorkspaceRole) async {
        guard let workspace = selectedWorkspace else { return }
        do {
            lastError = nil
            _ = try await workspaceRepository.inviteMember(workspaceId: workspace.id, email: email, role: role)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func cancelInvite(id: String) async {
        do {
            lastError = nil
            try await workspaceRepository.cancelInvite(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func updateMemberRole(id: String, role: WorkspaceRole) async {
        do {
            lastError = nil
            _ = try await workspaceRepository.updateMemberRole(id: id, role: role)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func removeMember(id: String) async {
        do {
            lastError = nil
            try await workspaceRepository.removeMember(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func updateProjectThreshold(id: String, threshold: MoneyAmount) async {
        do {
            guard let project = projects.first(where: { $0.id == id }) else { return }
            let updated = DomainProject(
                id: project.id,
                workspaceId: project.workspaceId,
                name: project.name,
                budget: project.budget,
                budgetPeriod: project.budgetPeriod,
                ownerMembershipId: project.ownerMembershipId,
                visibility: project.visibility,
                routingMode: project.routingMode,
                overBudgetBehavior: project.overBudgetBehavior,
                allowedCategoryIds: project.allowedCategoryIds,
                approvalThreshold: threshold,
                receiptRequiredThreshold: project.receiptRequiredThreshold,
                currentUserProjectRole: project.currentUserProjectRole,
                isArchived: project.isArchived
            )
            _ = try await projectRepository.updateProject(updated)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func approveExpense(id: String, note: String? = nil) async {
        do {
            _ = try await expenseRepository.approveExpense(id: id, note: note)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func rejectExpense(id: String, reason: String) async {
        do {
            _ = try await expenseRepository.rejectExpense(id: id, reason: reason)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func resubmitExpense(id: String) async {
        do {
            _ = try await expenseRepository.resubmitExpense(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func cancelExpense(id: String, reason: String? = nil) async {
        do {
            _ = try await expenseRepository.cancelExpense(id: id, reason: reason)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func confirmPurchase(id: String, input: PurchaseConfirmationInput) async {
        do {
            _ = try await expenseRepository.confirmPurchase(id: id, input: input)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func markReimbursed(id: String, input: ReimbursementInput) async {
        do {
            _ = try await expenseRepository.markReimbursed(id: id, input: input)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func archiveExpense(id: String) async {
        do {
            _ = try await expenseRepository.archiveExpense(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func unarchiveExpense(id: String) async {
        do {
            _ = try await expenseRepository.unarchiveExpense(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func deleteExpense(id: String) async {
        do {
            try await expenseRepository.deleteExpense(id: id)
            await reloadSelectedWorkspaceData()
        } catch {
            setError(error)
        }
    }

    func uploadReceiptAndStartScan(expenseId: String, fileName: String, data: Data) async -> ReceiptScanResult? {
        do {
            let attachment = try await attachmentRepository.uploadAttachment(
                expenseId: expenseId,
                kind: .submittedReceipt,
                fileName: fileName,
                contentType: "image/jpeg",
                data: data
            )
            return try await receiptScanRepository.startScan(attachmentId: attachment.id)
        } catch {
            setError(error)
            return nil
        }
    }

    func queueOfflineDraft() {
        isOfflineMode = true
        pendingOfflineDraftCount += 1
    }

    func clearOfflineQueue() {
        isOfflineMode = false
        pendingOfflineDraftCount = 0
    }

    private func loadWorkspaces(selecting workspaceId: String?) async {
        loadState = .loading
        do {
            let loadedWorkspaces = try await workspaceRepository.listWorkspacesForCurrentUser()
            workspaces = loadedWorkspaces
            selectedWorkspace = loadedWorkspaces.first { $0.id == workspaceId } ?? loadedWorkspaces.first
            if let selectedWorkspace {
                UserDefaults.standard.set(selectedWorkspace.id, forKey: selectedWorkspaceDefaultsKey)
            }
            await reloadSelectedWorkspaceData()
            loadState = .loaded
        } catch {
            setError(error)
        }
    }

    private func reloadSelectedWorkspaceData() async {
        guard let workspace = selectedWorkspace else {
            projects = []
            expenses = []
            eventsByExpenseId = [:]
            members = []
            invites = []
            categories = []
            notifications = []
            return
        }

        do {
            projects = try await projectRepository.listProjects(workspaceId: workspace.id)
            members = try await workspaceRepository.listMembers(workspaceId: workspace.id)
            invites = try await workspaceRepository.listInvites(workspaceId: workspace.id)
            categories = try await workspaceRepository.listCategories(workspaceId: workspace.id)
            notifications = try await workspaceRepository.listNotifications(workspaceId: workspace.id)
            expenses = try await expenseRepository.listExpenses(
                filters: ExpenseFilters(
                    workspaceId: workspace.id,
                    projectId: nil,
                    status: nil,
                    kind: nil,
                    searchText: nil,
                    dateRange: nil
                )
            )
            var loadedEvents: [String: [ExpenseWorkflowEvent]] = [:]
            for expense in expenses {
                loadedEvents[expense.id] = try await expenseRepository.listEvents(expenseId: expense.id)
            }
            eventsByExpenseId = loadedEvents
        } catch {
            setError(error)
        }
    }

    private func setError(_ error: Error) {
        let message = error.localizedDescription
        lastError = message
        loadState = .failed(message)
    }
}
