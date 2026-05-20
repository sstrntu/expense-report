import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @Binding var selectedTab: TabID
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
        return name.isEmpty ? "Welcome back" : "Hello, \(name)"
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
                Text("This month").font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            heroCard(pending: pending, approved: approved)

            scanReceiptButton

            if !repositoryApp.draftExpenses.isEmpty {
                Button { selectedTab = .add } label: {
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

            sectionHeader(title: "Recent activity", action: "See all") { selectedTab = .activity }
            recentList

            Text("Project budgets")
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
                        Text("REIMBURSABLE").font(.system(size: 11, weight: .semibold)).tracking(0.6).foregroundStyle(.secondary)
                        Text(money(pending + approved, currency: workspaceCurrency)).font(.system(size: 36, weight: .bold)).tracking(-1)
                    }
                    Spacer()
                }

                if monthlySeries.contains(where: { $0 > 0 }) {
                    Sparkline(data: monthlySeries)
                        .frame(height: 50)
                }

                HStack {
                    miniStat("Pending",  money(pending, currency: workspaceCurrency))
                    Spacer()
                    miniStat("Approved", money(approved, currency: workspaceCurrency))
                    Spacer()
                    miniStat("Rejected", money(rejected, currency: workspaceCurrency))
                }
            }
        }
    }

    private var scanReceiptButton: some View {
        Button { selectedTab = .add } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(Tokens.slate500)
                    Image(systemName: "plus").foregroundStyle(.white).font(.system(size: 16, weight: .bold))
                }.frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text("New Expense").font(.system(size: 14, weight: .semibold))
                    Text("Submit before making the purchase")
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
                    Button { onOpen(e) } label: { DomainExpenseRow(expense: e, projects: repositoryApp.projects) }
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

    var body: some View {
        HStack(spacing: 12) {
            Text(expense.icon).font(.system(size: 18))
                .frame(width: 36, height: 36)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 1) {
                Text(expense.merchant).font(.system(size: 13.5, weight: .semibold))
                Text("\(expense.categoryLabel) · \(expense.displayDate)")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(expense.amount.formatted).font(.system(size: 13.5, weight: .semibold))
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

    /// Only count expenses that share the project's currency. No conversion.
    private var spent: Double {
        expenses
            .filter { $0.projectId == project.id
                      && $0.amount.currency == project.budget.currency
                      && [.approved, .pendingFinanceReview, .readyForReimbursement, .reimbursed].contains($0.status) }
            .reduce(0) { $0 + $1.amount.decimalValue }
    }

    private var progress: Double {
        min(spent / max(project.budget.decimalValue, 1), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(project.name).font(.system(size: 12.5, weight: .medium))
                Spacer()
                Text("\(MoneyAmount.format(amount: spent, currency: project.budget.currency)) / \(project.budget.formatted)")
                    .font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(Tokens.slate500)
        }
    }
}

/// Render an amount in the given ISO currency code (default USD). Use this
/// only when you already know all the inputs share one currency.
func money(_ v: Double, currency: String = "USD") -> String {
    MoneyAmount.format(amount: v, currency: currency)
}
