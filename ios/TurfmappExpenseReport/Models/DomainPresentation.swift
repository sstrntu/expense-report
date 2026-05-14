import SwiftUI

extension DomainWorkspace {
    var brandColor: Color {
        Color(hex: UInt32(brandColorHex, radix: 16) ?? 0x878E9F)
    }

    var legacyCompany: Company {
        Company(id: id, name: name, abbr: abbr, color: brandColor)
    }
}

extension WorkspaceRole {
    var label: String {
        rawValue.capitalized
    }

    var appRole: AppRole {
        switch self {
        case .employee: return .employee
        case .manager: return .manager
        case .finance: return .finance
        case .admin: return .admin
        }
    }

    var legacyMemberRole: MemberRole {
        switch self {
        case .employee: return .employee
        case .manager: return .manager
        case .finance: return .approver
        case .admin: return .admin
        }
    }
}

extension AppRole {
    var workspaceRole: WorkspaceRole {
        switch self {
        case .employee: return .employee
        case .manager: return .manager
        case .finance: return .finance
        case .admin: return .admin
        }
    }

    var canApproveExpenses: Bool {
        workspaceRole.canApproveExpenses
    }

    var canReimburseExpenses: Bool {
        workspaceRole.canReimburseExpenses
    }
}

extension DomainWorkspaceMember {
    var initials: String {
        let value = displayName.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
        return value.isEmpty ? "U" : value
    }

    var avatarColor: Color {
        Color(hex: UInt32(avatarColorHex, radix: 16) ?? 0x878E9F)
    }

    var legacyRole: MemberRole {
        switch role {
        case .employee: return .employee
        case .manager: return .manager
        case .finance: return .approver
        case .admin: return .admin
        }
    }
}

extension MoneyAmount {
    var decimalValue: Double {
        Double(minorUnits) / 100
    }

    var formatted: String {
        String(format: "$%.2f", decimalValue)
    }
}

extension DomainExpense {
    var categoryLabel: String {
        categoryId
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }

    var displayDate: String {
        if Calendar.current.isDateInToday(submittedAt ?? createdAt) {
            return "Today"
        }
        return (submittedAt ?? createdAt).formatted(date: .abbreviated, time: .omitted)
    }

    var icon: String {
        switch categoryLabel {
        case "Meals": return "🍱"
        case "Travel": return "✈️"
        case "Software": return "💻"
        case "Office": return "🏢"
        default: return "🧾"
        }
    }

    func projectName(in projects: [DomainProject]) -> String {
        projects.first { $0.id == projectId }?.name ?? "Unknown project"
    }

    func legacyExpense(projects: [DomainProject]) -> Expense {
        Expense(
            id: id,
            companyId: workspaceId,
            merchant: merchant,
            category: categoryLabel,
            amount: amount.decimalValue,
            date: displayDate,
            status: status.legacyStatus,
            project: projectName(in: projects),
            icon: icon,
            isArchived: isArchived
        )
    }
}

extension ExpenseWorkflowStatus {
    var legacyStatus: ExpenseStatus {
        switch self {
        case .draft, .submitted, .scanProcessing, .scanFailed, .pendingManagerApproval:
            return .pending
        case .approved:
            return .approved
        case .rejected, .cancelled:
            return .rejected
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement:
            return .purchased
        case .reimbursed:
            return .reimbursed
        case .archived:
            return .reimbursed
        }
    }

    var tint: Color {
        switch self {
        case .draft, .archived:
            return Tokens.slate500
        case .submitted, .scanProcessing, .pendingManagerApproval:
            return Tokens.pending
        case .approved:
            return Tokens.approved
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement:
            return Tokens.purchased
        case .reimbursed:
            return Tokens.reimbursed
        case .rejected, .cancelled, .scanFailed:
            return Tokens.rejected
        }
    }

    var icon: String {
        switch self {
        case .draft: return "doc"
        case .submitted, .scanProcessing, .pendingManagerApproval: return "clock"
        case .approved: return "checkmark"
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement: return "creditcard"
        case .reimbursed: return "checkmark.circle"
        case .rejected, .cancelled, .scanFailed: return "xmark"
        case .archived: return "archivebox"
        }
    }

    var nextOwnerLabel: String? {
        switch self {
        case .submitted, .scanProcessing:
            return "System"
        case .pendingManagerApproval:
            return "Manager"
        case .approved:
            return "Employee"
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement:
            return "Finance"
        default:
            return nil
        }
    }

    var nextOwnerIcon: String {
        switch self {
        case .submitted, .scanProcessing:
            return "sparkles"
        case .pendingManagerApproval:
            return "person.crop.circle.badge.clock"
        case .approved:
            return "bag"
        case .pendingFinanceReview, .purchaseConfirmed, .readyForReimbursement:
            return "creditcard"
        default:
            return "circle"
        }
    }
}

extension ExpenseWorkflowEvent {
    var title: String {
        switch eventType {
        case "created": return "Created"
        case "submitted": return "Submitted"
        case "resubmitted": return "Resubmitted"
        case "approved": return "Approved"
        case "rejected": return "Rejected"
        case "cancelled": return "Cancelled"
        case "purchase_confirmed": return "Purchase confirmed"
        case "reimbursement_sent": return "Reimbursed"
        case "archived": return "Archived"
        case "unarchived": return "Unarchived"
        case "scan_completed": return "Receipt scanned"
        case "budget_warning": return "Budget warning"
        case "budget_escalation": return "Budget escalation"
        default: return eventType.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    var subtitle: String {
        if let note, !note.isEmpty { return note }
        if let toStatus { return toStatus.displayLabel }
        return createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    var tint: Color {
        switch eventType {
        case "approved": return Tokens.approved
        case "rejected", "cancelled": return Tokens.rejected
        case "purchase_confirmed", "budget_warning", "budget_escalation": return Tokens.pending
        case "reimbursement_sent": return Tokens.reimbursed
        case "scan_completed": return Tokens.aiPurple
        default: return Tokens.slate500
        }
    }
}
