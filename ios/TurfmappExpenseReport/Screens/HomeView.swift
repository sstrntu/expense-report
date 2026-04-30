import SwiftUI

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @Binding var selectedTab: TabID
    var onOpen: (Expense) -> Void

    var body: some View {
        let pending  = app.currentExpenses.filter { $0.status == .pending }.reduce(0)  { $0 + $1.amount }
        let approved = app.currentExpenses.filter { $0.status == .approved }.reduce(0) { $0 + $1.amount }

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Good morning, Sira").font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                Text("This month").font(.system(size: 26, weight: .bold))
            }
            .padding(.horizontal, 4)
            .padding(.top, 4)

            heroCard(pending: pending, approved: approved)

            scanReceiptButton

            aiInsightCard

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
                        Text(money(pending + approved)).font(.system(size: 36, weight: .bold)).tracking(-1)
                    }
                    Spacer()
                    StatusPill(text: "+12%", tint: Tokens.approved, leadingIcon: "arrow.up")
                }

                Sparkline(data: [42, 48, 39, 65, 58, 72, 68, 81, 74, 88, 82, 96])
                    .frame(height: 50)

                HStack {
                    miniStat("Pending",  money(pending))
                    Spacer()
                    miniStat("Approved", money(approved))
                    Spacer()
                    miniStat("Rejected", "$22.18")
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
                    Text("New Request").font(.system(size: 14, weight: .semibold))
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

    private var aiInsightCard: some View {
        GlassCard(padding: 14) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(LinearGradient(colors: [Tokens.aiPurple, Tokens.slate500], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "sparkles").foregroundStyle(.white).font(.system(size: 14, weight: .semibold))
                }.frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Insight").font(.system(size: 12, weight: .semibold))
                    Text("Your meals spend is 23% above your team average. Consider grouping meetings to share meal expenses.")
                        .font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(nil)
                }
            }
        }
    }

    private var recentList: some View {
        GlassCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(app.currentExpenses.prefix(4).enumerated()), id: \.element.id) { idx, e in
                    if idx > 0 { Divider().opacity(0.4) }
                    Button { onOpen(e) } label: { ExpenseRow(expense: e) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var projectsCard: some View {
        GlassCard(padding: 14) {
            VStack(spacing: 14) {
                ForEach(app.currentProjects.prefix(3)) { p in ProjectRow(project: p) }
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

func money(_ v: Double) -> String { String(format: "$%.2f", v) }
