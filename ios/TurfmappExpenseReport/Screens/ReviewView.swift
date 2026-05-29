import SwiftUI

struct ReviewView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onOpen: (DomainExpense) -> Void
    @State private var projectHistory: ProjectHistoryContext? = nil

    // managerQueue / financeQueue / awaitingPurchaseQueue on RepositoryAppState
    // are now project-aware — they only include expenses the current user can
    // act on (workspace role OR project_membership role). We don't need the
    // outer "if canApprove? else []" gate anymore; the empty case falls out
    // of the project-aware filter automatically.
    private var pending: [DomainExpense] { repositoryApp.managerQueue }
    private var financeQueue: [DomainExpense] { repositoryApp.financeQueue }

    /// Visible to anyone who can approve OR reimburse the project — same gate
    /// as the role-aware repository helper. Surfaced as "Watching", read-only.
    private var awaitingPurchase: [DomainExpense] { repositoryApp.awaitingPurchaseQueue }

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

            queueStack
                .tourTarget(.reviewQueues)

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

    /// Combined queue stack — empty state OR one section per non-empty queue.
    /// Extracted into a computed property so the whole block can be tagged as
    /// the tour target (.reviewQueues) without breaking the existing if/else
    /// layout. Section headers spell out which role the user is acting in,
    /// which matters for a multi-hat user (e.g. a Manager who also handles
    /// Finance).
    @ViewBuilder
    private var queueStack: some View {
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
                queueSection(
                    roleIcon: "person.badge.shield.checkmark.fill",
                    roleLabel: tr("review.role.manager"),
                    actionLabel: tr("review.action.to_approve"),
                    items: pending, tint: Tokens.pending
                )
            }
            if !financeQueue.isEmpty {
                queueSection(
                    roleIcon: "creditcard.fill",
                    roleLabel: tr("review.role.finance"),
                    actionLabel: tr("review.action.to_reimburse"),
                    items: financeQueue, tint: Tokens.reimbursed
                )
            }
            if !awaitingPurchase.isEmpty {
                queueSection(
                    roleIcon: "eye.fill",
                    roleLabel: tr("review.role.watching"),
                    actionLabel: tr("review.action.awaiting_purchase"),
                    items: awaitingPurchase, tint: Tokens.purchased
                )
            }
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

    /// Header is now two parts: a coloured role badge ("AS MANAGER") to show
    /// which hat the user is wearing, plus a plain action description
    /// ("3 to approve"). Pill on the right keeps the running count.
    private func queueSection(
        roleIcon: String,
        roleLabel: String,
        actionLabel: String,
        items: [DomainExpense],
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: roleIcon).font(.system(size: 9, weight: .bold))
                    Text(roleLabel.uppercased())
                        .font(.system(size: 10, weight: .bold)).tracking(0.8)
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(tint.opacity(0.12), in: Capsule())

                Text(actionLabel)
                    .font(.system(size: 11, weight: .semibold)).tracking(0.3)
                    .foregroundStyle(.secondary)
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
        SheetScaffold(
            header: {
                SheetHeader(
                    title: projectName,
                    subtitle: tr("review.history.subtitle"),
                    onClose: { dismiss() }
                )
            },
            content: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        summaryTile(label: tr("review.history.entries"), value: "\(totals.count)")
                        summaryTile(label: tr("review.history.total"),
                                    value: money(totals.amount, currency: repositoryApp.aggregationCurrency))
                    }

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
                    }
                }
            }
        )
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
