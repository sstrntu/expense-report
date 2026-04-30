import SwiftUI

struct Company: Identifiable, Hashable {
    let id: String
    let name: String
    let abbr: String
    let color: Color
}

enum ExpenseStatus: String, Codable {
    case pending, approved, rejected, purchased, reimbursed

    var label: String {
        switch self {
        case .pending:    return "Pending"
        case .approved:   return "Approved"
        case .rejected:   return "Rejected"
        case .purchased:  return "Purchased"
        case .reimbursed: return "Reimbursed"
        }
    }

    // Shown in the detail view info card to explain current state
    var sublabel: String {
        switch self {
        case .pending:    return "Awaiting manager approval"
        case .approved:   return "Approved — make the purchase"
        case .rejected:   return "Request was not approved"
        case .purchased:  return "Purchase confirmed — awaiting reimbursement"
        case .reimbursed: return "Completed"
        }
    }

    var tint: Color {
        switch self {
        case .pending:    return Tokens.pending
        case .approved:   return Tokens.approved
        case .rejected:   return Tokens.rejected
        case .purchased:  return Tokens.purchased
        case .reimbursed: return Tokens.reimbursed
        }
    }
}

enum PaymentMethod: String, CaseIterable, Codable, Hashable {
    case transfer = "Bank Transfer"
    case qr       = "QR Code"
    case cash     = "Cash"
    case card     = "Card"
    case cheque   = "Cheque"

    var icon: String {
        switch self {
        case .transfer: return "arrow.left.arrow.right"
        case .qr:       return "qrcode"
        case .cash:     return "banknote"
        case .card:     return "creditcard"
        case .cheque:   return "doc.text"
        }
    }
}

struct Expense: Identifiable, Hashable {
    let id: String
    let companyId: String
    let merchant: String
    let category: String
    let amount: Double
    let date: String
    var status: ExpenseStatus
    var paymentMethod: PaymentMethod? = nil
    var paymentReceipt: String? = nil
    let project: String
    let icon: String
    var isArchived: Bool = false
}

struct ExpenseDraft: Identifiable, Hashable {
    let id: String
    let companyId: String
    let merchant: String
    let amount: Double
    let category: String
    let project: String
    let updated: String
}

struct Project: Identifiable, Hashable {
    let id: String
    let companyId: String
    let name: String
    let spent: Double
    let budget: Double
    let owner: String
    let color: Color
    let visibility: String
    var autoApproveThreshold: Double = 100

    var progress: Double { min(spent / budget, 1) }
}

enum MemberRole: String, CaseIterable, Hashable {
    case submitter = "Submitter"
    case approver = "Approver"
    case manager = "Manager"
    case admin = "Admin"

    var label: String { rawValue }
}
struct Member: Identifiable, Hashable {
    let id: String
    let companyId: String
    let name: String
    let email: String
    var role: MemberRole
    let avatarColor: Color

    var initials: String {
        name.split(separator: " ").compactMap { $0.first.map(String.init) }.joined()
    }
}

struct ApprovalItem: Identifiable, Hashable {
    let id: String
    let user: String
    let merchant: String
    let amount: Double
    let project: String
    let submitted: String
    let avatar: Color
}
