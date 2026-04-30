import SwiftUI

struct ManagerOverviewView: View {
    @EnvironmentObject var app: AppState
    var onGoToReview: () -> Void

    private var pendingTotal: Double {
        app.currentExpenses.filter { $0.status == .pending }.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Manager view")
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
                            Text("\(app.currentExpenses.filter { $0.status == .pending }.count)")
                                .font(.system(size: 36, weight: .bold))
                            Text("\(money(pendingTotal)) total")
                                .font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(text: "2 over 24h", tint: Tokens.pending, leadingIcon: "clock")
                    }
                    Button(action: onGoToReview) {
                        Text("Review queue").primaryActionLabel()
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }

            HStack(spacing: 10) {
                kpiCard(label: "TEAM SPEND MTD", value: "$18.4k",  delta: "+12% vs LM",   positive: true)
                kpiCard(label: "AVG APPROVAL",   value: "4.2h",    delta: "−18% faster",  positive: true)
            }

            Text("Project budgets")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 4).padding(.top, 6)

            GlassCard(padding: 14) {
                VStack(spacing: 14) {
                    ForEach(app.currentProjects) { p in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(p.name).font(.system(size: 12.5, weight: .medium))
                                Spacer()
                                Text("\(Int(p.progress * 100))%")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(p.progress > 0.8 ? Tokens.pending : .secondary)
                            }
                            ProgressView(value: p.progress)
                                .progressViewStyle(.linear)
                                .tint(p.color)
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
