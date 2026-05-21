import SwiftUI

struct ManagerOverviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onGoToReview: () -> Void
    /// Tapping a draft row opens SubmitView with that specific draft loaded.
    /// Replaces the old single-tap "continue drafts" stub.
    var onOpenDraft: (String) -> Void = { _ in }

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
        guard let delta = spendDeltaVsLastMonth else { return tr("overview.no_prior_month") }
        return tr("overview.delta.vs_lm", String(format: "%+.0f", delta))
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
                Text(app.role == .admin ? tr("overview.admin_view") : app.role == .finance ? tr("overview.finance_view") : tr("overview.manager_view"))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text(tr("overview.title")).font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4).padding(.top, 4)

            GlassCard(padding: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("overview.awaiting.label"))
                                .font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                            Text("\(pendingCount)")
                                .font(.system(size: 36, weight: .bold))
                            Text(tr("overview.awaiting.total", money(pendingTotal, currency: workspaceCurrency)))
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if overdueApprovalCount > 0 {
                            StatusPill(text: tr("overview.over_24h", overdueApprovalCount), tint: Tokens.pending, leadingIcon: "clock")
                        }
                    }
                    Button(action: onGoToReview) {
                        Text(tr("overview.open_queue")).primaryActionLabel()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }

            draftsCard

            HStack(spacing: 10) {
                kpiCard(label: tr("overview.finance_queue"), value: "\(financeCount)", delta: money(financeTotal, currency: workspaceCurrency), positive: true)
                kpiCard(
                    label: tr("overview.team_spend_mtd"),
                    value: money(teamSpendMTD, currency: workspaceCurrency),
                    delta: spendDeltaDescription,
                    positive: (spendDeltaVsLastMonth ?? 0) >= 0
                )
            }

            if repositoryApp.convertedForeignExpenseCount > 0 || repositoryApp.unconvertibleExpenseCount > 0 {
                VStack(alignment: .leading, spacing: 2) {
                    if repositoryApp.convertedForeignExpenseCount > 0 {
                        Text(tr("dashboard.foreign.converted", repositoryApp.convertedForeignExpenseCount, workspaceCurrency))
                    }
                    if repositoryApp.unconvertibleExpenseCount > 0 {
                        Text(tr("dashboard.foreign.excluded", repositoryApp.unconvertibleExpenseCount))
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
            }

            Text(tr("overview.project_budgets"))
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 4).padding(.top, 6)

            GlassCard(padding: 14) {
                if activeProjects.isEmpty {
                    Text(tr("overview.no_projects"))
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

    /// Inline drafts panel. Same shape as `HomeView.draftsCard` but with
    /// "overview.*" copy keys so the heading reads consistently with the
    /// manager-context strings used elsewhere on this screen.
    @ViewBuilder
    private var draftsCard: some View {
        let drafts = repositoryApp.draftExpenses
        if !drafts.isEmpty {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(tr(drafts.count == 1 ? "overview.drafts.count" : "overview.drafts.count.plural", drafts.count))
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(tr("overview.drafts.continue"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)

                    ForEach(Array(drafts.prefix(3).enumerated()), id: \.element.id) { _, draft in
                        Divider().opacity(0.4)
                        Button { onOpenDraft(draft.id) } label: {
                            draftRow(draft)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func draftRow(_ draft: DomainExpense) -> some View {
        HStack(spacing: 12) {
            Text(draft.icon).font(.system(size: 18))
                .frame(width: 32, height: 32)
                .background(Tokens.pending.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(draft.merchant.isEmpty ? tr("home.drafts.untitled") : draft.merchant)
                    .font(.system(size: 13.5, weight: .semibold))
                Text("\(draft.projectName(in: repositoryApp.projects)) · \(draft.displayDate)")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(draft.amount.minorUnits == 0 ? "—" : draft.amount.formatted)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
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
