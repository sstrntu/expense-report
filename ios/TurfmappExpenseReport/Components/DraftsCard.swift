import SwiftUI

/// Inline drafts panel shared between HomeView (employee) and
/// ManagerOverviewView (manager/finance/admin). Tap a row → handoff the
/// draft id up to RootShell, which switches to the Add tab with that draft
/// loaded.
///
/// Previously HomeView and ManagerOverviewView each defined their own
/// `draftsCard` + `draftRow` with near-identical layout differing only in
/// the heading copy.
struct DraftsCard: View {
    let drafts: [DomainExpense]
    let projects: [DomainProject]
    /// Localization-key prefix so the manager overview can show
    /// "overview.drafts.count" while Home shows "home.drafts.count".
    /// Whichever prefix is passed, the card looks up `<prefix>.count`,
    /// `<prefix>.count.plural`, and `<prefix>.continue`.
    let copyPrefix: String
    var onOpen: (String) -> Void

    var body: some View {
        if !drafts.isEmpty {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    HStack {
                        Text(tr(drafts.count == 1 ? "\(copyPrefix).count" : "\(copyPrefix).count.plural", drafts.count))
                            .font(.system(size: 13, weight: .semibold))
                        Spacer()
                        Text(tr("\(copyPrefix).continue"))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 6)

                    ForEach(Array(drafts.prefix(3).enumerated()), id: \.element.id) { _, draft in
                        Divider().opacity(0.4)
                        Button { onOpen(draft.id) } label: {
                            row(draft)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func row(_ draft: DomainExpense) -> some View {
        HStack(spacing: 12) {
            Text(draft.icon).font(.system(size: 18))
                .frame(width: 32, height: 32)
                .background(Tokens.pending.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(draft.merchant.isEmpty ? tr("home.drafts.untitled") : draft.merchant)
                    .font(.system(size: 13.5, weight: .semibold))
                Text("\(draft.projectName(in: projects)) · \(draft.displayDate)")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(draft.amount.minorUnits == 0 ? "—" : draft.amount.formatted)
                    .font(.system(size: 13, weight: .semibold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}
