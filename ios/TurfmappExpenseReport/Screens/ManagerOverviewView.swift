import SwiftUI

struct ManagerOverviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onGoToReview: () -> Void
    /// Tapping a draft row opens SubmitView with that specific draft loaded.
    /// Replaces the old single-tap "continue drafts" stub.
    var onOpenDraft: (String) -> Void = { _ in }
    /// Opens an expense detail from the pipeline drill-down sheet.
    var onOpenExpense: (DomainExpense) -> Void = { _ in }

    @State private var drilldown: DashboardDrilldown? = nil

    private var workspaceCurrency: String { repositoryApp.aggregationCurrency }

    /// Sum a queue in the workspace currency, using the FX-snapshot
    /// projection so foreign-currency expenses count correctly instead of
    /// being silently dropped.
    private func total(of queue: [DomainExpense]) -> Double {
        let ids = Set(queue.map(\.id))
        return repositoryApp.expensesInDefaultCurrency
            .filter { ids.contains($0.id) }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    // MARK: – Action queues (role-aware)

    /// One row in the "Needs your action" hero. Built from the queues the
    /// current user can actually act on, so a pure Finance user sees their
    /// reimbursement workload front-and-centre instead of an empty manager
    /// approval count, and a multi-hat admin sees both.
    private struct ActionQueue: Identifiable {
        let id: String
        let icon: String
        let label: String
        let items: [DomainExpense]
        let total: Double
        let tint: Color
    }

    private var actionQueues: [ActionQueue] {
        var queues: [ActionQueue] = []
        let approvals = repositoryApp.managerQueue
        let reimbursements = repositoryApp.financeQueue
        if !approvals.isEmpty {
            queues.append(ActionQueue(
                id: "approve",
                icon: "person.badge.shield.checkmark.fill",
                label: tr("review.action.to_approve"),
                items: approvals,
                total: total(of: approvals),
                tint: Tokens.pending
            ))
        }
        if !reimbursements.isEmpty {
            queues.append(ActionQueue(
                id: "reimburse",
                icon: "creditcard.fill",
                label: tr("review.action.to_reimburse"),
                items: reimbursements,
                total: total(of: reimbursements),
                tint: Tokens.reimbursed
            ))
        }
        return queues
    }

    private var actionCount: Int { actionQueues.reduce(0) { $0 + $1.items.count } }
    private var actionTotal: Double { actionQueues.reduce(0) { $0 + $1.total } }

    // MARK: – Pipeline stages (workspace-wide)

    /// A stage of the approval → payment workflow, aggregated across the
    /// whole workspace. Gives reviewers the "where is the money right now"
    /// picture at a glance.
    private struct PipelineStage: Identifiable {
        let id: String
        let label: String
        let items: [DomainExpense]
        let total: Double
        let tint: Color
    }

    private var pipelineStages: [PipelineStage] {
        let converted = repositoryApp.expensesInDefaultCurrency
        let cal = Calendar.current
        let thisMonth = cal.dateInterval(of: .month, for: Date())

        func stage(_ id: String, _ labelKey: String, _ tint: Color,
                   _ matches: (DomainExpense) -> Bool) -> PipelineStage {
            let items = converted.filter { !$0.isArchived && matches($0) }
            return PipelineStage(
                id: id, label: tr(labelKey), items: items,
                total: items.reduce(0) { $0 + $1.amount.decimalValue },
                tint: tint
            )
        }

        return [
            stage("approval", "overview.pipeline.approval", Tokens.pending) {
                [.submitted, .pendingManagerApproval].contains($0.status)
            },
            stage("purchasing", "overview.pipeline.purchasing", Tokens.purchased) {
                [.approved, .purchaseConfirmed].contains($0.status)
            },
            stage("finance", "overview.pipeline.finance", Tokens.reimbursed) {
                [.pendingFinanceReview, .readyForReimbursement].contains($0.status)
            },
            stage("paid", "overview.pipeline.paid_mtd", Tokens.approved) {
                guard $0.status == .reimbursed else { return false }
                let date = $0.purchaseDate ?? $0.submittedAt ?? $0.createdAt
                return thisMonth?.contains(date) ?? false
            },
        ]
    }

    // MARK: – KPIs

    private static let spendStatuses: Set<ExpenseWorkflowStatus> =
        [.approved, .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement, .reimbursed]

    private func spend(in dateInterval: DateInterval) -> Double {
        repositoryApp.expensesInDefaultCurrency
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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(app.role == .admin ? tr("overview.admin_view") : app.role == .finance ? tr("overview.finance_view") : tr("overview.manager_view"))
                    .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text(tr("overview.title")).font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4).padding(.top, 4)

            actionHero

            draftsCard

            pipelineCard

            HStack(spacing: 10) {
                kpiCard(
                    label: tr("overview.paid_mtd"),
                    value: money(pipelineStages.last?.total ?? 0, currency: workspaceCurrency),
                    caption: tr((pipelineStages.last?.items.count ?? 0) == 1 ? "overview.payments.count" : "overview.payments.count.plural",
                                pipelineStages.last?.items.count ?? 0),
                    captionColor: .secondary
                )
                kpiCard(
                    label: tr("overview.team_spend_mtd"),
                    value: money(teamSpendMTD, currency: workspaceCurrency),
                    caption: spendDeltaDescription,
                    captionColor: (spendDeltaVsLastMonth ?? 0) <= 0 ? Tokens.approved : Tokens.pending
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

            Text(tr("overview.project_budgets").uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4).padding(.top, 6)

            GlassCard(padding: Tokens.padDense) {
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
        .sheet(item: $drilldown) { item in
            DashboardDrilldownSheet(item: item, onOpen: onOpenExpense)
                .presentationDetents([.medium, .large])
        }
        // Catch new submissions arriving from team members without forcing
        // the manager to pull-to-refresh. Throttled by refreshIfStale.
        .task {
            await repositoryApp.refreshIfStale()
        }
    }

    // MARK: – Needs your action hero

    /// Role-aware hero: shows exactly the queues this user can act on, each
    /// with its own count + total, and one button into the review tab. A pure
    /// Finance user therefore leads with reimbursements; a manager with
    /// approvals; an admin with both stacked.
    private var actionHero: some View {
        GlassCard(padding: Tokens.padHero) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("overview.action_needed"))
                            .font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                        Text("\(actionCount)")
                            .font(.system(size: 36, weight: .bold))
                            .contentTransition(.numericText())
                        Text(tr("overview.awaiting.total", money(actionTotal, currency: workspaceCurrency)))
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if overdueApprovalCount > 0 {
                        StatusPill(text: tr("overview.over_24h", overdueApprovalCount), tint: Tokens.pending, leadingIcon: "clock")
                    }
                }

                if actionQueues.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Tokens.approved)
                        Text(tr("review.empty.subtitle"))
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                } else {
                    VStack(spacing: 0) {
                        ForEach(actionQueues) { queue in
                            if queue.id != actionQueues.first?.id { Divider().opacity(0.4) }
                            HStack(spacing: 10) {
                                Image(systemName: queue.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(queue.tint)
                                    .frame(width: 28, height: 28)
                                    .background(queue.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                                Text(queue.label)
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                Text("\(queue.items.count)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(queue.tint)
                                Text(money(queue.total, currency: workspaceCurrency))
                                    .font(.system(size: 13, weight: .semibold))
                                    .frame(minWidth: 70, alignment: .trailing)
                            }
                            .padding(.vertical, 8)
                        }
                    }

                    Button(action: onGoToReview) {
                        Text(tr("overview.open_queue")).primaryActionLabel()
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
        .animation(Motion.snappy, value: actionCount)
    }

    // MARK: – Pipeline card

    /// Workspace-wide stage breakdown: a proportional bar plus a tappable
    /// row per stage (count + amount), so the approval → purchase → finance
    /// → paid flow is legible without opening every queue.
    private var pipelineCard: some View {
        let stages = pipelineStages
        let grandTotal = stages.reduce(0) { $0 + $1.total }

        return GlassCard(padding: Tokens.padCard) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(tr("overview.pipeline")).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(money(grandTotal, currency: workspaceCurrency))
                        .font(.system(size: 13, weight: .bold))
                }

                // Proportional stage bar. Stages with no money are skipped;
                // an all-empty pipeline gets a neutral hairline instead.
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        if grandTotal <= 0 {
                            Capsule().fill(Color.primary.opacity(0.06))
                        } else {
                            ForEach(stages.filter { $0.total > 0 }) { stage in
                                Capsule()
                                    .fill(stage.tint)
                                    .frame(width: max(geo.size.width * stage.total / grandTotal - 2, 6))
                            }
                        }
                    }
                }
                .frame(height: 6)
                .animation(Motion.gentle, value: grandTotal)

                VStack(spacing: 0) {
                    ForEach(stages) { stage in
                        if stage.id != stages.first?.id { Divider().opacity(0.4) }
                        Button {
                            guard !stage.items.isEmpty else { return }
                            drilldown = DashboardDrilldown(
                                title: stage.label,
                                subtitle: tr("overview.pipeline.drilldown"),
                                expenses: stage.items,
                                projects: repositoryApp.projects,
                                categories: repositoryApp.categories
                            )
                        } label: {
                            HStack(spacing: 8) {
                                Circle().fill(stage.tint).frame(width: 8, height: 8)
                                Text(stage.label).font(.system(size: 12.5, weight: .medium))
                                Spacer()
                                Text("\(stage.items.count)")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 20, alignment: .trailing)
                                Text(money(stage.total, currency: workspaceCurrency))
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .frame(minWidth: 76, alignment: .trailing)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .opacity(stage.items.isEmpty ? 0.3 : 1)
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.pressableRow)
                        .disabled(stage.items.isEmpty)
                    }
                }
            }
        }
    }

    private var draftsCard: some View {
        DraftsCard(
            drafts: repositoryApp.draftExpenses,
            projects: repositoryApp.projects,
            copyPrefix: "overview.drafts",
            onOpen: onOpenDraft
        )
    }

    private func kpiCard(label: String, value: String, caption: String, captionColor: Color) -> some View {
        GlassCard(padding: Tokens.padDense) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 10.5, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
                Text(value).font(.system(size: 22, weight: .bold))
                    .minimumScaleFactor(0.7).lineLimit(1)
                Text(caption).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(captionColor)
            }
        }
    }
}
