import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var drilldown: DashboardDrilldown? = nil
    var onOpen: (DomainExpense) -> Void = { _ in }

    private var workspaceCurrency: String { repositoryApp.aggregationCurrency }
    private var expensesInCurrency: [DomainExpense] { repositoryApp.expensesInDefaultCurrency }

    /// Active-but-not-yet-paid expenses (everything in the pipeline except actually reimbursed,
    /// drafts, cancelled, rejected, archived, or failed scans). These count toward total
    /// commitment but the cash hasn't gone out yet.
    private var projectedExpenses: [DomainExpense] {
        expensesInCurrency.filter { Self.projectedStatuses.contains($0.status) }
    }

    private var confirmedExpenses: [DomainExpense] {
        expensesInCurrency.filter { $0.status == .reimbursed }
    }

    private static let projectedStatuses: Set<ExpenseWorkflowStatus> = [
        .submitted, .pendingManagerApproval, .approved,
        .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement
    ]

    private var cats: [DonutChart.Segment] {
        let totals = Dictionary(grouping: expensesInCurrency, by: { repositoryApp.categoryName(forId: $0.categoryId) })
            .mapValues { $0.reduce(0) { $0 + $1.amount.decimalValue } }

        return totals
            .sorted { $0.value > $1.value }
            .map { category, value in
                DonutChart.Segment(value: value, color: categoryColor(category), label: category)
            }
    }

    /// Ordered list of category names that have any activity, used both to
    /// build the stacked-bar segments and to draw a consistent legend below
    /// the chart. Sorted by total spend so the dominant category sits on
    /// the bottom of each stack.
    private var monthlyCategoryOrder: [String] {
        Dictionary(grouping: expensesInCurrency, by: { repositoryApp.categoryName(forId: $0.categoryId) })
            .mapValues { $0.reduce(0) { $0 + $1.amount.decimalValue } }
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    private var months: [BarsChart.Bar] {
        let calendar = Calendar.current
        let now = Date()
        let categoryOrder = monthlyCategoryOrder

        return (0..<6).reversed().map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            let components = calendar.dateComponents([.year, .month], from: date)

            func isInMonth(_ expense: DomainExpense) -> Bool {
                let expenseDate = expense.purchaseDate ?? expense.submittedAt ?? expense.createdAt
                let c = calendar.dateComponents([.year, .month], from: expenseDate)
                return c.year == components.year && c.month == components.month
            }

            // One stacked segment per category that had any spend this month.
            // Categories without spend in this month are skipped — keeps the
            // bar tight rather than padding with zero-height slivers.
            let monthExpenses = expensesInCurrency.filter(isInMonth)
            let segments: [BarsChart.Segment] = categoryOrder.compactMap { category in
                let total = monthExpenses
                    .filter { repositoryApp.categoryName(forId: $0.categoryId) == category }
                    .reduce(0) { $0 + $1.amount.decimalValue }
                guard total > 0 else { return nil }
                return BarsChart.Segment(value: total, color: categoryColor(category))
            }

            let label = DateFormatter().shortMonthSymbols[max((components.month ?? 1) - 1, 0)]
            return BarsChart.Bar(label: label, segments: segments)
        }
    }

    private var merchants: [(String, Double, Int)] {
        Dictionary(grouping: expensesInCurrency, by: \.merchant)
            .map { merchant, expenses in
                (merchant, expenses.reduce(0) { $0 + $1.amount.decimalValue }, expenses.count)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        let segments = cats
        let total = segments.reduce(0) { $0 + $1.value }
        let confirmed = confirmedExpenses.reduce(0) { $0 + $1.amount.decimalValue }
        let projected = projectedExpenses.reduce(0) { $0 + $1.amount.decimalValue }
        let monthValues = months.map(\.value)
        let spendDelta: String = {
            guard monthValues.count >= 2 else { return "—" }
            let prev = monthValues[monthValues.count - 2]
            let curr = monthValues[monthValues.count - 1]
            guard prev > 0 else { return curr > 0 ? "New" : "—" }
            return String(format: "%+.1f%%", (curr - prev) / prev * 100)
        }()

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("All activity").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("Analytics").font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4).padding(.top, 4)

            spendBreakdownCard(paid: confirmed, pending: projected)

            categoryCard(segments: segments, total: total)

            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Monthly spend").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        StatusPill(text: "6 mo", tint: Tokens.slate500)
                    }
                    BarsChart(bars: months)
                    // Wrap to multiple lines when the workspace has many categories.
                    FlowingLegend(items: monthlyCategoryOrder.map { (categoryColor($0), $0) })
                }
            }

            merchantsCard

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
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(item: $drilldown) { item in
            DashboardDrilldownSheet(item: item, onOpen: onOpen)
                .presentationDetents([.medium])
        }
    }

    /// Single-card three-column breakdown: paid + pending + total. Replaces
    /// the old two-card row so users see the cash split without doing the
    /// arithmetic in their head.
    private func spendBreakdownCard(paid: Double, pending: Double) -> some View {
        GlassCard(padding: 16) {
            HStack(alignment: .top, spacing: 0) {
                breakdownColumn(
                    label: "PAID",
                    value: money(paid, currency: workspaceCurrency),
                    accent: Tokens.slate500
                )
                Divider().frame(height: 38).padding(.horizontal, 8).opacity(0.4)
                breakdownColumn(
                    label: "PENDING",
                    value: money(pending, currency: workspaceCurrency),
                    accent: Tokens.purchased
                )
                Divider().frame(height: 38).padding(.horizontal, 8).opacity(0.4)
                breakdownColumn(
                    label: "TOTAL",
                    value: money(paid + pending, currency: workspaceCurrency),
                    accent: Color.primary
                )
            }
        }
    }

    private func breakdownColumn(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 6, height: 6)
                Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
            }
            Text(value).font(.system(size: 18, weight: .bold)).tracking(-0.4)
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 8, height: 8)
            Text(label).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.secondary)
        }
    }

    private func kpiCard(label: String, value: String, delta: String, positive: Bool) -> some View {
        GlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 10.5, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
                Text(value).font(.system(size: 22, weight: .bold)).tracking(-0.5)
                Text(delta).font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(positive ? Tokens.approved : Tokens.rejected)
            }
        }
    }

    private func categoryCard(segments: [DonutChart.Segment], total: Double) -> some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("By category").font(.system(size: 13, weight: .semibold))
                HStack(spacing: 18) {
                    ZStack {
                        DonutChart(segments: segments).frame(width: 132, height: 132)
                        VStack(spacing: 1) {
                            Text("TOTAL").font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
                            Text(money(total, currency: workspaceCurrency)).font(.system(size: 18, weight: .bold))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(segments, id: \.self) { c in
                            Button {
                                drilldown = DashboardDrilldown(
                                    title: c.label,
                                    subtitle: "Category drilldown",
                                    expenses: repositoryApp.expenses.filter { repositoryApp.categoryName(forId: $0.categoryId) == c.label },
                                    projects: repositoryApp.projects,
                                    categories: repositoryApp.categories
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 2).fill(c.color).frame(width: 8, height: 8)
                                    Text(c.label).font(.system(size: 11.5))
                                    Spacer()
                                    Text("\(Int((c.value / max(total, 1)) * 100))%")
                                        .font(.system(size: 11.5, weight: .medium))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var merchantsCard: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                Text("Top merchants").font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
                ForEach(Array(merchants.enumerated()), id: \.offset) { idx, m in
                    Divider().opacity(0.4)
                    Button {
                        drilldown = DashboardDrilldown(
                            title: m.0,
                            subtitle: "Merchant drilldown",
                            expenses: repositoryApp.expenses.filter { $0.merchant == m.0 },
                            projects: repositoryApp.projects,
                            categories: repositoryApp.categories
                        )
                    } label: {
                        HStack(spacing: 12) {
                            Text("\(idx + 1)")
                                .font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(m.0).font(.system(size: 13, weight: .semibold))
                                Text("\(m.2) transactions").font(.system(size: 11)).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(money(m.1, currency: workspaceCurrency)).font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Travel":   return Tokens.slate500
        case "Meals":    return Tokens.aiPurple
        case "Software": return Tokens.approved
        case "Office":   return Tokens.pending
        default:         return Color(hex: 0x6B7185)
        }
    }
}

struct DashboardDrilldown: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let expenses: [DomainExpense]
    let projects: [DomainProject]
    var categories: [DomainCategory] = []
}

struct DashboardDrilldownSheet: View {
    let item: DashboardDrilldown
    var onOpen: (DomainExpense) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title).font(.system(size: 20, weight: .bold))
                    Text(item.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(item.expenses.enumerated()), id: \.element.id) { idx, expense in
                    if idx > 0 { Divider().opacity(0.4) }
                    Button {
                        dismiss()
                        onOpen(expense)
                    } label: {
                        DomainExpenseRow(expense: expense, projects: item.projects, categories: item.categories)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}

/// Wrapping legend — uses an iOS 16+ `Layout` via `WrappingHStack` semantics
/// implemented with a `ViewThatFits`/`FlexibleView` substitute. For the
/// modest category counts here a simple `HStack` with `flowLayout` via
/// a `Layout` protocol is overkill; a wrap helper using `Group` + manual
/// row breaks gives readable output without pulling in extra dependencies.
struct FlowingLegend: View {
    let items: [(Color, String)]

    var body: some View {
        // Up to 3 dots per row keeps each label readable on narrow phones.
        let chunks = items.chunked(into: 3)
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 14) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 2).fill(entry.0).frame(width: 8, height: 8)
                            Text(entry.1).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { Array(self[$0..<Swift.min($0 + size, count)]) }
    }
}
