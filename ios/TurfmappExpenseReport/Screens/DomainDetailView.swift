import SwiftUI

struct DomainDetailView: View {
    let expense: DomainExpense
    let projects: [DomainProject]
    var categories: [DomainCategory] = []
    let events: [ExpenseWorkflowEvent]
    var role: AppRole
    var onBack: () -> Void
    var onApprove: () -> Void
    var onReject: (String) -> Void
    var onResubmit: () -> Void
    var onCancel: () -> Void
    var onConfirmPurchase: (MoneyAmount, Data?, String?, String?) -> Void
    var onMarkReimbursed: (PaymentMethod, Data?, String?, String?) -> Void
    var onArchive: () -> Void
    var onDelete: () -> Void
    var onAttachReceipt: (Data, String, String) -> Void = { _, _, _ in }

    @EnvironmentObject private var repositoryApp: RepositoryAppState

    @State private var showPurchaseSheet = false
    @State private var showReimbursedSheet = false
    @State private var showRejectSheet = false
    @State private var showDeleteConfirm = false
    @State private var showReceiptSource = false
    @State private var previewReceipt: ReceiptPreview? = nil
    @State private var attachments: [ExpenseAttachment] = []

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
            PurchaseConfirmSheet(initialAmount: expense.amount.decimalValue, currency: expense.amount.currency) { finalAmount, data, fileName, contentType in
                onConfirmPurchase(
                    MoneyAmount(
                        minorUnits: Int((finalAmount * 100).rounded()),
                        currency: expense.amount.currency
                    ),
                    data, fileName, contentType
                )
            }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showReimbursedSheet) {
            MarkAsPaidSheet { method, data, fileName, contentType in
                onMarkReimbursed(method, data, fileName, contentType)
            }
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRejectSheet) {
            RejectReasonSheet { reason in onReject(reason) }
                .presentationDetents([.medium])
        }
        .sheet(item: $previewReceipt) { receipt in
            ReceiptPreviewSheet(receipt: receipt)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showReceiptSource) {
            ReceiptSourceSheet { data, fileName, contentType in
                showReceiptSource = false
                onAttachReceipt(data, fileName, contentType)
            }
            .presentationDetents([.height(300)])
        }
        .confirmationDialog(tr("detail.delete.title", expense.merchant), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(tr("common.delete"), role: .destructive) { onDelete() }
            Button(tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(tr("detail.delete.message"))
        }
        .task {
            attachments = await repositoryApp.listAttachments(for: expense.id)
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

            Text(tr("detail.title"))
                .font(.system(size: 15, weight: .semibold))

            Spacer()

            Menu {
                Button(action: onArchive) {
                    Label(expense.isArchived ? tr("common.unarchive") : tr("common.archive"),
                          systemImage: expense.isArchived ? "tray.and.arrow.up" : "archivebox")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(tr("common.delete"), systemImage: "trash")
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
                    StatusPill(text: localizedStatusLabel(expense.status), tint: statusTint, leadingIcon: statusIcon)
                }
                // Headline is the base-currency snapshot when the receipt was
                // foreign — matches the dashboard total. Native amount goes
                // below as the audit line so finance can trace the conversion.
                Text((expense.amountInBase ?? expense.amount).formatted)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .tracking(-1)
                if expense.isConverted {
                    fxAuditLine
                }
            }
        }
    }

    /// "↻ $20.00 USD · 36.0500 THB/USD · May 20, 2026 · Frankfurter" — every
    /// piece of the conversion the user (or auditor) might need to verify.
    private var fxAuditLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 10, weight: .semibold))
            Text(fxAuditText).font(.system(size: 11))
        }
        .foregroundStyle(.secondary)
    }

    private var fxAuditText: String {
        var parts: [String] = [expense.amount.formatted]
        if let rate = expense.fxRate, let inBase = expense.amountInBase {
            let rateString = String(format: "%.4f", rate)
            parts.append("\(rateString) \(inBase.currency)/\(expense.amount.currency)")
        }
        if let asOf = expense.fxRateAsOf {
            parts.append(Self.fxDateFormatter.string(from: asOf))
        }
        if let source = expense.fxSource, source != "identity" {
            parts.append(source.replacingOccurrences(of: "-", with: " ").capitalized)
        }
        return parts.joined(separator: " · ")
    }

    private static let fxDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    private var detailsCard: some View {
        GlassCard(padding: Tokens.padCard) {
            VStack(spacing: 0) {
                FormFieldRow(label: tr("detail.field.type"), value: localizedKindLabel(expense.kind), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("detail.field.category"), value: categories.first { $0.id == expense.categoryId }?.name ?? expense.categoryLabel)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("detail.field.project"), value: projectName)
                Divider().opacity(0.4)
                FormFieldRow(label: tr("detail.field.submitted_by"), value: submitterName, showChevron: false)
            }
        }
    }

    private var receiptPreviewCard: some View {
        let submitted = attachments.first { $0.kind == .submittedReceipt || $0.kind == .supportingDocument }
        let purchase = attachments.first { $0.kind == .purchaseReceipt }
        let reimbursement = attachments.first { $0.kind == .reimbursementProof }

        return GlassCard(padding: 0) {
            VStack(spacing: 0) {
                if let a = submitted {
                    receiptRow(title: tr("detail.receipts.submitted"), attachment: a, tint: Tokens.slate500)
                } else if !attachments.isEmpty || expense.status != .draft {
                    receiptRow(title: tr("detail.receipts.submitted"), attachment: nil, tint: Tokens.slate500)
                }
                if [.pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement, .reimbursed].contains(expense.status) {
                    Divider().opacity(0.4)
                    receiptRow(title: tr("detail.receipts.purchase"), attachment: purchase, tint: Tokens.purchased)
                }
                if expense.status == .reimbursed {
                    Divider().opacity(0.4)
                    receiptRow(title: tr("detail.receipts.reimbursement"), attachment: reimbursement, tint: Tokens.reimbursed)
                }
                Divider().opacity(0.4)
                Button { showReceiptSource = true } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Tokens.slate500)
                            .frame(width: 32, height: 32)
                            .background(Tokens.slate500.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tr("detail.add_receipt")).font(.system(size: 13.5, weight: .semibold))
                            Text(tr("detail.add_receipt.subtitle")).font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func receiptRow(title: String, attachment: ExpenseAttachment?, tint: Color) -> some View {
        let fileName = attachment?.fileName ?? tr("detail.receipt_preview.title")
        let hasFile = attachment != nil
        return Button {
            guard hasFile, let a = attachment else { return }
            previewReceipt = ReceiptPreview(
                title: title,
                fileName: a.fileName,
                tint: tint,
                loadImage: { [repositoryApp] in await repositoryApp.downloadAttachment(a) }
            )
        } label: {
            HStack(spacing: 12) {
                Image(systemName: hasFile ? "doc.text.image.fill" : "doc.text.image")
                    .foregroundStyle(hasFile ? tint : Color.secondary)
                    .frame(width: 32, height: 32)
                    .background((hasFile ? tint : Color.secondary).opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13.5, weight: .medium))
                    Text(fileName).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if hasFile {
                    Image(systemName: "eye.fill").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .disabled(!hasFile)
    }

    private var timelineCard: some View {
        GlassCard(padding: Tokens.padDense) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("detail.timeline")).font(.system(size: 13, weight: .semibold))
                if events.isEmpty {
                    timelineRow(tr("detail.timeline.created"), tr("detail.timeline.no_events"), complete: true, tint: Tokens.slate500)
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

    /// Surfaces only the events that carry a real human-authored note
    /// (rejection reasons, approval comments, etc.). Hidden entirely when
    /// there are none so we never render fake placeholder content.
    @ViewBuilder
    private var notesCard: some View {
        let noted = events.filter { ($0.note?.isEmpty == false) }
        if !noted.isEmpty {
            GlassCard(padding: Tokens.padDense) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(tr("detail.notes")).font(.system(size: 13, weight: .semibold))
                    ForEach(noted) { event in
                        noteRow(noteAuthor(for: event), event.note ?? "", tint: event.tint)
                    }
                }
            }
        }
    }

    private func noteAuthor(for event: ExpenseWorkflowEvent) -> String {
        switch event.eventType {
        case "rejected": return tr("detail.notes.author.reviewer")
        case "approved": return tr("detail.notes.author.manager")
        default: return event.title
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
        // Project-aware authorization: a workspace manager/admin can approve
        // any project; a project_approver/project_admin can approve only
        // their assigned projects. canCurrentUserApprove / Reimburse fold
        // both rules into one check that matches the server's RLS.
        let canApproveThis = repositoryApp.canCurrentUserApprove(expense)
        let canReimburseThis = repositoryApp.canCurrentUserReimburse(expense)
        switch expense.status {
        case .pendingManagerApproval:
            if canApproveThis {
                HStack(spacing: 10) {
                    Button { showRejectSheet = true } label: {
                        Label(tr("detail.action.reject"), systemImage: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.rejected)
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.rejected.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Tokens.rejected.opacity(0.4)))

                    Button(action: onApprove) {
                        Label(tr("detail.action.approve"), systemImage: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.approved, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                VStack(spacing: 10) {
                    statusInfoCard(icon: "clock", tint: Tokens.pending, title: tr("detail.info.awaiting_approval.title"), message: tr("detail.info.awaiting_approval.message"))
                    Button(action: onCancel) {
                        Label(tr("detail.action.cancel_submission"), systemImage: "xmark.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Tokens.rejected)
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.rejected.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        case .approved:
            // "I made the purchase" must be limited to the submitter — anyone
            // else seeing the button is both a security foot-gun and a UX trap
            // (the server-side RLS rejects non-submitters with a permission
            // error). canConfirmPurchase(_:currentMembershipId:) does the
            // status + kind + submitter check in one place.
            if ExpenseWorkflow.canConfirmPurchase(expense, currentMembershipId: repositoryApp.currentMembershipId) {
                Button { showPurchaseSheet = true } label: {
                    Label(tr("detail.action.purchased"), systemImage: "bag.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.plain)
                .background(Tokens.purchased, in: RoundedRectangle(cornerRadius: 14))
            } else if canReimburseThis && expense.kind != .preApproval {
                Button { showReimbursedSheet = true } label: {
                    Label(tr("detail.action.mark_reimbursed"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.plain)
                .background(Tokens.reimbursed, in: RoundedRectangle(cornerRadius: 14))
            } else {
                statusInfoCard(icon: "clock", tint: Tokens.approved, title: tr("detail.info.approved.title"), message: tr("detail.info.approved.message"))
            }
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement:
            if canReimburseThis {
                Button { showReimbursedSheet = true } label: {
                    Label(tr("detail.action.mark_reimbursed"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.plain)
                .background(Tokens.reimbursed, in: RoundedRectangle(cornerRadius: 14))
            } else {
                statusInfoCard(icon: "clock", tint: Tokens.purchased, title: tr("detail.info.awaiting_reimbursement.title"), message: tr("detail.info.awaiting_reimbursement.message"))
            }
        case .rejected:
            VStack(spacing: 10) {
                statusInfoCard(icon: "xmark.circle", tint: Tokens.rejected, title: tr("detail.info.not_approved.title"), message: tr("detail.info.not_approved.message"))
                if role == .employee {
                    Button(action: onResubmit) {
                        Label(tr("detail.action.resubmit"), systemImage: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(16)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        case .reimbursed:
            statusInfoCard(icon: "checkmark.circle.fill", tint: Tokens.reimbursed, title: tr("detail.info.reimbursed.title"), message: tr("detail.info.reimbursed.message"))
        case .draft, .submitted, .scanProcessing, .scanFailed, .cancelled, .archived:
            statusInfoCard(icon: statusIcon, tint: statusTint, title: localizedStatusLabel(expense.status), message: tr("detail.info.no_action"))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.25), lineWidth: 0.5))
    }

    /// Resolves the submitter membership id to a real display name, falling
    /// back to a generic label when the lookup fails (e.g. membership
    /// removed, or members haven't loaded yet). Previously this was a
    /// hardcoded "Sira Sasitorn" placeholder.
    private var submitterName: String {
        if let member = repositoryApp.members.first(where: { $0.id == expense.submittedByMembershipId }) {
            return member.displayName
        }
        return tr("detail.field.submitted_by.unknown")
    }

    private var managerApproved: Bool {
        [.approved, .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains(expense.status)
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
