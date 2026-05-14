import SwiftUI
import PhotosUI

struct SubmitView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onClose: () -> Void
    var onSubmit: () -> Void

    @State private var vendor: String     = ""
    @State private var amountText: String = ""
    @State private var purpose: String    = ""
    @State private var category: String   = "Meals"
    @State private var selectedProjectId: String?
    @State private var expenseKind: ExpenseKind = .preApproval
    @State private var purchaseDate = Date()
    @State private var neededByDate = Date()

    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var scanStatus: ReceiptScanStatus = .notStarted
    @State private var receiptFileName: String? = nil
    @State private var showReceiptOptions = false
    @State private var showDiscardConfirm = false
    @State private var isSubmitting = false
    @State private var isSavingDraft = false
    @State private var duplicateReceiptWarning = false
    @State private var aiFields: Set<String> = []
    @State private var scanFields: [LocalScanField] = []

    private let categories = ["Meals", "Travel", "Software", "Office", "Other"]

    private var trimmedVendor: String { vendor.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedPurpose: String { purpose.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var amount: Double {
        Double(amountText.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
    private var selectedProject: Project? {
        if let id = selectedProjectId { return app.currentProjects.first { $0.id == id } }
        return app.currentProjects.first
    }
    private var willAutoApprove: Bool {
        guard let p = selectedProject else { return false }
        return amount > 0 && amount <= p.autoApproveThreshold
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
                    Text(expenseKind == .preApproval ? "New Approval" : "New Reimbursement")
                        .font(.system(size: 26, weight: .bold))
                    Text(expenseKind == .preApproval ? "Ask before buying" : "Get reimbursed for a purchase")
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
                    editableRow(label: "Vendor",  placeholder: "Whole Foods Market", text: $vendor)
                    Divider().opacity(0.4)
                    amountRow
                    Divider().opacity(0.4)
                    workflowDateRow
                    Divider().opacity(0.4)
                    pickerRow(label: "Category", value: category, options: categories) {
                        category = $0
                        aiFields.remove("Category")
                    }
                    Divider().opacity(0.4)
                    projectRow
                    Divider().opacity(0.4)
                    editableRow(label: "Purpose", placeholder: "Team lunch — design review", text: $purpose)
                }
            }

            if hasAnyInput && !validationMessages.isEmpty {
                validationCard
            }

            if let lastError = repositoryApp.lastError {
                infoBanner(
                    icon: "exclamationmark.shield.fill",
                    tint: Tokens.rejected,
                    title: "Cannot submit expense",
                    message: lastError
                )
            }

            if duplicateReceiptWarning {
                infoBanner(
                    icon: "doc.on.doc.fill",
                    tint: Tokens.pending,
                    title: "Possible duplicate receipt",
                    message: "This file name was already attached in this draft. Keep it only if it is a different image."
                )
            }

            if amount > 0, let p = selectedProject {
                routingBanner(project: p)
            }

            Button {
                submitExpense()
            } label: {
                Text(isSubmitting ? "Submitting..." : submitLabel).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity(canSubmit && !isSubmitting ? 1 : 0.5)
            .disabled(!canSubmit || isSubmitting)

            Button {
                saveDraft()
            } label: {
                Text(isSavingDraft ? "Saving..." : "Save Draft").secondaryActionLabel()
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
            ReceiptSourceSheet { fileName in
                showReceiptOptions = false
                startScan(fileName: fileName)
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Discard this expense?", isPresented: $showDiscardConfirm, titleVisibility: .visible) {
            Button("Discard draft", role: .destructive) { onClose() }
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Your vendor, amount, purpose, and receipt details have not been submitted.")
        }
    }

    // MARK: – AI scan card

    private var expenseTypePicker: some View {
        GlassCard(padding: 12) {
            Picker("Expense type", selection: $expenseKind) {
                Text("Pre-approval").tag(ExpenseKind.preApproval)
                Text("Claim reimbursement").tag(ExpenseKind.reimbursementClaim)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var draftsCard: some View {
        if !app.currentDrafts.isEmpty {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    Text("Drafts")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)
                    ForEach(Array(app.currentDrafts.prefix(2).enumerated()), id: \.element.id) { idx, draft in
                        if idx > 0 { Divider().opacity(0.4) }
                        Button {
                            vendor = draft.merchant == "Untitled expense" ? "" : draft.merchant
                            amountText = draft.amount == 0 ? "" : String(format: "%.2f", draft.amount)
                            category = draft.category
                            selectedProjectId = app.currentProjects.first { $0.name == draft.project }?.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.badge.clock")
                                    .foregroundStyle(Tokens.pending)
                                    .frame(width: 32, height: 32)
                                    .background(Tokens.pending.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(draft.merchant).font(.system(size: 13.5, weight: .semibold))
                                    Text("\(draft.project) · \(draft.updated)")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(draft.amount == 0 ? "--" : money(draft.amount))
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
                    Text(scanStatus == .uploading ? "Uploading receipt" : "Scanning receipt")
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
                    title: "Scan failed",
                    message: "Enter the receipt fields manually or try another photo."
                )
                Button { showReceiptOptions = true } label: {
                    Label("Try Another Photo", systemImage: "camera.fill")
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
                    Text("Receipt scanned")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text("Review extracted fields before submitting")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Rescan") { showReceiptOptions = true }
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
                        Text("Scan receipt or product").font(.system(size: 14, weight: .semibold))
                        Text(expenseKind == .preApproval ? "Attach context or quote" : "AI fills vendor, amount, and category")
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
                Text("AI field review")
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

    private func startScan(fileName: String) {
        duplicateReceiptWarning = receiptFileName == fileName && (hasScanned || scanStatus == .failed)
        receiptFileName = fileName
        scanStatus = .uploading
        isScanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
            scanStatus = .processing
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            if fileName.contains("failed") {
                scanFields = []
                hasScanned = false
                scanStatus = .failed
                isScanning = false
                return
            }
            vendor = "Whole Foods Market"
            amountText = "47.23"
            category = "Meals"
            purchaseDate = Date()
            aiFields = ["Vendor", "Amount", "Category"]
            scanFields = [
                LocalScanField(id: "merchant", label: "Vendor", value: "Whole Foods Market", confidence: .high),
                LocalScanField(id: "amount", label: "Amount", value: "47.23", confidence: .high),
                LocalScanField(id: "category", label: "Category", value: "Meals", confidence: .medium)
            ]
            hasScanned = true
            scanStatus = .needsReview
            isScanning = false
        }
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
            category = value
            aiFields.remove("Category")
        default:
            break
        }
    }

    private var submitLabel: String {
        guard amount > 0 else { return "Submit" }
        switch expenseKind {
        case .preApproval:
            return willAutoApprove ? "Submit Pre-approval" : "Submit for Approval"
        case .reimbursementClaim:
            return willAutoApprove ? "Submit Claim" : "Submit Claim for Review"
        }
    }

    // MARK: – Form rows

    private var amountRow: some View {
        HStack {
            Text("Amount").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            if aiFields.contains("Amount") {
                StatusPill(text: "AI", tint: Tokens.aiPurple, leadingIcon: "sparkles")
            }
            Text("$").font(.system(size: 13.5, weight: .medium)).foregroundStyle(.secondary)
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
            Text(expenseKind == .preApproval ? "Needed by" : "Purchase date")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Spacer()
            DatePicker(
                expenseKind == .preApproval ? "Needed by" : "Purchase date",
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
            title: "Complete required fields",
            message: validationMessages.joined(separator: " ")
        )
    }

    private var projectRow: some View {
        Menu {
            ForEach(app.currentProjects) { p in
                Button {
                    selectedProjectId = p.id
                } label: {
                    HStack {
                        Text(p.name)
                        if selectedProjectId == p.id || (selectedProjectId == nil && p.id == app.currentProjects.first?.id) {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Text("Project").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                Text(selectedProject?.name ?? "Select project")
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

    private func routingBanner(project: Project) -> some View {
        let tint = willAutoApprove ? Tokens.approved : Tokens.pending
        let icon = willAutoApprove ? "bolt.fill" : "person.crop.circle.badge.clock"
        let title = willAutoApprove ? autoRouteTitle : "Requires manager approval"
        let detail: String
        if willAutoApprove {
            detail = expenseKind == .preApproval
                ? "Under \(money(project.autoApproveThreshold)) limit for \(project.name). You can buy after submission."
                : "Under \(money(project.autoApproveThreshold)) limit for \(project.name). Finance can process reimbursement."
        } else {
            detail = expenseKind == .preApproval
                ? "Over \(money(project.autoApproveThreshold)) limit for \(project.name). Wait for approval before purchasing."
                : "Over \(money(project.autoApproveThreshold)) limit for \(project.name). Manager review is required before reimbursement."
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
            let upload = receiptFileName.map {
                PendingReceiptUpload(kind: .submittedReceipt, fileName: $0, contentType: "image/jpeg", data: Data("mock-receipt".utf8))
            }
            let didSubmit = await repositoryApp.createAndSubmitExpense(repositoryInput(project: p), receipt: upload)

            await MainActor.run {
                isSubmitting = false
                if didSubmit {
                    app.addExpense(kind: expenseKind, merchant: trimmedVendor, amount: amount, category: category,
                                   project: p, purpose: trimmedPurpose, icon: iconFor(category))
                    onSubmit()
                }
            }
        }
    }

    private func saveDraft() {
        isSavingDraft = true
        let project = selectedProject

        Task {
            var didSaveRepositoryDraft = project == nil
            if let project {
                didSaveRepositoryDraft = await repositoryApp.createDraft(repositoryInput(project: project))
            }

            await MainActor.run {
                isSavingDraft = false
                if didSaveRepositoryDraft {
                    app.saveDraft(merchant: vendor, amount: amount, category: category, project: project)
                    onClose()
                }
            }
        }
    }

    private func repositoryInput(project: Project) -> ExpenseDraftInput {
        ExpenseDraftInput(
            workspaceId: project.companyId,
            projectId: project.id,
            kind: expenseKind,
            merchant: trimmedVendor.isEmpty ? "Untitled expense" : trimmedVendor,
            amount: MoneyAmount(minorUnits: Int((amount * 100).rounded()), currency: "USD"),
            categoryId: category.lowercased(),
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

            Text("Reading receipt…")
                .font(.system(size: 17, weight: .semibold))
            Text("Extracting vendor, amount, date, and category")
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
    var onPicked: () -> Void

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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { self.parent.onPicked() }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

struct ReceiptSourceSheet: View {
    var onScan: (String) -> Void
    @State private var showCamera = false
    @State private var photosItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Add receipt or product photo")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24).padding(.bottom, 16)

            VStack(spacing: 0) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: {
                        sourceRow(icon: "camera.fill", tint: Tokens.slate500,
                                  title: "Take Photo",
                                  subtitle: "Capture your receipt with the camera")
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
                            Text("Choose from Library").font(.system(size: 13.5, weight: .semibold))
                            Text("Pick an existing receipt photo").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                Divider().opacity(0.4).padding(.leading, 56)

                Button { onScan("failed_receipt.jpg") } label: {
                    sourceRow(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                              title: "Use Unreadable Sample",
                              subtitle: "Preview failed scan and manual entry fallback")
                }
                .buttonStyle(.plain)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            Spacer()
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(isPresented: $showCamera) { onScan("camera_receipt.jpg") }
                .ignoresSafeArea()
        }
        .onChange(of: photosItem) { _, item in
            guard item != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { onScan("library_receipt.jpg") }
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
