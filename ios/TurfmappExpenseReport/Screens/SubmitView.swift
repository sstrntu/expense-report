import SwiftUI

struct SubmitView: View {
    @EnvironmentObject var app: AppState
    var onClose: () -> Void
    var onSubmit: () -> Void

    @State private var vendor: String     = ""
    @State private var amountText: String = ""
    @State private var purpose: String    = ""
    @State private var category: String   = "Meals"
    @State private var selectedProjectId: String?

    @State private var isScanning = false
    @State private var hasScanned = false
    @State private var showReceiptOptions = false
    @State private var showDiscardConfirm = false
    @State private var aiFields: Set<String> = []

    private let categories = ["Meals", "Travel", "Software", "Office", "Other"]

    private var amount: Double { Double(amountText) ?? 0 }
    private var selectedProject: Project? {
        if let id = selectedProjectId { return app.currentProjects.first { $0.id == id } }
        return app.currentProjects.first
    }
    private var willAutoApprove: Bool {
        guard let p = selectedProject else { return false }
        return amount > 0 && amount <= p.autoApproveThreshold
    }
    private var canSubmit: Bool {
        !vendor.isEmpty && amount > 0 && !purpose.isEmpty && selectedProject != nil
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Expense").font(.system(size: 26, weight: .bold))
                    Text("Small expenses are auto-approved")
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

            scanCard

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    editableRow(label: "Vendor",  placeholder: "Whole Foods Market", text: $vendor)
                    Divider().opacity(0.4)
                    amountRow
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Date", value: "Today", showChevron: false)
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

            if amount > 0, let p = selectedProject {
                routingBanner(project: p)
            }

            Button {
                guard let p = selectedProject else { return }
                app.addExpense(merchant: vendor, amount: amount, category: category,
                               project: p, purpose: purpose, icon: iconFor(category))
                onSubmit()
            } label: {
                Text(submitLabel).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity(canSubmit ? 1 : 0.5)
            .disabled(!canSubmit)

            Button {
                app.saveDraft(merchant: vendor, amount: amount, category: category, project: selectedProject)
                onClose()
            } label: {
                Text("Save Draft").secondaryActionLabel()
            }
            .buttonStyle(.plain)
            .opacity(vendor.isEmpty && amountText.isEmpty && purpose.isEmpty ? 0.5 : 1)
            .disabled(vendor.isEmpty && amountText.isEmpty && purpose.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(isPresented: $isScanning) {
            ScanningSheet()
                .presentationDetents([.height(280)])
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showReceiptOptions) {
            ReceiptSourceSheet {
                showReceiptOptions = false
                startScan()
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
        if hasScanned {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Tokens.aiPurple)
                Text("Receipt scanned — review the auto-filled fields below")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Rescan") { startScan() }
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
                        Text("AI fills vendor, amount, and category")
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

    private func startScan() {
        isScanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            vendor = "Whole Foods Market"
            amountText = "47.23"
            category = "Meals"
            aiFields = ["Vendor", "Amount", "Category"]
            hasScanned = true
            isScanning = false
        }
    }

    private var submitLabel: String {
        guard amount > 0 else { return "Submit" }
        return willAutoApprove ? "Submit Expense" : "Submit for Approval"
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
        let title = willAutoApprove ? "Auto-approved" : "Requires manager approval"
        let detail = willAutoApprove
            ? "Under \(money(project.autoApproveThreshold)) limit for \(project.name). Submit and attach the receipt."
            : "Over \(money(project.autoApproveThreshold)) limit for \(project.name). Wait for approval before purchasing."
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

struct ReceiptSourceSheet: View {
    var onScan: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var cameraAllowed = false
    @State private var photosAllowed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add receipt or product photo")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            Text("Use AI extraction when camera or photo access is available. Manual upload remains available as a fallback.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                permissionRow(title: "Camera", subtitle: cameraAllowed ? "Allowed" : "Tap to allow camera access",
                              icon: "camera.fill", active: cameraAllowed) {
                    cameraAllowed.toggle()
                }
                Divider().opacity(0.4)
                permissionRow(title: "Photo Library", subtitle: photosAllowed ? "Allowed" : "Tap to allow photo access",
                              icon: "photo.fill", active: photosAllowed) {
                    photosAllowed.toggle()
                }
                Divider().opacity(0.4)
                Button {
                    dismiss()
                    onScan()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(Tokens.aiPurple)
                            .frame(width: 30, height: 30)
                            .background(Tokens.aiPurple.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Scan with AI").font(.system(size: 13.5, weight: .semibold))
                            Text("AI extraction for receipt or product photo")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            infoBanner(icon: "paperclip", tint: Tokens.slate500,
                       title: "Manual fallback",
                       message: "If permissions are denied, users can still attach a receipt file before submitting.")
                .padding(.horizontal, 20)

            Spacer()
        }
    }

    private func permissionRow(title: String, subtitle: String, icon: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(active ? Tokens.approved : .secondary)
                    .frame(width: 30, height: 30)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13.5, weight: .medium))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: active ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(active ? Tokens.approved : Color.secondary.opacity(0.5))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
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
