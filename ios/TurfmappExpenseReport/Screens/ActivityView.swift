import SwiftUI

/// Filter keys for the Activity screen. Stored as enum so the active filter
/// stays stable when the user switches language mid-session (the rawValue
/// matches the .strings key, looked up at render time).
enum ActivityFilter: String, CaseIterable, Hashable {
    case all
    case awaitingApproval
    case approved
    case awaitingReimbursement
    case reimbursed
    case rejected
    case archived

    var stringsKey: String {
        switch self {
        case .all: return "activity.filter.all"
        case .awaitingApproval: return "activity.filter.awaiting_approval"
        case .approved: return "activity.filter.approved"
        case .awaitingReimbursement: return "activity.filter.awaiting_reimbursement"
        case .reimbursed: return "activity.filter.reimbursed"
        case .rejected: return "activity.filter.rejected"
        case .archived: return "activity.filter.archived"
        }
    }
}

struct ActivityView: View {
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @ObservedObject private var localization = LocalizationManager.shared
    @State private var filter: ActivityFilter = .all
    @State private var searchText = ""
    /// Empty string acts as the "All projects" sentinel — easier than juggling
    /// optionals across the filter chain.
    @State private var projectFilter: String = ""
    @State private var expenseToDelete: DomainExpense? = nil
    var onOpen: (DomainExpense) -> Void
    /// Provided only when pushed as a stack screen (e.g. from You → My activity).
    /// When nil the view assumes it's the root of the Activity tab.
    var onBack: (() -> Void)? = nil

    private var filtered: [DomainExpense] {
        let pool = repositoryApp.expenses.filter { expense in
            switch filter {
            case .archived: return expense.isArchived || expense.status == .archived
            case .awaitingApproval: return expense.status == .pendingManagerApproval
            case .approved: return expense.status == .approved
            case .awaitingReimbursement: return [.pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement].contains(expense.status)
            case .reimbursed: return expense.status == .reimbursed
            case .rejected: return expense.status == .rejected
            case .all: return !expense.isArchived && expense.status != .archived
            }
        }

        return pool.filter { expense in
            let matchesSearch = searchText.isEmpty ||
                expense.merchant.localizedCaseInsensitiveContains(searchText) ||
                repositoryApp.categoryName(forId: expense.categoryId).localizedCaseInsensitiveContains(searchText) ||
                repositoryApp.displayCategoryName(forId: expense.categoryId).localizedCaseInsensitiveContains(searchText) ||
                expense.projectName(in: repositoryApp.projects).localizedCaseInsensitiveContains(searchText)
            let matchesProject = projectFilter.isEmpty || expense.projectName(in: repositoryApp.projects) == projectFilter
            return matchesSearch && matchesProject
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                if let onBack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .glassSurface(corner: 999)
                }
                Text(tr("activity.title")).font(.system(size: 26, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 4).padding(.top, 4)

            searchAndProjectFilters

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ActivityFilter.allCases, id: \.self) { f in
                        Button(tr(f.stringsKey)) { filter = f }
                            .buttonStyle(FilterChipStyle(active: filter == f))
                    }
                }
                .padding(.horizontal, 4)
            }

            let today    = Array(filtered.prefix(2))
            let thisWeek = filtered.count > 2 ? Array(filtered[2..<min(5, filtered.count)]) : []
            let earlier  = filtered.count > 5 ? Array(filtered.suffix(from: 5)) : []

            if !today.isEmpty    { section(title: tr("activity.section.today"),     items: today) }
            if !thisWeek.isEmpty { section(title: tr("activity.section.this_week"), items: thisWeek) }
            if !earlier.isEmpty  { section(title: tr("activity.section.earlier"),   items: earlier) }

            if filtered.isEmpty {
                GlassCard(padding: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: filter == .archived ? "archivebox" : "magnifyingglass")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(emptyTitle)
                            .font(.system(size: 14, weight: .semibold))
                        Text(emptySubtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .alert(item: $expenseToDelete) { expense in
            Alert(
                title: Text(tr("activity.delete.title", expense.merchant)),
                message: Text(tr("activity.delete.message")),
                primaryButton: .destructive(Text(tr("common.delete"))) {
                    Task { await repositoryApp.deleteExpense(id: expense.id) }
                },
                secondaryButton: .cancel(Text(tr("common.cancel")))
            )
        }
    }

    private var emptyTitle: String {
        if filter == .archived { return tr("activity.empty.archived.title") }
        if repositoryApp.expenses.isEmpty { return tr("activity.empty.fresh.title") }
        return tr("activity.empty.filtered.title")
    }

    private var emptySubtitle: String {
        if filter == .archived { return tr("activity.empty.archived.subtitle") }
        if repositoryApp.expenses.isEmpty { return tr("activity.empty.fresh.subtitle") }
        return tr("activity.empty.filtered.subtitle")
    }

    private var searchAndProjectFilters: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(tr("activity.search.placeholder"), text: $searchText)
                    .font(.system(size: 13.5, weight: .medium))
                    .textInputAutocapitalization(.never)
            }
            .padding(12)
            .glassSurface(corner: 16)

            HStack(spacing: 8) {
                Menu {
                    Button(tr("activity.all_projects")) { projectFilter = "" }
                    ForEach(repositoryApp.projects) { project in
                        Button(project.name) { projectFilter = project.name }
                    }
                } label: {
                    Label(projectFilter.isEmpty ? tr("activity.all_projects") : projectFilter, systemImage: "folder.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                Label(tr("activity.all_time"), systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                Spacer()
            }
        }
    }

    private func section(title: String, items: [DomainExpense]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, e in
                        if idx > 0 { Divider().opacity(0.4) }
                        Button { onOpen(e) } label: { DomainExpenseRow(expense: e, projects: repositoryApp.projects, categories: repositoryApp.categories) }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    Task { await repositoryApp.archiveExpense(id: e.id) }
                                } label: {
                                    Label(e.isArchived ? tr("common.unarchive") : tr("common.archive"),
                                          systemImage: e.isArchived ? "tray.and.arrow.up" : "archivebox")
                                }
                                Button(role: .destructive) {
                                    expenseToDelete = e
                                } label: {
                                    Label(tr("common.delete"), systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
    }
}

struct FilterChipStyle: ButtonStyle {
    let active: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(active ? Color.white : Color.primary)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(
                Group {
                    if active {
                        Capsule().fill(Tokens.slate500)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
            )
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.4), lineWidth: 0.5))
    }
}
