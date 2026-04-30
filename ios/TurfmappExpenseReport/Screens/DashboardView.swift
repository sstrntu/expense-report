import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var app: AppState
    @State private var drilldown: DashboardDrilldown? = nil

    private var cats: [DonutChart.Segment] {
        let totals = Dictionary(grouping: app.currentExpenses, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        return totals
            .sorted { $0.value > $1.value }
            .map { category, value in
                DonutChart.Segment(value: value, color: categoryColor(category), label: category)
            }
    }

    private var months: [BarsChart.Bar] {
        let total = max(app.currentExpenses.reduce(0) { $0 + $1.amount }, 1)
        return [
            .init(label: "Nov", value: total * 0.42),
            .init(label: "Dec", value: total * 0.58),
            .init(label: "Jan", value: total * 0.47),
            .init(label: "Feb", value: total * 0.70),
            .init(label: "Mar", value: total * 0.82),
            .init(label: "Apr", value: total),
        ]
    }

    private var merchants: [(String, Double, Int)] {
        Dictionary(grouping: app.currentExpenses, by: \.merchant)
            .map { merchant, expenses in
                (merchant, expenses.reduce(0) { $0 + $1.amount }, expenses.count)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { $0 }
    }

    var body: some View {
        let segments = cats
        let total = segments.reduce(0) { $0 + $1.value }
        let average = app.currentExpenses.isEmpty ? 0 : total / Double(app.currentExpenses.count)

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Last 30 days").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("Analytics").font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4).padding(.top, 4)

            HStack(spacing: 10) {
                kpiCard(label: "TOTAL SPEND", value: String(format: "$%.2fk", total / 1000), delta: "+8.2%", positive: true)
                kpiCard(label: "AVG PER CLAIM", value: money(average), delta: "\(app.currentExpenses.count) claims", positive: true)
            }

            categoryCard(segments: segments, total: total)

            GlassCard(padding: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Monthly spend").font(.system(size: 13, weight: .semibold))
                        Spacer()
                        StatusPill(text: "6 mo", tint: Tokens.slate500)
                    }
                    BarsChart(bars: months)
                }
            }

            merchantsCard
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(item: $drilldown) { item in
            DashboardDrilldownSheet(item: item)
                .presentationDetents([.medium])
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
                            Text(String(format: "$%.2fk", total/1000)).font(.system(size: 18, weight: .bold))
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(segments, id: \.self) { c in
                            Button {
                                drilldown = DashboardDrilldown(
                                    title: c.label,
                                    subtitle: "Category drilldown",
                                    expenses: app.currentExpenses.filter { $0.category == c.label }
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
                            expenses: app.currentExpenses.filter { $0.merchant == m.0 }
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
                            Text("$\(Int(m.1))").font(.system(size: 13, weight: .semibold))
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
    let expenses: [Expense]
}

struct DashboardDrilldownSheet: View {
    let item: DashboardDrilldown
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
                    ExpenseRow(expense: expense)
                }
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
