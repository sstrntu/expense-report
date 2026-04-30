import SwiftUI

struct DetailView: View {
    let expense: Expense
    var role: AppRole
    var onBack: () -> Void
    var onAction: (ExpenseStatus, PaymentMethod?, String?) -> Void

    @State private var showPurchaseSheet   = false
    @State private var showReimbursedSheet = false
    @State private var showRejectSheet     = false
    @State private var previewReceipt: ReceiptPreview? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            }
            .padding(.horizontal, 4).padding(.top, 4)

            GlassCard(padding: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text(expense.icon)
                            .font(.system(size: 26))
                            .frame(width: 50, height: 50)
                            .background(Color.primary.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.merchant).font(.system(size: 16, weight: .bold))
                            Text(expense.date).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(status: expense.status)
                    }
                    Text(money(expense.amount))
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .tracking(-1)
                }
            }

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    FormFieldRow(label: "Category",     value: expense.category)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Project",      value: expense.project)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Submitted by", value: "Sam Otero")
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Receipt",      value: "receipt.pdf")
                    if let method = expense.paymentMethod {
                        Divider().opacity(0.4)
                        FormFieldRow(label: "Paid via", value: method.rawValue, showChevron: false)
                    }
                    if let receipt = expense.paymentReceipt {
                        Divider().opacity(0.4)
                        FormFieldRow(label: "Payment receipt", value: receipt, showChevron: false)
                    }
                }
            }

            receiptPreviewCard

            timelineCard

            commentsCard

            actionArea
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(isPresented: $showPurchaseSheet) {
            PurchaseConfirmSheet { receipt in
                onAction(.purchased, nil, receipt)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showReimbursedSheet) {
            MarkAsPaidSheet { method, receipt in
                onAction(.reimbursed, method, receipt)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showRejectSheet) {
            RejectReasonSheet { _ in
                onAction(.rejected, nil, nil)
            }
            .presentationDetents([.height(320)])
        }
        .sheet(item: $previewReceipt) { receipt in
            ReceiptPreviewSheet(receipt: receipt)
                .presentationDetents([.medium])
        }
    }

    private var receiptPreviewCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                receiptRow(title: "Submitted receipt", file: "receipt.pdf", tint: Tokens.slate500)
                if expense.status == .purchased || expense.status == .reimbursed {
                    Divider().opacity(0.4)
                    receiptRow(title: "Purchase receipt", file: expense.paymentReceipt ?? "purchase_receipt.pdf", tint: Tokens.purchased)
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
                timelineRow("Submitted", "Sam Otero · \(expense.date)", complete: true, tint: Tokens.slate500)
                timelineRow("Approved", "Manager review", complete: [.approved, .purchased, .reimbursed].contains(expense.status), tint: Tokens.approved)
                timelineRow("Purchased", "Employee confirms purchase", complete: [.purchased, .reimbursed].contains(expense.status), tint: Tokens.purchased)
                timelineRow("Reimbursed", "Finance marks payment sent", complete: expense.status == .reimbursed, tint: Tokens.reimbursed)
                if expense.status == .rejected {
                    timelineRow("Rejected", "Reason provided by manager", complete: true, tint: Tokens.rejected)
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

    private var commentsCard: some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Notes").font(.system(size: 13, weight: .semibold))
                noteRow("Sam", "Submitted for \(expense.project).", tint: Tokens.slate500)
                if expense.status == .rejected {
                    noteRow("Manager", "Please add more context and a clearer business purpose.", tint: Tokens.rejected)
                } else if expense.status == .approved || expense.status == .purchased || expense.status == .reimbursed {
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
        case .pending:
            if role == .manager {
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

                    Button { onAction(.approved, nil, nil) } label: {
                        Label("Approve", systemImage: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(15)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.approved, in: RoundedRectangle(cornerRadius: 14))
                }
            } else {
                statusInfoCard(
                    icon: "clock",
                    tint: Tokens.pending,
                    title: "Awaiting approval",
                    message: "Your request is waiting for manager review."
                )
            }

        case .approved:
            if role == .employee {
                Button { showPurchaseSheet = true } label: {
                    Label("I Made the Purchase", systemImage: "bag.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.plain)
                .background(Tokens.purchased, in: RoundedRectangle(cornerRadius: 14))
            } else {
                statusInfoCard(
                    icon: "clock",
                    tint: Tokens.approved,
                    title: "Approved — waiting on employee",
                    message: "The employee will confirm once they've made the purchase."
                )
            }

        case .purchased:
            if role == .manager {
                Button { showReimbursedSheet = true } label: {
                    Label("Mark as Reimbursed", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16)
                }
                .buttonStyle(.plain)
                .background(Tokens.reimbursed, in: RoundedRectangle(cornerRadius: 14))
            } else {
                statusInfoCard(
                    icon: "clock",
                    tint: Tokens.purchased,
                    title: "Purchase confirmed",
                    message: "Your purchase was logged. Waiting for the team to process reimbursement."
                )
            }

        case .rejected:
            statusInfoCard(
                icon: "xmark.circle",
                tint: Tokens.rejected,
                title: "Request not approved",
                message: "Contact your manager for details."
            )

        case .reimbursed:
            statusInfoCard(
                icon: "checkmark.circle.fill",
                tint: Tokens.reimbursed,
                title: "Reimbursed",
                message: "Payment sent to employee outside the app."
            )
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
}

struct ReceiptPreview: Identifiable {
    let id = UUID()
    let title: String
    let fileName: String
    let tint: Color
}

struct ReceiptPreviewSheet: View {
    let receipt: ReceiptPreview
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(receipt.title).font(.system(size: 20, weight: .bold))
                    Text(receipt.fileName).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

            RoundedRectangle(cornerRadius: 20)
                .fill(receipt.tint.opacity(0.12))
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.image.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(receipt.tint)
                        Text("Mock receipt preview")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Real release should show image/PDF preview, zoom, share, and retry if download fails.")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                )
                .frame(height: 260)
                .padding(.horizontal, 20)

            Spacer()
        }
    }
}

// MARK: – Purchase confirmation sheet (employee)

struct PurchaseConfirmSheet: View {
    var onConfirm: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var receiptName: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Confirm Purchase")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            Text("Confirm that you've made this purchase. Attach your receipt so the team can process reimbursement.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("Receipt")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                Button {
                    receiptName = receiptName == nil ? "receipt.pdf" : nil
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: receiptName != nil ? "doc.fill" : "paperclip")
                            .font(.system(size: 16))
                            .foregroundStyle(receiptName != nil ? Tokens.purchased : .secondary)
                        Text(receiptName ?? "Attach receipt")
                            .font(.system(size: 14))
                            .foregroundStyle(receiptName != nil ? Color.primary : .secondary)
                        Spacer()
                        if receiptName != nil {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                        receiptName != nil ? Tokens.purchased.opacity(0.4) : Color.white.opacity(0.4),
                        lineWidth: 0.5
                    ))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                onConfirm(receiptName)
                dismiss()
            } label: {
                Text("Confirm Purchase")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Tokens.purchased, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

struct RejectReasonSheet: View {
    var onReject: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reject request")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            Text("Add a reason so the employee knows what to fix before resubmitting.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            TextField("Reason", text: $reason, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(3, reservesSpace: true)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

            Spacer()

            Button {
                onReject(reason)
                dismiss()
            } label: {
                Text("Reject expense")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Tokens.rejected, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

// MARK: – Reimbursement sheet (manager/financier)

struct MarkAsPaidSheet: View {
    var onConfirm: (PaymentMethod, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: PaymentMethod? = nil
    @State private var receiptName: String? = nil
    @State private var showReceiptPicker = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Mark as Reimbursed")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text("Payment method")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(PaymentMethod.allCases, id: \.self) { method in
                        methodTile(method)
                    }
                }
                .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Payment receipt")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                Button {
                    receiptName = receiptName == nil ? "payment_receipt.pdf" : nil
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: receiptName != nil ? "doc.fill" : "paperclip")
                            .font(.system(size: 16))
                            .foregroundStyle(receiptName != nil ? Tokens.reimbursed : .secondary)
                        Text(receiptName ?? "Attach receipt (optional)")
                            .font(.system(size: 14))
                            .foregroundStyle(receiptName != nil ? Color.primary : .secondary)
                        Spacer()
                        if receiptName != nil {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                        receiptName != nil ? Tokens.reimbursed.opacity(0.4) : Color.white.opacity(0.4),
                        lineWidth: 0.5
                    ))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
            }

            Spacer()

            Button {
                guard let method = selectedMethod else { return }
                onConfirm(method, receiptName)

                dismiss()
            } label: {
                Text(selectedMethod == nil ? "Select a payment method" : "Confirm Reimbursement")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(
                        selectedMethod != nil ? Tokens.reimbursed : Tokens.slate300,
                        in: RoundedRectangle(cornerRadius: 16)
                    )
            }
            .buttonStyle(.plain)
            .disabled(selectedMethod == nil)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func methodTile(_ method: PaymentMethod) -> some View {
        let selected = selectedMethod == method
        return Button { selectedMethod = method } label: {
            VStack(spacing: 8) {
                Image(systemName: method.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? .white : Color.primary)
                Text(method.rawValue)
                    .font(.system(size: 11, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(selected ? .white : Color.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                selected ? Tokens.reimbursed : Color.primary.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selected ? Tokens.reimbursed : Color.white.opacity(0.4), lineWidth: selected ? 0 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
