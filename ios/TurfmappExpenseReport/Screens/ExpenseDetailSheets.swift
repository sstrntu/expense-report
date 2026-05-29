import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

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
        SheetScaffold(
            scrolls: false,
            header: { SheetHeader(title: receipt.title, subtitle: receipt.fileName, onClose: { dismiss() }) },
            content: {
                Group {
                    if isLoading {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(receipt.tint.opacity(0.08))
                            .overlay(ProgressView().tint(receipt.tint))
                            .frame(maxHeight: .infinity)
                    } else if let data = imageData, let uiImage = UIImage(data: data) {
                        // Scale the whole receipt to fit the available area so it
                        // never gets clipped by the sheet, regardless of aspect.
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    }
                }
                .frame(maxHeight: .infinity)
            }
        )
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
    let currency: String
    var onConfirm: (Double, Data?, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var finalAmountText: String
    @State private var pickedData: Data? = nil
    @State private var pickedFileName: String? = nil
    @State private var pickedContentType: String? = nil
    @State private var photosItem: PhotosPickerItem? = nil
    @State private var showPickerOptions = false
    @State private var showImagePicker = false
    @State private var showFilePicker = false

    init(initialAmount: Double, currency: String, onConfirm: @escaping (Double, Data?, String?, String?) -> Void) {
        self.initialAmount = initialAmount
        self.currency = currency
        self.onConfirm = onConfirm
        _finalAmountText = State(initialValue: String(format: "%.2f", initialAmount))
    }

    private var currencySymbol: String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "THB": return "฿"
        default: return currency
        }
    }

    var body: some View {
        SheetScaffold(
            header: {
                SheetHeader(
                    title: tr("detail.purchase_sheet.title"),
                    subtitle: tr("detail.purchase_sheet.subtitle"),
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("detail.purchase_sheet.final_amount"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(currencySymbol)
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
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("detail.purchase_sheet.receipt"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Button {
                            if pickedFileName != nil {
                                pickedData = nil; pickedFileName = nil; pickedContentType = nil; photosItem = nil
                            } else {
                                showPickerOptions = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: pickedFileName != nil ? "doc.fill" : "paperclip")
                                    .font(.system(size: 16))
                                    .foregroundStyle(pickedFileName != nil ? Tokens.purchased : .secondary)
                                Text(pickedFileName ?? tr("detail.add_receipt"))
                                    .font(.system(size: 14))
                                    .foregroundStyle(pickedFileName != nil ? Color.primary : .secondary)
                                    .lineLimit(1)
                                Spacer()
                                if pickedFileName != nil {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                                pickedFileName != nil ? Tokens.purchased.opacity(0.4) : Color.white.opacity(0.4),
                                lineWidth: 0.5
                            ))
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Add Receipt", isPresented: $showPickerOptions, titleVisibility: .visible) {
                            Button("Photo Library") { showImagePicker = true }
                            Button("Files") { showFilePicker = true }
                            Button("Cancel", role: .cancel) {}
                        }
                        .photosPicker(isPresented: $showImagePicker, selection: $photosItem, matching: .images)
                        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .image]) { result in
                            guard let url = try? result.get() else { return }
                            guard url.startAccessingSecurityScopedResource() else { return }
                            defer { url.stopAccessingSecurityScopedResource() }
                            guard let data = try? Data(contentsOf: url) else { return }
                            pickedData = data
                            pickedFileName = url.lastPathComponent
                            pickedContentType = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/jpeg"
                        }
                        .onChange(of: photosItem) { _, item in
                            guard let item else { return }
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        pickedData = data
                                        pickedFileName = "receipt-\(Int(Date().timeIntervalSince1970)).jpg"
                                        pickedContentType = "image/jpeg"
                                    }
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                Button {
                    onConfirm(finalAmount, pickedData, pickedFileName, pickedContentType)
                    dismiss()
                } label: {
                    Text(tr("detail.purchase_sheet.title")).primaryActionLabel(tint: Tokens.purchased)
                }
                .buttonStyle(.plain)
                .disabled(finalAmount <= 0)
                .opacity(finalAmount > 0 ? 1 : 0.5)
            }
        )
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
        SheetScaffold(
            scrolls: false,
            header: {
                SheetHeader(
                    title: tr("detail.reject_sheet.title"),
                    subtitle: tr("detail.reject_sheet.subtitle"),
                    onClose: { dismiss() }
                )
            },
            content: {
                TextField(tr("detail.reject_sheet.reason_placeholder"), text: $reason, axis: .vertical)
                    .font(.system(size: 14))
                    .lineLimit(3, reservesSpace: true)
                    .padding(14)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
            },
            footer: {
                Button {
                    onReject(trimmedReason)
                    dismiss()
                } label: {
                    Text(tr("sheet.reject.title")).primaryActionLabel(tint: Tokens.rejected)
                }
                .buttonStyle(.plain)
                .disabled(trimmedReason.isEmpty)
                .opacity(trimmedReason.isEmpty ? 0.5 : 1)
            }
        )
    }

    private var trimmedReason: String {
        reason.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: – Reimbursement sheet (manager/financier)

struct MarkAsPaidSheet: View {
    var onConfirm: (PaymentMethod, Data?, String?, String?) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedMethod: PaymentMethod? = nil
    @State private var pickedData: Data? = nil
    @State private var pickedFileName: String? = nil
    @State private var pickedContentType: String? = nil
    @State private var photosItem: PhotosPickerItem? = nil
    @State private var showPickerOptions = false
    @State private var showImagePicker = false
    @State private var showFilePicker = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        SheetScaffold(
            header: { SheetHeader(title: tr("detail.paid_sheet.title"), onClose: { dismiss() }) },
            content: {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("detail.paid_sheet.method"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(PaymentMethod.allCases, id: \.self) { method in
                                methodTile(method)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text(tr("detail.paid_sheet.receipt"))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Button {
                            if pickedFileName != nil {
                                pickedData = nil; pickedFileName = nil; pickedContentType = nil; photosItem = nil
                            } else {
                                showPickerOptions = true
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: pickedFileName != nil ? "doc.fill" : "paperclip")
                                    .font(.system(size: 16))
                                    .foregroundStyle(pickedFileName != nil ? Tokens.reimbursed : .secondary)
                                Text(pickedFileName ?? "Attach receipt (optional)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(pickedFileName != nil ? Color.primary : .secondary)
                                    .lineLimit(1)
                                Spacer()
                                if pickedFileName != nil {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(14)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(
                                pickedFileName != nil ? Tokens.reimbursed.opacity(0.4) : Color.white.opacity(0.4),
                                lineWidth: 0.5
                            ))
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Add Receipt", isPresented: $showPickerOptions, titleVisibility: .visible) {
                            Button("Photo Library") { showImagePicker = true }
                            Button("Files") { showFilePicker = true }
                            Button("Cancel", role: .cancel) {}
                        }
                        .photosPicker(isPresented: $showImagePicker, selection: $photosItem, matching: .images)
                        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.pdf, .image]) { result in
                            guard let url = try? result.get() else { return }
                            guard url.startAccessingSecurityScopedResource() else { return }
                            defer { url.stopAccessingSecurityScopedResource() }
                            guard let data = try? Data(contentsOf: url) else { return }
                            pickedData = data
                            pickedFileName = url.lastPathComponent
                            pickedContentType = url.pathExtension.lowercased() == "pdf" ? "application/pdf" : "image/jpeg"
                        }
                        .onChange(of: photosItem) { _, item in
                            guard let item else { return }
                            Task {
                                if let data = try? await item.loadTransferable(type: Data.self) {
                                    await MainActor.run {
                                        pickedData = data
                                        pickedFileName = "receipt-\(Int(Date().timeIntervalSince1970)).jpg"
                                        pickedContentType = "image/jpeg"
                                    }
                                }
                            }
                        }
                    }
                }
            },
            footer: {
                Button {
                    guard let method = selectedMethod else { return }
                    onConfirm(method, pickedData, pickedFileName, pickedContentType)
                    dismiss()
                } label: {
                    Text(selectedMethod == nil ? "Select a payment method" : "Confirm Reimbursement")
                        .primaryActionLabel(tint: selectedMethod != nil ? Tokens.reimbursed : Tokens.slate300)
                }
                .buttonStyle(.plain)
                .disabled(selectedMethod == nil)
            }
        )
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
