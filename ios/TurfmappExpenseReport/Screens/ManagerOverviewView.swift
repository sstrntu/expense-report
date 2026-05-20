import SwiftUI

struct ManagerOverviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onGoToReview: () -> Void
    var onContinueDraft: () -> Void = {}

    private var workspaceCurrency: String { repositoryApp.aggregationCurrency }

    private var pendingTotal: Double {
        repositoryApp.managerQueue
            .filter { $0.amount.currency == workspaceCurrency }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }
    private var financeTotal: Double {
        repositoryApp.financeQueue
            .filter { $0.amount.currency == workspaceCurrency }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    private static let spendStatuses: Set<ExpenseWorkflowStatus> =
        [.approved, .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement, .reimbursed]

    private func spend(in dateInterval: DateInterval) -> Double {
        repositoryApp.expenses
            .filter { $0.amount.currency == workspaceCurrency }
            .filter { Self.spendStatuses.contains($0.status) }
            .filter { dateInterval.contains($0.submittedAt ?? $0.createdAt) }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    private var teamSpendMTD: Double {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: Date()) else { return 0 }
        return spend(in: interval)
    }

    /// Month-over-month delta, or nil when there is no prior-month baseline.
    private var spendDeltaVsLastMonth: Double? {
        let cal = Calendar.current
        guard let thisMonth = cal.dateInterval(of: .month, for: Date()),
              let lastMonthDate = cal.date(byAdding: .month, value: -1, to: thisMonth.start),
              let lastMonth = cal.dateInterval(of: .month, for: lastMonthDate) else { return nil }
        let prior = spend(in: lastMonth)
        guard prior > 0 else { return nil }
        return (teamSpendMTD - prior) / prior * 100
    }

    private var spendDeltaDescription: String {
        guard let delta = spendDeltaVsLastMonth else { return "No prior month" }
        return String(format: "%+.0f%% vs LM", delta)
    }

    private var overdueApprovalCount: Int {
        let cutoff = Date().addingTimeInterval(-24 * 60 * 60)
        return repositoryApp.managerQueue.filter { ($0.submittedAt ?? $0.createdAt) < cutoff }.count
    }

    private var activeProjects: [DomainProject] {
        repositoryApp.projects.filter { !$0.isArchived }
    }

    var body: some View {
        let pendingCount = repositoryApp.managerQueue.count
        let financeCount = repositoryApp.financeQueue.count

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.role == .admin ? "Admin view" : app.role == .finance ? "Finance view" : "Manager view")
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("Overview").font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4).padding(.top, 4)

            GlassCard(padding: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AWAITING YOUR APPROVAL")
                                .font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                            Text("\(pendingCount)")
                                .font(.system(size: 36, weight: .bold))
                            Text("\(money(pendingTotal, currency: workspaceCurrency)) total")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if overdueApprovalCount > 0 {
                            StatusPill(text: "\(overdueApprovalCount) over 24h", tint: Tokens.pending, leadingIcon: "clock")
                        }
                    }
                    Button(action: onGoToReview) {
                        Text("Open review queue").primaryActionLabel()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }

            if !repositoryApp.draftExpenses.isEmpty {
                Button(action: onContinueDraft) {
                    GlassCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.clock")
                                .foregroundStyle(Tokens.pending)
                                .frame(width: 32, height: 32)
                                .background(Tokens.pending.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(repositoryApp.draftExpenses.count) draft\(repositoryApp.draftExpenses.count == 1 ? "" : "s")")
                                    .font(.system(size: 13.5, weight: .semibold))
                                    .foregroundStyle(Color.primary)
                                Text("Tap to continue editing.")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                kpiCard(label: "FINANCE QUEUE", value: "\(financeCount)", delta: money(financeTotal, currency: workspaceCurrency), positive: true)
                kpiCard(
                    label: "TEAM SPEND MTD",
                    value: money(teamSpendMTD, currency: workspaceCurrency),
                    delta: spendDeltaDescription,
                    positive: (spendDeltaVsLastMonth ?? 0) >= 0
                )
            }

            if repositoryApp.convertedForeignExpenseCount > 0 || repositoryApp.unconvertibleExpenseCount > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    if repositoryApp.convertedForeignExpenseCount > 0 {
                        Text("\(repositoryApp.convertedForeignExpenseCount) expense(s) converted to \(workspaceCurrency) at approximate rates.")
                    }
                    if repositoryApp.unconvertibleExpenseCount > 0 {
                        Text("\(repositoryApp.unconvertibleExpenseCount) expense(s) excluded — currency not supported.")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
            }

            Text("Project budgets")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 4).padding(.top, 6)

            GlassCard(padding: 14) {
                if activeProjects.isEmpty {
                    Text("No projects yet. Create one in You ▸ Manage projects.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                } else {
                    VStack(spacing: 14) {
                        ForEach(activeProjects) { p in
                            DomainProjectRow(project: p, expenses: repositoryApp.expenses)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    private func kpiCard(label: String, value: String, delta: String, positive: Bool) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 10.5, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
                Text(value).font(.system(size: 22, weight: .bold))
                Text(delta).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(positive ? Tokens.approved : Tokens.rejected)
            }
        }
    }
}
