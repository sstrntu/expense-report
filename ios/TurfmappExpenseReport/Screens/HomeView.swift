import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @Binding var selectedTab: TabID
    /// Tapping a draft row hands its id up to RootShell, which stashes it and
    /// switches to the Add tab. SubmitView then opens with that draft loaded.
    var onOpenDraft: (String) -> Void = { _ in }
    var onOpen: (DomainExpense) -> Void

    private var workspaceCurrency: String { repositoryApp.aggregationCurrency }

    private var expensesInCurrency: [DomainExpense] {
        repositoryApp.expensesInDefaultCurrency
    }

    private var rejected: Double {
        expensesInCurrency
            .filter { $0.status == .rejected }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    /// Monthly reimbursable totals for the last 6 months, oldest first.
    private var monthlySeries: [Double] {
        let cal = Calendar.current
        let now = Date()
        return (0..<6).reversed().map { offset in
            guard let date = cal.date(byAdding: .month, value: -offset, to: now),
                  let interval = cal.dateInterval(of: .month, for: date) else { return 0 }
            return expensesInCurrency
                .filter { [.approved, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains($0.status) }
                .filter { interval.contains($0.submittedAt ?? $0.createdAt) }
                .reduce(0) { $0 + $1.amount.decimalValue }
        }
    }

    private var greeting: String {
        let name = app.userName.split(separator: " ").first.map(String.init) ?? ""
        return name.isEmpty ? tr("home.greeting.welcome") : tr("home.greeting.hello", name)
    }

    var body: some View {
        let pending = expensesInCurrency
            .filter { $0.status == .pendingManagerApproval }
            .reduce(0) { $0 + $1.amount.decimalValue }
        let approved = expensesInCurrency
            .filter { $0.status == .approved || $0.status == .readyForReimbursement || $0.status == .pendingFinanceReview }
            .reduce(0) { $0 + $1.amount.decimalValue }

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text(tr("home.this_month")).font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            heroCard(pending: pending, approved: approved)

            scanReceiptButton

            draftsCard

            sectionHeader(title: tr("home.recent"), action: tr("home.see_all")) { selectedTab = .activity }
            recentList

            Text(tr("overview.project_budgets"))
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 4).padding(.top, 6)
            projectsCard
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
    }

    private func heroCard(pending: Double, approved: Double) -> some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("home.reimbursable")).font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                        Text(money(pending + approved, currency: workspaceCurrency)).font(.system(size: 36, weight: .bold)).tracking(-1)
                    }
                    Spacer()
                }

                if monthlySeries.contains(where: { $0 > 0 }) {
                    Sparkline(data: monthlySeries)
                        .frame(height: 50)
                }

                HStack {
                    miniStat(tr("home.stat.pending"),  money(pending, currency: workspaceCurrency))
                    Spacer()
                    miniStat(tr("home.stat.approved"), money(approved, currency: workspaceCurrency))
                    Spacer()
                    miniStat(tr("home.stat.rejected"), money(rejected, currency: workspaceCurrency))
                }
            }
        }
    }

    /// Inline drafts panel: replaces the old "X drafts" stub card with a
    /// per-row picker, so the user can see what each draft is *about* and
    /// pick one directly. Tap → SubmitView opens with that draft loaded.
    @ViewBuilder
    private var draftsCard: some View {
        let drafts = repositoryApp.draftExpenses
        if !drafts.isEmpty {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(tr(drafts.count == 1 ? "home.drafts.count" : "home.drafts.count.plural", drafts.count))
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(tr("home.drafts.continue"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)

                    ForEach(Array(drafts.prefix(3).enumerated()), id: \.element.id) { idx, draft in
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

    private var scanReceiptButton: some View {
        Button { selectedTab = .add } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Tokens.slate500)
                    Image(systemName: "plus").foregroundStyle(.white).font(.system(size: 16, weight: .bold))
                }.frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text(tr("home.new_expense")).font(.system(size: 14, weight: .semibold))
                    Text(tr("home.new_expense.subtitle"))
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .glassSurface(corner: 18)
    }

    private var recentList: some View {
        GlassCard(padding: 0) {
                VStack(spacing: 0) {
                ForEach(Array(repositoryApp.expenses.prefix(4).enumerated()), id: \.element.id) { idx, e in
                    if idx > 0 { Divider().opacity(0.4) }
                    Button { onOpen(e) } label: { DomainExpenseRow(expense: e, projects: repositoryApp.projects, categories: repositoryApp.categories) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var projectsCard: some View {
        GlassCard(padding: 14) {
            VStack(spacing: 14) {
                ForEach(repositoryApp.projects.prefix(3)) { p in
                    DomainProjectRow(project: p, expenses: repositoryApp.expenses)
                }
            }
        }
    }

    private func sectionHeader(title: String, action: String, onTap: @escaping () -> Void) -> some View {
        HStack {
            Text(title).font(.system(size: 13, weight: .semibold))
            Spacer()
            Button(action, action: onTap)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4).padding(.top, 6)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 17, weight: .semibold))
        }
    }
}

struct ExpenseRow: View {
    let expense: Expense
    var body: some View {
        HStack(spacing: 12) {
            Text(expense.icon).font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(expense.merchant).font(.system(size: 13.5, weight: .semibold))
                Text("\(expense.category) · \(expense.date)")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(money(expense.amount)).font(.system(size: 13.5, weight: .semibold))
                StatusPill(status: expense.status)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct DomainExpenseRow: View {
    let expense: DomainExpense
    let projects: [DomainProject]
    var categories: [DomainCategory] = []

    private var categoryName: String {
        categories.first { $0.id == expense.categoryId }?.name ?? expense.categoryLabel
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(expense.icon).font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(expense.merchant).font(.system(size: 13.5, weight: .semibold))
                Text("\(categoryName) · \(expense.displayDate)")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                // When the receipt was in a foreign currency, the headline is
                // the snapshotted base-currency amount so it lines up with the
                // dashboard totals; the original native amount lives below in
                // a small "↻" tag so the user can still see what they paid.
                Text((expense.amountInBase ?? expense.amount).formatted)
                    .font(.system(size: 13.5, weight: .semibold))
                if expense.isConverted {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .semibold))
                        Text(expense.amount.formatted).font(.system(size: 10.5))
                    }
                    .foregroundStyle(.tertiary)
                }
                StatusPill(text: expense.status.displayLabel, tint: expense.status.tint, leadingIcon: expense.status.icon)
                if let owner = expense.status.nextOwnerLabel {
                    StatusPill(text: owner, tint: Tokens.slate500, leadingIcon: expense.status.nextOwnerIcon)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct ProjectRow: View {
    let project: Project
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(project.name).font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text("$\(Int(project.spent / 1000))k / $\(Int(project.budget / 1000))k")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            ProgressView(value: project.progress)
                .progressViewStyle(.linear)
                .tint(project.color)
        }
    }
}

struct DomainProjectRow: View {
    let project: DomainProject
    let expenses: [DomainExpense]

    private static let paidStatuses: Set<ExpenseWorkflowStatus> = [.reimbursed]
    private static let pendingStatuses: Set<ExpenseWorkflowStatus> = [
        .submitted, .pendingManagerApproval, .approved,
        .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement
    ]

    /// All expenses for this project, regardless of native currency. Foreign
    /// expenses get rolled in via their `amountInBase` snapshot — the rate
    /// was captured at submit time, so the budget consumption is exact and
    /// reproducible. Expenses with no snapshot AND a non-matching native
    /// currency are skipped (legacy rows pending backfill).
    private var projectExpenses: [DomainExpense] {
        expenses.filter { $0.projectId == project.id }
    }

    /// Returns the contribution of this expense to the project's budget. Same
    /// currency as the budget; nil when we can't project the amount into the
    /// project base (no snapshot + foreign currency).
    private func budgetAmount(of expense: DomainExpense) -> Double? {
        let base = project.budget.currency
        if expense.amount.currency == base { return expense.amount.decimalValue }
        if let inBase = expense.amountInBase, inBase.currency == base { return inBase.decimalValue }
        return nil
    }

    private var paid: Double {
        projectExpenses
            .filter { Self.paidStatuses.contains($0.status) }
            .compactMap(budgetAmount(of:))
            .reduce(0, +)
    }

    private var pending: Double {
        projectExpenses
            .filter { Self.pendingStatuses.contains($0.status) }
            .compactMap(budgetAmount(of:))
            .reduce(0, +)
    }

    private var committed: Double { paid + pending }

    private var budget: Double { project.budget.decimalValue }

    private var isOverBudget: Bool { committed > budget && budget > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(project.name).font(.system(size: 12.5, weight: .medium))
                if isOverBudget {
                    StatusPill(text: tr("overview.budget.over"), tint: Tokens.rejected, leadingIcon: "exclamationmark.triangle.fill")
                }
                Spacer()
                Text("\(MoneyAmount.format(amount: committed, currency: project.budget.currency)) / \(project.budget.formatted)")
                    .font(.system(size: 11.5))
                    .foregroundStyle(isOverBudget ? Tokens.rejected : .secondary)
            }

            // Two-segment progress bar: paid (solid) + pending (lighter). Both clip to the
            // bar width; an extra "over" red tail shows whenever committed > budget.
            GeometryReader { proxy in
                let width = proxy.size.width
                let cap = max(budget, committed)
                let paidW   = cap > 0 ? CGFloat(paid / cap) * width : 0
                let pendW   = cap > 0 ? CGFloat(pending / cap) * width : 0
                let budgetX = cap > 0 ? CGFloat(budget / cap) * width : width

                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    HStack(spacing: 0) {
                        Capsule().fill(Tokens.slate500).frame(width: paidW)
                        Capsule().fill(Tokens.purchased.opacity(0.7)).frame(width: pendW)
                    }
                    .clipShape(Capsule())
                    if isOverBudget {
                        Rectangle()
                            .fill(Tokens.rejected.opacity(0.8))
                            .frame(width: 1.5)
                            .offset(x: budgetX - 0.75)
                    }
                }
                .frame(height: 6)
            }
            .frame(height: 6)

            if pending > 0 || isOverBudget {
                HStack(spacing: 10) {
                    breakdownChip(label: tr("overview.budget.paid"), value: paid, tint: Tokens.slate500)
                    breakdownChip(label: tr("overview.budget.pending"), value: pending, tint: Tokens.purchased)
                    Spacer()
                }
            }
        }
    }

    private func breakdownChip(label: String, value: Double, tint: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 6, height: 6)
            Text("\(label) \(MoneyAmount.format(amount: value, currency: project.budget.currency))")
                .font(.system(size: 10.5)).foregroundStyle(.secondary)
        }
    }
}

/// Render an amount in the given ISO currency code (default USD). Use this
/// only when you already know all the inputs share one currency.
func money(_ v: Double, currency: String = "USD") -> String {
    MoneyAmount.format(amount: v, currency: currency)
}
