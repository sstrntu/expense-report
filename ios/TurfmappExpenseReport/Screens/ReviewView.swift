import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var app: AppState
    var onOpen: (Expense) -> Void

    private var pending: [Expense] { app.currentExpenses.filter { $0.status == .pending } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Review").font(.system(size: 26, weight: .bold))
                Text("\(pending.count) expense\(pending.count == 1 ? "" : "s") awaiting approval")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4).padding(.top, 4)

            if pending.count > 1 {
                Button {
                    pending.forEach { app.updateStatus(id: $0.id, to: .approved) }
                } label: {
                    Label("Approve all visible", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(14)
                        .background(Tokens.approved, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            if pending.isEmpty {
                GlassCard(padding: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle").font(.system(size: 28)).foregroundStyle(Tokens.approved)
                        Text("All caught up").font(.system(size: 14, weight: .semibold))
                        Text("No expenses pending approval").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(pending.enumerated()), id: \.element.id) { idx, e in
                            if idx > 0 { Divider().opacity(0.4) }
                            Button { onOpen(e) } label: {
                                HStack(spacing: 12) {
                                    Text(e.icon)
                                        .font(.system(size: 18))
                                        .frame(width: 40, height: 40)
                                        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(e.merchant).font(.system(size: 13.5, weight: .semibold))
                                        Text("\(e.category) · \(e.date)")
                                            .font(.system(size: 11.5)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(money(e.amount)).font(.system(size: 14, weight: .bold))
                                        Text(e.project).font(.system(size: 10.5)).foregroundStyle(.tertiary)
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }
}
