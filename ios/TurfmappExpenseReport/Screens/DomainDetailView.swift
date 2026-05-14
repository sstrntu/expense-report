import SwiftUI

struct DomainDetailView: View {
    let expense: DomainExpense
    let projects: [DomainProject]
    let events: [ExpenseWorkflowEvent]
    var role: AppRole
    var onBack: () -> Void
    var onApprove: () -> Void
    var onReject: (String) -> Void
    var onResubmit: () -> Void
    var onCancel: () -> Void
    var onConfirmPurchase: (MoneyAmount, String?) -> Void
    var onMarkReimbursed: (PaymentMethod, String?) -> Void
    var onArchive: () -> Void
    var onDelete: () -> Void

    @State private var showPurchaseSheet = false
    @State private var showReimbursedSheet = false
    @State private var showRejectSheet = false
    @State private var showDeleteConfirm = false
    @State private var previewReceipt: ReceiptPreview? = nil

    private var projectName: String { expense.projectName(in: projects) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            summaryCard
            detailsCard
            receiptPreviewCard
            timelineCard
            notesCard
            actionArea
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseConfirmSheet(initialAmount: expense.amount.decimalValue) { finalAmount, receipt in
                onConfirmPurchase(
                    MoneyAmount(
                        minorUnits: Int((finalAmount * 100).rounded()),
                        currency: expense.amount.currency
                    ),
                    receipt
                )
            }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showReimbursedSheet) {
            MarkAsPaidSheet { method, receipt in onMarkReimbursed(method, receipt) }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRejectSheet) {
            RejectReasonSheet { reason in onReject(reason) }
                .presentationDetents([.height(320)])
        }
        .sheet(item: $previewReceipt) { receipt in
            ReceiptPreviewSheet(receipt: receipt)
                .presentationDetents([.medium])
        }
        .confirmationDialog("Delete \"\(expense.merchant)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 999)

            Text("Expense detail")
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            Menu {
                Button(action: onArchive) {
                    Label(expense.isArchived ? "Unarchive" : "Archive",
                          systemImage: expense.isArchived ? "tray.and.arrow.up" : "archivebox")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .glassSurface(corner: 999)
        }
        .padding(.horizontal, 4).padding(.top, 4)
    }

    private var summaryCard: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Text(expense.icon)
                        .font(.system(size: 26))
                        .frame(width: 50, height: 50)
                        .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(expense.merchant).font(.system(size: 16, weight: .bold))
                        Text(expense.displayDate).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(text: expense.status.displayLabel, tint: statusTint, leadingIcon: statusIcon)
                }
                Text(expense.amount.formatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-1)
            }
        }
    }

    private var detailsCard: some View {
        GlassCard(padding: 16) {
            VStack(spacing: 0) {
                FormFieldRow(label: "Type", value: expense.kind.label, showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: "Category", value: expense.categoryLabel)
                Divider().opacity(0.4)
                FormFieldRow(label: "Project", value: projectName)
                Divider().opacity(0.4)
                FormFieldRow(label: "Submitted by", value: "Sira Sasitorn")
                Divider().opacity(0.4)
                FormFieldRow(label: "Receipt", value: receiptLabel)
            }
        }
    }

    private var receiptPreviewCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                receiptRow(title: "Submitted receipt", file: receiptLabel, tint: Tokens.slate500)
                if [.pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement, .reimbursed].contains(expense.status) {
                    Divider().opacity(0.4)
                    receiptRow(title: "Purchase receipt", file: "purchase_receipt.pdf", tint: Tokens.purchased)
                }
                if expense.status == .reimbursed {
                    Divider().opacity(0.4)
                    receiptRow(title: "Reimbursement proof", file: "reimbursement_proof.pdf", tint: Tokens.reimbursed)
                }
            }
        }
    }

    private func receiptRow(title: String, file: String, tint: Color) -> some View {
        Button {
            previewReceipt = ReceiptPreview(title: title, fileName: file, tint: tint)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.image.fill")
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13.5, weight: .medium))
                    Text(file).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "eye.fill").foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private var timelineCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline").font(.system(size: 13, weight: .semibold))
                if events.isEmpty {
                    timelineRow("Created", "No repository events yet", complete: true, tint: Tokens.slate500)
                } else {
                    ForEach(events) { event in
                        timelineRow(
                            event.title,
                            event.subtitle,
                            complete: true,
                            tint: event.tint
                        )
                    }
                }
            }
        }
    }

    private func timelineRow(_ title: String, _ subtitle: String, complete: Bool, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: complete ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(complete ? tint : Color.secondary.opacity(0.45))
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private var notesCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes").font(.system(size: 13, weight: .semibold))
                noteRow("Sira", "Submitted for \(projectName).", tint: Tokens.slate500)
                if expense.status == .rejected {
                    noteRow("Reviewer", "Please add more context and a clearer business purpose.", tint: Tokens.rejected)
                } else if managerApproved {
                    noteRow("Manager", "Approved under project policy.", tint: Tokens.approved)
                }
            }
        }
    }

    private func noteRow(_ author: String, _ message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(color: tint, size: 28, label: String(author.prefix(1)))
            VStack(alignment: .leading, spacing: 1) {
                Text(author).font(.system(size: 11.5, weight: .semibold))
                Text(message).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        switch expense.status {
        case .pendingManagerApproval:
            if role.canApproveExpenses {
                HStack(spacing: 10) {
                    Button { showRejectSheet = true } label: {
                        Label("Reject", systemImage: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.rejected)
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.rejected.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Tokens.rejected.opacity(0.4)))

                    Button(action: onApprove) {
                        Label("Approve", systemImage: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.approved, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                VStack(spacing: 10) {
                    statusInfoCard(icon: "clock", tint: Tokens.pending, title: "Awaiting approval", message: "A manager or admin needs to review this expense.")
                    Button(action: onCancel) {
                        Label("Cancel Submission", systemImage: "xmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.rejected)
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.rejected.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        case .approved:
            if role == .employee && expense.kind == .preApproval {
                Button { showPurchaseSheet = true } label: {
                    Label("I Made the Purchase", systemImage: "bag.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.plain)
                .background(Tokens.purchased, in: RoundedRectangle(cornerRadius: 14))
            } else {
                statusInfoCard(icon: "clock", tint: Tokens.approved, title: "Approved", message: "Waiting for the next workflow step.")
            }
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement:
            if role.canReimburseExpenses {
                Button { showReimbursedSheet = true } label: {
                    Label("Mark as Reimbursed", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.plain)
                .background(Tokens.reimbursed, in: RoundedRectangle(cornerRadius: 14))
            } else {
                statusInfoCard(icon: "clock", tint: Tokens.purchased, title: "Awaiting reimbursement", message: "Finance or an admin needs to process this expense.")
            }
        case .rejected:
            VStack(spacing: 10) {
                statusInfoCard(icon: "xmark.circle", tint: Tokens.rejected, title: "Not approved", message: "Review the reason and resubmit if needed.")
                if role == .employee {
                    Button(action: onResubmit) {
                        Label("Resubmit Expense", systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(16)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        case .reimbursed:
            statusInfoCard(icon: "checkmark.circle.fill", tint: Tokens.reimbursed, title: "Reimbursed", message: "Payment has been marked as sent.")
        case .draft, .submitted, .scanProcessing, .scanFailed, .cancelled, .archived:
            statusInfoCard(icon: statusIcon, tint: statusTint, title: expense.status.displayLabel, message: "No action is currently available.")
        }
    }

    private func statusInfoCard(icon: String, tint: Color, title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(message).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(nil)
            }
        }
        .padding(14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
    }

    private var receiptLabel: String {
        expense.kind == .reimbursementClaim ? "receipt.pdf" : "supporting_document.pdf"
    }

    private var managerApproved: Bool {
        [.approved, .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains(expense.status)
    }

    private var financeReady: Bool {
        [.pendingFinanceReview, .readyForReimbursement, .reimbursed].contains(expense.status)
    }

    private var statusTint: Color {
        switch expense.status {
        case .pendingManagerApproval, .submitted, .scanProcessing: return Tokens.pending
        case .approved: return Tokens.approved
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement: return Tokens.purchased
        case .reimbursed: return Tokens.reimbursed
        case .rejected, .cancelled, .scanFailed: return Tokens.rejected
        case .draft, .archived: return Tokens.slate500
        }
    }

    private var statusIcon: String {
        switch expense.status {
        case .reimbursed: return "checkmark.circle.fill"
        case .rejected, .cancelled, .scanFailed: return "xmark.circle"
        case .approved: return "checkmark"
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement: return "creditcard.fill"
        default: return "clock"
        }
    }
}
