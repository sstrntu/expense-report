import SwiftUI
import PhotosUI

struct SubmitView: View {
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onClose: () -> Void
    var onSubmit: () -> Void

    @State private var vendor: String     = ""
    @State private var amountText: String = ""
    @State private var purpose: String    = ""
    @State private var selectedCategoryId: String?
    @State private var selectedProjectId: String?
    @State private var expenseKind: ExpenseKind = .preApproval
    @State private var purchaseDate = Date()
    @State private var neededByDate = Date()

    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var scanStatus: ReceiptScanStatus = .notStarted
    @State private var receiptFileName: String? = nil
    @State private var scannedDraftId: String? = nil
    @State private var showReceiptOptions = false
    @State private var showDiscardConfirm = false
    @State private var isSubmitting = false
    @State private var isSavingDraft = false
    @State private var aiFields: Set<String> = []
    @State private var scanFields: [LocalScanField] = []
    @State private var saveDraftError: String?
    @State private var currency: String?

    /// Available ISO currency codes shown in the picker.
    private static let currencyOptions = ["USD", "EUR", "GBP", "THB", "JPY", "SGD", "AUD", "CAD"]

    private var effectiveCurrency: String {
        currency ?? selectedProject?.budget.currency ?? repositoryApp.selectedWorkspace?.defaultCurrency ?? "USD"
    }

    private var activeProjects: [DomainProject] {
        repositoryApp.projects.filter { !$0.isArchived }
    }
    private var workspaceCategories: [DomainCategory] {
        repositoryApp.categories
    }
    private var category: String {
        guard let id = selectedCategoryId else { return workspaceCategories.first?.name ?? "" }
        return repositoryApp.categoryName(forId: id)
    }
    private var trimmedVendor: String { vendor.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPurpose: String { purpose.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
    private var selectedProject: DomainProject? {
        if let id = selectedProjectId { return activeProjects.first { $0.id == id } }
        return activeProjects.first
    }
    private var willAutoApprove: Bool {
        guard let p = selectedProject else { return false }
        return amount > 0 && amount <= p.approvalThreshold.decimalValue
    }
    private var canSubmit: Bool {
        validationMessages.isEmpty
    }
    private var hasAnyInput: Bool {
        !trimmedVendor.isEmpty || !amountText.isEmpty || !trimmedPurpose.isEmpty
    }
    private var validationMessages: [String] {
        var messages: [String] = []
        if trimmedVendor.isEmpty { messages.append("Vendor is required.") }
        if amount <= 0 { messages.append("Amount must be greater than $0.") }
        if selectedProject == nil { messages.append("Project is required.") }
        if trimmedPurpose.isEmpty { messages.append("Business purpose is required.") }
        if expenseKind == .reimbursementClaim, purchaseDate > Date() {
            messages.append("Purchase date cannot be in the future.")
        }
        return messages
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(expenseKind == .preApproval ? tr("submit.title.pre_approval") : tr("submit.title.reimbursement"))
                        .font(.system(size: 26, weight: .bold))
                    Text(expenseKind == .preApproval ? tr("submit.subtitle.pre_approval") : tr("submit.subtitle.reimbursement"))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    if vendor.isEmpty && amountText.isEmpty && purpose.isEmpty {
                        onClose()
                    } else {
                        showDiscardConfirm = true
                    }
                } label: {
                    Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .glassSurface(corner: 999)
            }
            .padding(.horizontal, 4).padding(.top, 4)

            draftsCard

            expenseTypePicker

            scanCard

            if !scanFields.isEmpty {
                scanReviewCard
            }

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    editableRow(label: tr("submit.field.vendor"),  placeholder: tr("submit.field.vendor.placeholder"), text: $vendor)
                    Divider().opacity(0.4)
                    amountRow
                    Divider().opacity(0.4)
                    workflowDateRow
                    Divider().opacity(0.4)
                    pickerRow(label: tr("submit.field.category"), value: category, options: workspaceCategories.map(\.name)) { picked in
                        selectedCategoryId = workspaceCategories.first { $0.name == picked }?.id
                        aiFields.remove("Category")
                    }
                    Divider().opacity(0.4)
                    projectRow
                    Divider().opacity(0.4)
                    editableRow(label: tr("submit.field.purpose"), placeholder: tr("submit.field.purpose.placeholder"), text: $purpose)
                }
            }

            if hasAnyInput && !validationMessages.isEmpty {
                validationCard
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(
                    icon: "exclamationmark.shield.fill",
                    tint: Tokens.rejected,
                    title: tr("submit.action.cannot_submit"),
                    message: lastError
                )
            }

            if amount > 0, let p = selectedProject {
                routingBanner(project: p)
            }

            Button {
                submitExpense()
            } label: {
                Text(isSubmitting ? tr("submit.action.save_draft.saving") : submitLabel).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity(canSubmit && !isSubmitting ? 1 : 0.5)
            .disabled(!canSubmit || isSubmitting)

            if let saveDraftError {
                infoBanner(
                    icon: "exclamationmark.triangle.fill",
                    tint: Tokens.rejected,
                    title: tr("account.save_failed"),
                    message: saveDraftError
                )
            }

            Button {
                saveDraft()
            } label: {
                Text(isSavingDraft ? tr("submit.action.save_draft.saving") : tr("submit.action.save_draft")).secondaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity((vendor.isEmpty && amountText.isEmpty && purpose.isEmpty) || isSavingDraft ? 0.5 : 1)
            .disabled((vendor.isEmpty && amountText.isEmpty && purpose.isEmpty) || isSavingDraft)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(isPresented: $isScanning) {
            ScanningSheet()
                .presentationDetents([.height(280)])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showReceiptOptions) {
            ReceiptSourceSheet { data, fileName, contentType in
                showReceiptOptions = false
                startScan(data: data, fileName: fileName, contentType: contentType)
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Discard this expense?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button(tr("submit.discard.action"), role: .destructive) { onClose() }
            Button(tr("submit.discard.keep"), role: .cancel) {}
        } message: {
            Text(tr("submit.discard.message"))
        }
    }

    // MARK: – AI scan card

    private var expenseTypePicker: some View {
        GlassCard(padding: 12) {
            Picker(tr("detail.field.type"), selection: $expenseKind) {
                Text(tr("submit.kind.pre_approval")).tag(ExpenseKind.preApproval)
                Text(tr("submit.kind.reimbursement")).tag(ExpenseKind.reimbursementClaim)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var draftsCard: some View {
        let drafts = repositoryApp.draftExpenses
        if !drafts.isEmpty {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    Text(tr("submit.drafts.title"))
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                    ForEach(Array(drafts.prefix(3).enumerated()), id: \.element.id) { idx, draft in
                        if idx > 0 { Divider().opacity(0.4) }
                        Button {
                            vendor = draft.merchant
                            amountText = draft.amount.minorUnits == 0 ? "" : String(format: "%.2f", draft.amount.decimalValue)
                            currency = draft.amount.currency
                            selectedCategoryId = draft.categoryId
                            selectedProjectId = draft.projectId
                            expenseKind = draft.kind
                            purpose = draft.businessPurpose
                            scannedDraftId = draft.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.clock")
                                    .foregroundStyle(Tokens.pending)
                                    .frame(width: 32, height: 32)
                                    .background(Tokens.pending.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(draft.merchant.isEmpty ? "Untitled expense" : draft.merchant)
                                        .font(.system(size: 13.5, weight: .semibold))
                                    Text(draft.projectName(in: repositoryApp.projects))
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(draft.amount.minorUnits == 0 ? "--" : draft.amount.formatted)
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scanCard: some View {
        if scanStatus == .uploading || scanStatus == .processing {
            HStack(spacing: 10) {
                ProgressView().tint(Tokens.aiPurple)
                VStack(alignment: .leading, spacing: 1) {
                    Text(scanStatus == .uploading ? tr("submit.scan.uploading_label") : tr("submit.scan.scanning_label"))
                        .font(.system(size: 13, weight: .semibold))
                    Text(receiptFileName ?? "receipt.jpg")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(12)
            .background(Tokens.aiPurple.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Tokens.aiPurple.opacity(0.25), lineWidth: 0.5))
        } else if scanStatus == .failed {
            VStack(spacing: 10) {
                infoBanner(
                    icon: "exclamationmark.triangle.fill",
                    tint: Tokens.rejected,
                    title: tr("submit.scan.failed"),
                    message: tr("status.scan_failed")
                )
                Button { showReceiptOptions = true } label: {
                    Label(tr("submit.scan.retry"), systemImage: "camera.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.aiPurple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Tokens.aiPurple.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
        } else if hasScanned {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.aiPurple)
                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("submit.scan.needs_review"))
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(tr("submit.scan.subtitle.reimbursement"))
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(tr("submit.scan.retry")) { showReceiptOptions = true }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.aiPurple)
            }
            .padding(12)
            .background(Tokens.aiPurple.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Tokens.aiPurple.opacity(0.25), lineWidth: 0.5))
        } else {
            Button { showReceiptOptions = true } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(colors: [Tokens.aiPurple, Tokens.slate500],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                        Image(systemName: "sparkles").foregroundStyle(.white)
                    }.frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(tr("submit.scan.title.pre_approval")).font(.system(size: 14, weight: .semibold))
                        Text(expenseKind == .preApproval ? tr("submit.scan.subtitle.pre_approval") : tr("submit.scan.subtitle.reimbursement"))
                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "camera.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 18)
        }
    }

    private var scanReviewCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                Text(tr("submit.scan.ai_review"))
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                ForEach($scanFields) { $field in
                    Divider().opacity(0.4)
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(field.label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            HStack(spacing: 5) {
                                StatusPill(text: field.confidence.rawValue.capitalized, tint: field.confidence.tint, leadingIcon: field.confidence.icon)
                                if field.wasEdited {
                                    StatusPill(text: "Manual", tint: Tokens.pending, leadingIcon: "pencil")
                                }
                            }
                        }
                        Spacer()
                        TextField(field.label, text: $field.value)
                            .font(.system(size: 13.5, weight: .medium))
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 170)
                            .onChange(of: field.value) { _, newValue in
                                applyScanField(field.id, value: newValue)
                                field.wasEdited = true
                            }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 11)
                }
            }
        }
    }

    private func startScan(data: Data, fileName: String, contentType: String) {
        guard let project = selectedProject else {
            scanStatus = .failed
            return
        }
        receiptFileName = fileName
        scanStatus = .uploading
        isScanning = true

        Task {
            let input = repositoryInput(project: project)
            let outcome = await repositoryApp.scanReceipt(
                input: input,
                fileName: fileName,
                contentType: contentType,
                data: data
            )
            await MainActor.run {
                isScanning = false
                guard let outcome else {
                    scanStatus = .failed
                    hasScanned = false
                    scanFields = []
                    return
                }
                scannedDraftId = outcome.draftId
                let result = outcome.result
                if result.status == .needsReview || result.status == .confirmed {
                    applyScanResult(result)
                    hasScanned = true
                    scanStatus = .needsReview
                } else {
                    scanStatus = .failed
                    hasScanned = false
                    scanFields = []
                }
            }
        }
    }

    private func applyScanResult(_ result: ReceiptScanResult) {
        func value(_ name: String) -> String? {
            result.fields.first { $0.fieldName == name }
                .map { $0.normalizedValue ?? $0.extractedValue }
                .flatMap { $0.isEmpty ? nil : $0 }
        }
        var fields: [LocalScanField] = []
        if let merchant = value("merchant") {
            vendor = merchant
            aiFields.insert("Vendor")
            fields.append(LocalScanField(id: "merchant", label: tr("submit.field.vendor"), value: merchant, confidence: .high))
        }
        if let amountValue = value("amount") {
            amountText = amountValue
            aiFields.insert("Amount")
            fields.append(LocalScanField(id: "amount", label: tr("submit.field.amount"), value: amountValue, confidence: .high))
        }
        // Currency is now extracted too — apply it so Thai receipts default to THB.
        if let currencyValue = value("currency"),
           !currencyValue.isEmpty {
            currency = currencyValue.uppercased()
        }
        if let categoryName = value("category"),
           let match = workspaceCategories.first(where: { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }) {
            selectedCategoryId = match.id
            aiFields.insert("Category")
            // Show the localized category name so a Thai user sees "อาหาร" not "Meals".
            let displayName = repositoryApp.displayCategoryName(forId: match.id)
            fields.append(LocalScanField(id: "category", label: tr("submit.field.category"), value: displayName, confidence: .medium))
        }
        if let dateValue = value("date") {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd"
            if let parsed = formatter.date(from: dateValue) {
                purchaseDate = parsed
            }
        }
        scanFields = fields
    }

    private func applyScanField(_ id: String, value: String) {
        switch id {
        case "merchant":
            vendor = value
            aiFields.remove("Vendor")
        case "amount":
            amountText = value
            aiFields.remove("Amount")
        case "category":
            selectedCategoryId = workspaceCategories.first { $0.name.caseInsensitiveCompare(value) == .orderedSame }?.id
            aiFields.remove("Category")
        default:
            break
        }
    }

    private var submitLabel: String {
        // We keep a single translated label across kinds — multilingual UX
        // benefits more from consistency than from the four English variants.
        tr("submit.action.submit")
    }

    // MARK: – Form rows

    private var amountRow: some View {
        HStack {
            Text(tr("submit.field.amount")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            if aiFields.contains("Amount") {
                StatusPill(text: "AI", tint: Tokens.aiPurple, leadingIcon: "sparkles")
            }
            Menu {
                ForEach(Self.currencyOptions, id: \.self) { code in
                    Button {
                        currency = code
                    } label: {
                        HStack {
                            Text(code)
                            if effectiveCurrency == code { Image(systemName: "checkmark") }
                        }
                    }
                }
            } label: {
                Text(effectiveCurrency)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.primary.opacity(0.06), in: Capsule())
            }
            TextField("0.00", text: $amountText)
                .font(.system(size: 13.5, weight: .medium))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 100)
                .onChange(of: amountText) { _, _ in aiFields.remove("Amount") }
        }
        .padding(.vertical, 11)
    }

    private var workflowDateRow: some View {
        HStack {
            Text(expenseKind == .preApproval ? tr("submit.field.needed_by") : tr("submit.field.purchase_date"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker(
                expenseKind == .preApproval ? tr("submit.field.needed_by") : tr("submit.field.purchase_date"),
                selection: expenseKind == .preApproval ? $neededByDate : $purchaseDate,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.compact)
        }
        .padding(.vertical, 8)
    }

    private var validationCard: some View {
        infoBanner(
            icon: "exclamationmark.circle.fill",
            tint: Tokens.pending,
            title: tr("common.required"),
            message: validationMessages.joined(separator: " ")
        )
    }

    private var projectRow: some View {
        Menu {
            ForEach(activeProjects) { p in
                Button {
                    selectedProjectId = p.id
                } label: {
                    HStack {
                        Text(p.name)
                        if selectedProjectId == p.id || (selectedProjectId == nil && p.id == activeProjects.first?.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text(tr("submit.field.project")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(selectedProject?.name ?? tr("submit.field.project"))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(Color.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
        }
    }

    private func editableRow(label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            if aiFields.contains(label) {
                StatusPill(text: "AI", tint: Tokens.aiPurple, leadingIcon: "sparkles")
            }
            TextField(placeholder, text: text)
                .font(.system(size: 13.5, weight: .medium))
                .multilineTextAlignment(.trailing)
                .onChange(of: text.wrappedValue) { _, _ in aiFields.remove(label) }
        }
        .padding(.vertical, 11)
    }

    private func pickerRow(label: String, value: String, options: [String], onPick: @escaping (String) -> Void) -> some View {
        Menu {
            ForEach(options, id: \.self) { opt in
                Button {
                    onPick(opt)
                } label: {
                    HStack {
                        Text(opt)
                        if value == opt { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack {
                Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                if aiFields.contains(label) {
                    StatusPill(text: "AI", tint: Tokens.aiPurple, leadingIcon: "sparkles")
                }
                Text(value).font(.system(size: 13.5, weight: .medium)).foregroundStyle(Color.primary)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 11)
        }
    }

    private func routingBanner(project: DomainProject) -> some View {
        let threshold = project.approvalThreshold.decimalValue
        let tint = willAutoApprove ? Tokens.approved : Tokens.pending
        let icon = willAutoApprove ? "bolt.fill" : "person.crop.circle.badge.clock"
        let title = willAutoApprove ? autoRouteTitle : "Requires manager approval"
        let detail: String
        if willAutoApprove {
            detail = expenseKind == .preApproval
                ? "Under \(money(threshold, currency: project.budget.currency)) limit for \(project.name). You can buy after submission."
                : "Under \(money(threshold, currency: project.budget.currency)) limit for \(project.name). Finance can process reimbursement."
        } else {
            detail = expenseKind == .preApproval
                ? "Over \(money(threshold, currency: project.budget.currency)) limit for \(project.name). Wait for approval before purchasing."
                : "Over \(money(threshold, currency: project.budget.currency)) limit for \(project.name). Manager review is required before reimbursement."
        }
        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(detail).font(.system(size: 11.5)).foregroundStyle(.secondary).lineLimit(nil)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
    }

    private var autoRouteTitle: String {
        expenseKind == .preApproval ? "Auto-approved pre-approval" : "Routes to finance"
    }

    private func submitExpense() {
        guard let p = selectedProject else { return }
        isSubmitting = true

        Task {
            let input = repositoryInput(project: p)
            let didSubmit: Bool
            if let draftId = scannedDraftId {
                didSubmit = await repositoryApp.updateDraftAndSubmit(id: draftId, input)
            } else {
                didSubmit = await repositoryApp.createAndSubmitExpense(input)
            }

            await MainActor.run {
                isSubmitting = false
                if didSubmit {
                    onSubmit()
                }
            }
        }
    }

    private func saveDraft() {
        saveDraftError = nil
        guard let project = selectedProject else {
            saveDraftError = activeProjects.isEmpty
                ? "Create a project first — drafts live inside a project."
                : "Pick a project before saving a draft."
            return
        }
        isSavingDraft = true

        Task {
            let input = repositoryInput(project: project)
            let didSave: Bool
            if let draftId = scannedDraftId {
                didSave = await repositoryApp.updateDraftOnly(id: draftId, input)
            } else {
                didSave = await repositoryApp.createDraft(input)
            }

            await MainActor.run {
                isSavingDraft = false
                if didSave {
                    onClose()
                } else {
                    saveDraftError = repositoryApp.lastError ?? "Could not save draft. Check connection and try again."
                }
            }
        }
    }

    private func repositoryInput(project: DomainProject) -> ExpenseDraftInput {
        let resolvedCurrency = effectiveCurrency
        let categoryId = selectedCategoryId
            ?? workspaceCategories.first(where: { project.allowedCategoryIds.isEmpty || project.allowedCategoryIds.contains($0.id) })?.id
            ?? workspaceCategories.first?.id
            ?? ""
        return ExpenseDraftInput(
            workspaceId: project.workspaceId,
            projectId: project.id,
            kind: expenseKind,
            merchant: trimmedVendor.isEmpty ? "Untitled expense" : trimmedVendor,
            amount: MoneyAmount(minorUnits: Int((amount * 100).rounded()), currency: resolvedCurrency),
            categoryId: categoryId,
            businessPurpose: trimmedPurpose,
            purchaseDate: expenseKind == .reimbursementClaim ? purchaseDate : nil,
            neededByDate: expenseKind == .preApproval ? neededByDate : nil
        )
    }

    private func iconFor(_ category: String) -> String {
        switch category {
        case "Meals":    return "🍱"
        case "Travel":   return "✈️"
        case "Software": return "💻"
        case "Office":   return "🏢"
        default:         return "🧾"
        }
    }
}

// MARK: – Scanning sheet

struct ScanningSheet: View {
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(colors: [Tokens.aiPurple, Tokens.slate500],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "sparkles")
                    .font(.system(size: 30))
                    .foregroundStyle(.white)
            }
            .frame(width: 70, height: 70)
            .scaleEffect(pulse ? 1.08 : 1.0)
            .opacity(pulse ? 0.75 : 1.0)
            .animation(.easeInOut(duration: 0.7).repeatForever(), value: pulse)

            Text(tr("submit.scan.processing"))
                .font(.system(size: 17, weight: .semibold))
            Text(tr("submit.scan.processing_detail"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { pulse = true }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    var onCaptured: (Data) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.isPresented = false
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 0.8) {
                parent.onCaptured(data)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

struct ReceiptSourceSheet: View {
    /// (image data, file name, content type)
    var onScan: (Data, String, String) -> Void
    @State private var showCamera = false
    @State private var photosItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(tr("submit.scan.add_receipt"))
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)

            VStack(spacing: 0) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        sourceRow(icon: "camera.fill", tint: Tokens.slate500,
                                  title: tr("submit.scan.take_photo"),
                                  subtitle: tr("submit.scan.take_photo.subtitle"))
                    }
                    .buttonStyle(.plain)
                    Divider().opacity(0.4).padding(.leading, 56)
                }

                PhotosPicker(selection: $photosItem, matching: .images) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.fill")
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Tokens.aiPurple, in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("submit.scan.choose_library")).font(.system(size: 13.5, weight: .semibold))
                            Text(tr("submit.scan.choose_library.subtitle")).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            Spacer()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { data in
                onScan(data, "receipt-\(Int(Date().timeIntervalSince1970)).jpg", "image/jpeg")
            }
            .ignoresSafeArea()
        }
        .onChange(of: photosItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        onScan(data, "receipt-\(Int(Date().timeIntervalSince1970)).jpg", "image/jpeg")
                    }
                }
            }
        }
    }

    private func sourceRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct LocalScanField: Identifiable, Hashable {
    let id: String
    let label: String
    var value: String
    var confidence: ScanFieldConfidence
    var wasEdited: Bool = false
}

private extension ScanFieldConfidence {
    var tint: Color {
        switch self {
        case .high: return Tokens.approved
        case .medium: return Tokens.pending
        case .low: return Tokens.rejected
        case .manual: return Tokens.slate500
        }
    }

    var icon: String {
        switch self {
        case .high: return "checkmark"
        case .medium: return "exclamationmark"
        case .low: return "xmark"
        case .manual: return "pencil"
        }
    }
}

struct FormFieldRow: View {
    let label: String
    let value: String
    var aiTagged: Bool = false
    var showChevron: Bool = true
    var body: some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            if aiTagged {
                StatusPill(text: "AI", tint: Tokens.aiPurple, leadingIcon: "sparkles")
            }
            Text(value).font(.system(size: 13.5, weight: .medium))
            if showChevron {
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 11)
    }
}

extension Text {
    func primaryActionLabel() -> some View {
        self.font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 16))
    }

    func secondaryActionLabel() -> some View {
        self.font(.system(size: 14, weight: .medium))
            .frame(maxWidth: .infinity)
            .padding(14)
    }
}
