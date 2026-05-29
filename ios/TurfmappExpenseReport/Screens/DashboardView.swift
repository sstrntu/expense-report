import SwiftUI

struct DashboardView: View {
    enum Scope: String, CaseIterable, Hashable { case mine, workspace }

    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var drilldown: DashboardDrilldown? = nil
    @State private var scope: Scope = .workspace
    var onOpen: (DomainExpense) -> Void = { _ in }

    private var workspaceCurrency: String { repositoryApp.aggregationCurrency }

    /// Does the user have any cross-team responsibilities? If not we hide the
    /// scope toggle entirely — their only data is their own. Admin grants both
    /// approve and reimburse so the two-flag check covers it.
    private var canViewWorkspaceScope: Bool {
        app.role.canApproveExpenses || app.role.canReimburseExpenses
    }

    /// `expensesInDefaultCurrency` with an optional submitter filter applied.
    /// "Mine" filters to expenses submitted by the current member; "workspace"
    /// passes everything through. If we can't identify the current member while
    /// in Mine scope, return empty rather than silently falling back to the
    /// workspace set — that's how the two tabs ended up showing identical
    /// numbers in early testing.
    private var expensesInCurrency: [DomainExpense] {
        let all = repositoryApp.expensesInDefaultCurrency
        if scope == .workspace { return all }
        guard let me = repositoryApp.currentMembershipId else { return [] }
        return all.filter { $0.submittedByMembershipId == me }
    }

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

    /// All expenses that count toward analytics — excludes drafts, cancelled, rejected, archived, and failed scans.
    private static let analyticsStatuses: Set<ExpenseWorkflowStatus> = [
        .submitted, .pendingManagerApproval, .approved,
        .purchaseConfirmed, .pendingFinanceReview, .readyForReimbursement, .reimbursed
    ]

    private var analyticsExpenses: [DomainExpense] {
        expensesInCurrency.filter { Self.analyticsStatuses.contains($0.status) }
    }

    private var cats: [DonutChart.Segment] {
        let totals = Dictionary(grouping: analyticsExpenses, by: { repositoryApp.categoryName(forId: $0.categoryId) })
            .mapValues { $0.reduce(0) { $0 + $1.amount.decimalValue } }

        return totals
            .sorted { $0.value > $1.value }
            .map { category, value in
                DonutChart.Segment(value: value, color: categoryColor(category), label: localizeCategory(category))
            }
    }

    /// Map an English-stored seeded category to the user-selected language.
    /// Workspace-custom categories pass through unchanged.
    private func localizeCategory(_ name: String) -> String {
        switch name {
        case "Travel":   return tr("category.travel")
        case "Meals":    return tr("category.meals")
        case "Software": return tr("category.software")
        case "Office":   return tr("category.office")
        case "Other":    return tr("category.other")
        default:         return name
        }
    }

    /// How each analytics expense buckets in the monthly bar chart. Mirrors
    /// the Paid / Pending split shown by `spendBreakdownCard` directly above
    /// so the chart legend and the KPI tiles tell the same story.
    private enum MonthlyStatusGroup: CaseIterable {
        case pending  // submitted through ready-for-reimbursement
        case paid     // reimbursed

        var color: Color {
            switch self {
            case .pending: return Tokens.purchased
            case .paid:    return Tokens.slate500
            }
        }

        /// Translation key for the legend chip. Resolved by `tr()` at the
        /// call site so the enum body stays off the main actor (and the
        /// language picker still refreshes the legend immediately).
        var localizationKey: String {
            switch self {
            case .pending: return "dashboard.kpi.pending"
            case .paid:    return "dashboard.kpi.paid"
            }
        }
    }

    private func statusGroup(for expense: DomainExpense) -> MonthlyStatusGroup {
        expense.status == .reimbursed ? .paid : .pending
    }

    private var months: [BarsChart.Bar] {
        let calendar = Calendar.current
        let now = Date()

        return (0..<6).reversed().map { offset in
            let date = calendar.date(byAdding: .month, value: -offset, to: now) ?? now
            let components = calendar.dateComponents([.year, .month], from: date)

            func isInMonth(_ expense: DomainExpense) -> Bool {
                let expenseDate = expense.purchaseDate ?? expense.submittedAt ?? expense.createdAt
                let c = calendar.dateComponents([.year, .month], from: expenseDate)
                return c.year == components.year && c.month == components.month
            }

            // One segment per status group that has any spend this month.
            // Pending sits on the bottom (the dominant bucket for most teams);
            // paid stacks on top. Groups without spend are skipped — no
            // zero-height slivers cluttering the bar.
            let monthExpenses = analyticsExpenses.filter(isInMonth)
            let segments: [BarsChart.Segment] = MonthlyStatusGroup.allCases.compactMap { group in
                let total = monthExpenses
                    .filter { statusGroup(for: $0) == group }
                    .reduce(0) { $0 + $1.amount.decimalValue }
                guard total > 0 else { return nil }
                return BarsChart.Segment(value: total, color: group.color)
            }

            let label = DateFormatter().shortMonthSymbols[max((components.month ?? 1) - 1, 0)]
            return BarsChart.Bar(label: label, segments: segments)
        }
    }

    private var merchants: [(String, Double, Int)] {
        Dictionary(grouping: analyticsExpenses, by: \.merchant)
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
                Text(tr("dashboard.subtitle")).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text(tr("dashboard.title")).font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4).padding(.top, 4)

            // Multi-role users (managers/finance/admin) can flip between their
            // own submissions and the whole workspace. Plain employees never
            // see the toggle — their data is always personal.
            if canViewWorkspaceScope {
                Picker("", selection: $scope) {
                    Text(tr("dashboard.scope.mine")).tag(Scope.mine)
                    Text(tr("dashboard.scope.workspace")).tag(Scope.workspace)
                }
                .pickerStyle(.segmented)
            }

            spendBreakdownCard(paid: confirmed, pending: projected)

            categoryCard(segments: segments, total: total)

            GlassCard(padding: Tokens.padCard) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(tr("dashboard.monthly")).font(.system(size: 13, weight: .semibold))
                        Spacer()
                        StatusPill(text: tr("dashboard.monthly.range_6mo"), tint: Tokens.slate500)
                    }
                    BarsChart(bars: months)
                    // Legend matches the Paid/Pending split shown by the
                    // breakdown card above, so the chart and the KPI tiles
                    // line up colour-for-colour.
                    FlowingLegend(items: MonthlyStatusGroup.allCases.map { ($0.color, tr($0.localizationKey)) })
                }
            }

            merchantsCard

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
        GlassCard(padding: Tokens.padCard) {
            HStack(alignment: .top, spacing: 0) {
                breakdownColumn(
                    label: tr("dashboard.kpi.paid"),
                    value: money(paid, currency: workspaceCurrency),
                    accent: Tokens.slate500
                )
                Divider().frame(height: 38).padding(.horizontal, 8).opacity(0.4)
                breakdownColumn(
                    label: tr("dashboard.kpi.pending"),
                    value: money(pending, currency: workspaceCurrency),
                    accent: Tokens.purchased
                )
                Divider().frame(height: 38).padding(.horizontal, 8).opacity(0.4)
                breakdownColumn(
                    label: tr("dashboard.kpi.total"),
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

    private func categoryCard(segments: [DonutChart.Segment], total: Double) -> some View {
        GlassCard(padding: Tokens.padCard) {
            VStack(alignment: .leading, spacing: 12) {
                Text(tr("dashboard.category")).font(.system(size: 13, weight: .semibold))
                HStack(spacing: 18) {
                    ZStack {
                        DonutChart(segments: segments).frame(width: 132, height: 132)
                        VStack(spacing: 1) {
                            Text(tr("dashboard.category.total")).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
                            Text(money(total, currency: workspaceCurrency)).font(.system(size: 18, weight: .bold))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(segments, id: \.self) { c in
                            Button {
                                drilldown = DashboardDrilldown(
                                    title: c.label,
                                    subtitle: tr("dashboard.drilldown.category"),
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
                Text(tr("dashboard.top_merchants")).font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)
                ForEach(Array(merchants.enumerated()), id: \.offset) { idx, m in
                    Divider().opacity(0.4)
                    Button {
                        drilldown = DashboardDrilldown(
                            title: m.0,
                            subtitle: tr("dashboard.drilldown.merchant"),
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
                                Text(tr("dashboard.transactions", m.2)).font(.system(size: 11)).foregroundStyle(.tertiary)
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
        SheetScaffold(
            header: {
                SheetHeader(title: item.title, subtitle: item.subtitle, onClose: { dismiss() })
            },
            content: {
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
            }
        )
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
