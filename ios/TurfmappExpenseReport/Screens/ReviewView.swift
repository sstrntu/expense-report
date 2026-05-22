import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onOpen: (DomainExpense) -> Void
    @State private var projectHistory: ProjectHistoryContext? = nil

    private var pending: [DomainExpense] {
        app.role.canApproveExpenses ? repositoryApp.managerQueue : []
    }

    private var financeQueue: [DomainExpense] {
        app.role.canReimburseExpenses ? repositoryApp.financeQueue : []
    }

    /// Surfaced to anyone who can approve or reimburse — visibility only, not actionable from here.
    private var awaitingPurchase: [DomainExpense] {
        (app.role.canApproveExpenses || app.role.canReimburseExpenses) ? repositoryApp.awaitingPurchaseQueue : []
    }

    /// Projects that have any past/archived expenses (reimbursed, cancelled, rejected, archived).
    /// Used to build the always-visible history browser at the bottom of Review.
    private var projectsWithHistory: [(project: DomainProject, count: Int)] {
        repositoryApp.projects.map { project in
            let count = repositoryApp.expenses.filter {
                $0.projectId == project.id &&
                ($0.isArchived || [.reimbursed, .cancelled, .rejected, .archived].contains($0.status))
            }.count
            return (project, count)
        }
        .filter { $0.count > 0 }
        .sorted { $0.count > $1.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(tr("review.title")).font(.system(size: 26, weight: .bold))
                // Plural-aware via Localizable.strings — Thai doesn't pluralize the
                // same way English does, so we use the same key with %d and let
                // each language's translation handle its own grammar.
                Text(tr(pending.count == 1 && financeQueue.count == 1 ? "review.summary" : "review.summary.plural",
                        pending.count, financeQueue.count, awaitingPurchase.count))
                    .font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4).padding(.top, 4)

            if app.role.canApproveExpenses && pending.count > 1 {
                Button {
                    Task {
                        for item in pending {
                            await repositoryApp.approveExpense(id: item.id)
                        }
                    }
                } label: {
                    Label(tr("review.approve_all"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(14)
                        .background(Tokens.approved, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }

            if pending.isEmpty && financeQueue.isEmpty && awaitingPurchase.isEmpty {
                GlassCard(padding: 24) {
                    VStack(spacing: 6) {
                        Image(systemName: "checkmark.circle").font(.system(size: 28)).foregroundStyle(Tokens.approved)
                        Text(tr("review.empty.title")).font(.system(size: 14, weight: .semibold))
                        Text(tr("review.empty.subtitle")).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                if !pending.isEmpty {
                    queueSection(title: tr("review.section.manager"), items: pending, tint: Tokens.pending)
                }
                if !financeQueue.isEmpty {
                    queueSection(title: tr("review.section.finance"), items: financeQueue, tint: Tokens.reimbursed)
                }
                if !awaitingPurchase.isEmpty {
                    queueSection(title: tr("review.section.awaiting_purchase"), items: awaitingPurchase, tint: Tokens.purchased)
                }
            }

            if !projectsWithHistory.isEmpty {
                pastActivitySection
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(item: $projectHistory) { ctx in
            ProjectHistorySheet(
                projectId: ctx.projectId,
                projectName: ctx.projectName,
                onOpen: { e in
                    projectHistory = nil
                    onOpen(e)
                }
            )
            .environmentObject(repositoryApp)
            .presentationDetents([.large])
        }
    }

    private var pastActivitySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tr("review.section.past"))
                    .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(projectsWithHistory.enumerated()), id: \.element.project.id) { idx, item in
                        if idx > 0 { Divider().opacity(0.4) }
                        Button {
                            projectHistory = ProjectHistoryContext(
                                projectId: item.project.id,
                                projectName: item.project.name
                            )
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "folder.fill")
                                    .foregroundStyle(Tokens.slate500)
                                    .frame(width: 32, height: 32)
                                    .background(Tokens.slate500.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.project.name).font(.system(size: 13.5, weight: .semibold))
                                    Text(tr("review.past.count", item.count))
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    /// Single Button row — the whole row opens the expense. The project
    /// chip is a separate trailing Button so taps on it bring up the
    /// project history sheet without the outer row swallowing the gesture.
    /// Replaces the previous structure that nested three overlapping
    /// `.onTapGesture` calls on one HStack.
    private func queueRow(_ e: DomainExpense, tint: Color) -> some View {
        Button { onOpen(e) } label: {
            HStack(spacing: 12) {
                Text(e.icon)
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 3) {
                    Text(e.merchant).font(.system(size: 13.5, weight: .semibold))
                    Text("\(repositoryApp.displayCategoryName(forId: e.categoryId)) · \(e.displayDate)")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                    StatusPill(text: localizedStatusLabel(e.status), tint: tint)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(e.amount.formatted).font(.system(size: 14, weight: .bold))
                    Button {
                        if let project = repositoryApp.projects.first(where: { $0.id == e.projectId }) {
                            projectHistory = ProjectHistoryContext(projectId: project.id, projectName: project.name)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath").font(.system(size: 9, weight: .semibold))
                            Text(e.projectName(in: repositoryApp.projects)).font(.system(size: 10.5, weight: .medium))
                        }
                        .foregroundStyle(Tokens.slate500)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func queueSection(title: String, items: [DomainExpense], tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                    .foregroundStyle(.tertiary)
                Spacer()
                StatusPill(text: "\(items.count)", tint: tint)
            }
            .padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, e in
                        if idx > 0 { Divider().opacity(0.4) }
                        queueRow(e, tint: tint)
                    }
                }
            }
        }
    }
}

struct ProjectHistoryContext: Identifiable {
    let id = UUID()
    let projectId: String
    let projectName: String
}

struct ProjectHistorySheet: View {
    @EnvironmentObject var repositoryApp: RepositoryAppState
    let projectId: String
    let projectName: String
    var onOpen: (DomainExpense) -> Void
    @Environment(\.dismiss) private var dismiss

    private var history: [DomainExpense] {
        repositoryApp.expenses
            .filter { $0.projectId == projectId }
            .filter { e in
                e.isArchived ||
                [.reimbursed, .cancelled, .rejected, .archived].contains(e.status)
            }
            .sorted { ($0.submittedAt ?? $0.createdAt) > ($1.submittedAt ?? $1.createdAt) }
    }

    private var totals: (count: Int, amount: Double) {
        let amount = history
            .filter { $0.amount.currency == repositoryApp.aggregationCurrency }
            .reduce(0) { $0 + $1.amount.decimalValue }
        return (history.count, amount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(projectName).font(.system(size: 20, weight: .bold))
                    Text(tr("review.history.subtitle")).font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

            HStack(spacing: 10) {
                summaryTile(label: tr("review.history.entries"), value: "\(totals.count)")
                summaryTile(label: tr("review.history.total"),
                            value: money(totals.amount, currency: repositoryApp.aggregationCurrency))
            }
            .padding(.horizontal, 20)

            ScrollView {
                if history.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 24, weight: .semibold)).foregroundStyle(.secondary)
                        Text(tr("review.history.empty.title")).font(.system(size: 14, weight: .semibold))
                        Text(tr("review.history.empty.subtitle"))
                            .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 28).padding(.vertical, 36)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(history.enumerated()), id: \.element.id) { idx, expense in
                            if idx > 0 { Divider().opacity(0.4) }
                            Button { onOpen(expense) } label: {
                                DomainExpenseRow(
                                    expense: expense,
                                    projects: repositoryApp.projects,
                                    categories: repositoryApp.categories
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func summaryTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 18, weight: .bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}
