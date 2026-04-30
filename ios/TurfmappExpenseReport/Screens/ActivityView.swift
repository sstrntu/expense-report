import SwiftUI

struct ActivityView: View {
    @EnvironmentObject var app: AppState
    @State private var filter: String = "All"
    @State private var searchText = ""
    @State private var projectFilter = "All projects"
    var onOpen: (Expense) -> Void

    private let filters = ["All", "Awaiting Approval", "Approved", "Awaiting Reimbursement", "Reimbursed", "Rejected"]

    private var filtered: [Expense] {
        let statusFiltered: [Expense]
        switch filter {
        case "Awaiting Approval":      statusFiltered = app.currentExpenses.filter { $0.status == .pending }
        case "Approved":               statusFiltered = app.currentExpenses.filter { $0.status == .approved }
        case "Awaiting Reimbursement": statusFiltered = app.currentExpenses.filter { $0.status == .purchased }
        case "Reimbursed":             statusFiltered = app.currentExpenses.filter { $0.status == .reimbursed }
        case "Rejected":               statusFiltered = app.currentExpenses.filter { $0.status == .rejected }
        default:                       statusFiltered = app.currentExpenses
        }

        return statusFiltered.filter { expense in
            let matchesSearch = searchText.isEmpty ||
                expense.merchant.localizedCaseInsensitiveContains(searchText) ||
                expense.category.localizedCaseInsensitiveContains(searchText) ||
                expense.project.localizedCaseInsensitiveContains(searchText)
            let matchesProject = projectFilter == "All projects" || expense.project == projectFilter
            return matchesSearch && matchesProject
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity").font(.system(size: 26, weight: .bold))
                .padding(.horizontal, 4).padding(.top, 4)

            searchAndProjectFilters

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(filters, id: \.self) { f in
                        Button(f) { filter = f }
                            .buttonStyle(FilterChipStyle(active: filter == f))
                    }
                }
                .padding(.horizontal, 4)
            }

            let today    = Array(filtered.prefix(2))
            let thisWeek = filtered.count > 2 ? Array(filtered[2..<min(5, filtered.count)]) : []
            let earlier  = filtered.count > 5 ? Array(filtered.suffix(from: 5)) : []

            if !today.isEmpty    { section(title: "Today",     items: today) }
            if !thisWeek.isEmpty { section(title: "This week", items: thisWeek) }
            if !earlier.isEmpty  { section(title: "Earlier",   items: earlier) }

            if filtered.isEmpty {
                GlassCard(padding: 24) {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text(app.currentExpenses.isEmpty ? "No expenses yet" : "No matching expenses")
                            .font(.system(size: 14, weight: .semibold))
                        Text(app.currentExpenses.isEmpty ? "New expenses will appear here after submission." : "Adjust search, project, or status filters.")
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
    }

    private var searchAndProjectFilters: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search merchant, category, project", text: $searchText)
                    .font(.system(size: 13.5, weight: .medium))
                    .textInputAutocapitalization(.never)
            }
            .padding(12)
            .glassSurface(corner: 16)

            HStack(spacing: 8) {
                Menu {
                    Button("All projects") { projectFilter = "All projects" }
                    ForEach(app.currentProjects) { project in
                        Button(project.name) { projectFilter = project.name }
                    }
                } label: {
                    Label(projectFilter, systemImage: "folder.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.primary.opacity(0.06), in: Capsule())
                }
                .buttonStyle(.plain)

                Label("Last 30 days", systemImage: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.primary.opacity(0.06), in: Capsule())

                Spacer()
            }
        }
    }

    private func section(title: String, items: [Expense]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold)).tracking(0.6)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, e in
                        if idx > 0 { Divider().opacity(0.4) }
                        Button { onOpen(e) } label: { ExpenseRow(expense: e) }
                            .buttonStyle(.plain)
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
