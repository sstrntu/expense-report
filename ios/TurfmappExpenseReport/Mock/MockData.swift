import SwiftUI

enum MockData {
    static let companies: [Company] = [
        Company(id: "turfmapp",     name: "Turfmapp",         abbr: "TM",  color: Color(hex: 0x878E9F)),
        Company(id: "groundwork",   name: "Groundwork10",     abbr: "G10", color: Color(hex: 0x4A6FA5)),
        Company(id: "baansaensaep", name: "Baan Saen Saep",   abbr: "BS",  color: Color(hex: 0xC97B4A)),
        Company(id: "ladderice",    name: "Ladderice",        abbr: "LI",  color: Color(hex: 0x7E5BA8)),
    ]

    static let expenses: [Expense] = [
        // Turfmapp
        Expense(id: "e1", companyId: "turfmapp",     merchant: "Whole Foods Market", category: "Meals",    amount: 47.23,  date: "Today, 12:48 PM", status: .pending,    project: "Turfmapp Q2 Launch",     icon: "🍱"),
        Expense(id: "e2", companyId: "turfmapp",     merchant: "Uber",               category: "Travel",   amount: 18.50,  date: "Today, 9:12 AM",  status: .approved,   project: "Turfmapp Q2 Launch",     icon: "🚕"),
        Expense(id: "e4", companyId: "turfmapp",     merchant: "Delta Airlines",     category: "Travel",   amount: 612.40, date: "Mar 18",          status: .pending,    project: "Turfmapp Q2 Launch",     icon: "✈️"),
        Expense(id: "e6", companyId: "turfmapp",     merchant: "Sweetgreen",         category: "Meals",    amount: 22.18,  date: "Mar 12",          status: .rejected,   project: "Turfmapp Q2 Launch",     icon: "🥗"),
        // Groundwork10
        Expense(id: "e3", companyId: "groundwork",   merchant: "Apple Store",        category: "Software", amount: 199.00, date: "Yesterday",       status: .purchased,  project: "Groundwork10 Pilot",     icon: "💻"),
        Expense(id: "e7", companyId: "groundwork",   merchant: "Hilton SF",          category: "Travel",   amount: 348.00, date: "Mar 20",          status: .pending,    project: "Groundwork10 Pilot",     icon: "🏨"),
        // Baan Saen Saep
        Expense(id: "e8", companyId: "baansaensaep", merchant: "Adobe Creative",     category: "Software", amount: 79.99,  date: "Mar 22",          status: .approved,   project: "Baan Saen Saep Rebrand", icon: "🎨"),
        Expense(id: "e9", companyId: "baansaensaep", merchant: "Figma",              category: "Software", amount: 45.00,  date: "Mar 19",          status: .reimbursed, project: "Baan Saen Saep Rebrand", icon: "🖼️"),
        // Ladderice
        Expense(id: "e5", companyId: "ladderice",    merchant: "WeWork",             category: "Office",   amount: 89.00,  date: "Mar 14",          status: .reimbursed, project: "Ladderice DevOps",       icon: "🏢"),
        Expense(id: "ea", companyId: "ladderice",    merchant: "Lyft",               category: "Travel",   amount: 24.10,  date: "Mar 17",          status: .pending,    project: "Ladderice DevOps",       icon: "🚕"),
    ]

    static let projects: [Project] = [
        Project(id: "p1", companyId: "turfmapp",     name: "Turfmapp Q2 Launch",     spent: 12480, budget: 25000, owner: "You",       color: Color(hex: 0x878E9F), visibility: "team",    autoApproveThreshold: 100),
        Project(id: "p2", companyId: "groundwork",   name: "Groundwork10 Pilot",     spent: 4220,  budget: 8000,  owner: "Mark Dowd", color: Color(hex: 0x4A6FA5), visibility: "private", autoApproveThreshold: 50),
        Project(id: "p3", companyId: "baansaensaep", name: "Baan Saen Saep Rebrand", spent: 7150,  budget: 12000, owner: "Pim S.",    color: Color(hex: 0xC97B4A), visibility: "team",    autoApproveThreshold: 250),
        Project(id: "p4", companyId: "ladderice",    name: "Ladderice DevOps",       spent: 1840,  budget: 6000,  owner: "Diego A.",  color: Color(hex: 0x7E5BA8), visibility: "org",     autoApproveThreshold: 100),
    ]

    static let approvals: [ApprovalItem] = [
        ApprovalItem(id: "a1", user: "Alex Lee",   merchant: "Delta Airlines", amount: 612.40, project: "Turfmapp",       submitted: "2h ago",    avatar: Color(hex: 0x6B7185)),
        ApprovalItem(id: "a2", user: "Priya Shah", merchant: "Hilton SF",      amount: 348.00, project: "Groundwork10",   submitted: "4h ago",    avatar: Color(hex: 0x4A6FA5)),
        ApprovalItem(id: "a3", user: "Jordan K.",  merchant: "Adobe Creative", amount: 79.99,  project: "Baan Saen Saep", submitted: "Yesterday", avatar: Color(hex: 0xC97B4A)),
        ApprovalItem(id: "a4", user: "Sira Sasitorn",  merchant: "Lyft",           amount: 24.10,  project: "Ladderice",      submitted: "Yesterday", avatar: Color(hex: 0x7E5BA8)),
    ]

    static let members: [Member] = [
        Member(id: "m1", companyId: "turfmapp",     name: "Alex Lee",   email: "alex@turfmapp.io",       role: .employee, avatarColor: Color(hex: 0x6B7185)),
        Member(id: "m2", companyId: "turfmapp",     name: "Priya Shah", email: "priya@turfmapp.io",      role: .manager,  avatarColor: Color(hex: 0x4A6FA5)),
        Member(id: "m3", companyId: "groundwork",   name: "Mark Dowd",  email: "mark@groundwork10.com",  role: .admin,     avatarColor: Color(hex: 0x4A6FA5)),
        Member(id: "m4", companyId: "groundwork",   name: "Sira Sasitorn",  email: "sira@groundwork10.com",   role: .employee, avatarColor: Color(hex: 0x7E5BA8)),
        Member(id: "m5", companyId: "baansaensaep", name: "Pim S.",     email: "pim@baansaensaep.com",   role: .admin,     avatarColor: Color(hex: 0xC97B4A)),
        Member(id: "m6", companyId: "baansaensaep", name: "Mei Chen",   email: "mei@baansaensaep.com",   role: .employee, avatarColor: Color(hex: 0x5EA06C)),
        Member(id: "m7", companyId: "ladderice",    name: "Diego A.",   email: "diego@ladderice.com",    role: .manager,  avatarColor: Color(hex: 0x7E5BA8)),
        Member(id: "m8", companyId: "ladderice",    name: "Jordan K.",  email: "jordan@ladderice.com",   role: .employee, avatarColor: Color(hex: 0x6B7185)),
    ]
}
