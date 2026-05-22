import SwiftUI

// Reusable sheet components used by `DomainDetailView`:
//   - `ReceiptPreview` / `ReceiptPreviewSheet` — loads + renders an attachment from Supabase Storage.
//   - `PurchaseConfirmSheet` — employee confirms a completed purchase.
//   - `RejectReasonSheet` — manager rejects with a free-text reason.
//   - `MarkAsPaidSheet` — finance marks an expense reimbursed.


struct ReceiptPreview: Identifiable {
    let id = UUID()
    let title: String
    let fileName: String
    let tint: Color
    var loadImage: (() async -> Data?)? = nil
}

struct ReceiptPreviewSheet: View {
    let receipt: ReceiptPreview
    @Environment(\.dismiss) private var dismiss
    @State private var imageData: Data? = nil
    @State private var isLoading = true

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

            if isLoading {
                RoundedRectangle(cornerRadius: 20)
                    .fill(receipt.tint.opacity(0.08))
                    .overlay(ProgressView().tint(receipt.tint))
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 20)
            } else if let data = imageData, let uiImage = UIImage(data: data) {
                ScrollView([.vertical, .horizontal], showsIndicators: false) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(receipt.tint.opacity(0.12))
                    .overlay(
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.image.fill")
                                .font(.system(size: 42)).foregroundStyle(receipt.tint)
                            Text(tr("detail.receipt_preview.title"))
                                .font(.system(size: 15, weight: .semibold))
                            Text(tr("detail.receipt_preview.subtitle"))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).padding(.horizontal, 24)
                        }
                    )
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)
        }
        .task {
            if let load = receipt.loadImage {
                imageData = await load()
            }
            isLoading = false
        }
    }
}

// MARK: – Purchase confirmation sheet (employee)

struct PurchaseConfirmSheet: View {
    let initialAmount: Double
    var onConfirm: (Double, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var finalAmountText: String
    @State private var receiptName: String? = nil

    init(initialAmount: Double, onConfirm: @escaping (Double, String?) -> Void) {
        self.initialAmount = initialAmount
        self.onConfirm = onConfirm
        _finalAmountText = State(initialValue: String(format: "%.2f", initialAmount))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(tr("detail.purchase_sheet.title"))
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            Text(tr("detail.purchase_sheet.subtitle"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text(tr("detail.purchase_sheet.final_amount"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)

                HStack {
                    Text("$")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                    TextField("0.00", text: $finalAmountText)
                        .font(.system(size: 14, weight: .semibold))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5))
                .padding(.horizontal, 20)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(tr("detail.purchase_sheet.receipt"))
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
                        Text(receiptName ?? tr("detail.add_receipt"))
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
                onConfirm(finalAmount, receiptName)
                dismiss()
            } label: {
                Text(tr("detail.purchase_sheet.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Tokens.purchased, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(finalAmount <= 0)
            .opacity(finalAmount > 0 ? 1 : 0.45)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var finalAmount: Double {
        Double(finalAmountText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
    }
}

struct RejectReasonSheet: View {
    var onReject: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var reason = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(tr("detail.reject_sheet.title"))
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            Text(tr("detail.reject_sheet.subtitle"))
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            TextField(tr("detail.reject_sheet.reason_placeholder"), text: $reason, axis: .vertical)
                .font(.system(size: 14))
                .lineLimit(3, reservesSpace: true)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

            Spacer()

            Button {
                onReject(trimmedReason)
                dismiss()
            } label: {
                Text(tr("sheet.reject.title"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).padding(16)
                    .background(Tokens.rejected, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(trimmedReason.isEmpty)
            .opacity(trimmedReason.isEmpty ? 0.45 : 1)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
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
            Text(tr("detail.paid_sheet.title"))
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            VStack(alignment: .leading, spacing: 10) {
                Text(tr("detail.paid_sheet.method"))
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
                Text(tr("detail.paid_sheet.receipt"))
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
                Text(method.localizedLabel)
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
