import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onOpen: (DomainExpense) -> Void

    private var pending: [DomainExpense] {
        app.role.canApproveExpenses ? repositoryApp.managerQueue : []
    }

    private var financeQueue: [DomainExpense] {
        app.role.canReimburseExpenses ? repositoryApp.financeQueue : []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Review").font(.system(size: 26, weight: .bold))
                Text("\(pending.count) approval\(pending.count == 1 ? "" : "s") · \(financeQueue.count) reimbursement\(financeQueue.count == 1 ? "" : "s")")
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4).padding(.top, 4)

            if app.role.canApproveExpenses && pending.count > 1 {
                Button {
                    Task {
                        for item in pending {
                            await repositoryApp.approveExpense(id: item.id)
                        }
                    }
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

            if pending.isEmpty && financeQueue.isEmpty {
                GlassCard(padding: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle").font(.system(size: 28)).foregroundStyle(Tokens.approved)
                        Text("All caught up").font(.system(size: 14, weight: .semibold))
                        Text("No approvals or reimbursements waiting").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                if !pending.isEmpty {
                    queueSection(title: "Manager approval", items: pending, tint: Tokens.pending)
                }
                if !financeQueue.isEmpty {
                    queueSection(title: "Finance reimbursement", items: financeQueue, tint: Tokens.reimbursed)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    private func queueSection(title: String, items: [DomainExpense], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                    .foregroundStyle(.tertiary)
                Spacer()
                StatusPill(text: "\(items.count)", tint: tint)
            }
            .padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, e in
                        if idx > 0 { Divider().opacity(0.4) }
                        Button { onOpen(e) } label: {
                            HStack(spacing: 12) {
                                Text(e.icon)
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(e.merchant).font(.system(size: 13.5, weight: .semibold))
                                    Text("\(e.categoryLabel) · \(e.displayDate)")
                                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(e.amount.formatted).font(.system(size: 14, weight: .bold))
                                    Text(e.projectName(in: repositoryApp.projects)).font(.system(size: 10.5)).foregroundStyle(.tertiary)
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
}
