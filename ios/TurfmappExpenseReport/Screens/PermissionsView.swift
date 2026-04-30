import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var app: AppState
    @State private var editingID: String? = nil
    @State private var showInvite = false
    @State private var memberToRemove: Member? = nil
    @State private var showRemoveConfirm = false
    @State private var pendingInvites = ["finance@turfmapp.io"]
    var onBack: () -> Void

    private let roles = MemberRole.allCases
    private var members: [Member] { app.currentMembers }
    private var canEditRoles: Bool { app.role == .manager || app.role == .admin }
    private var canInviteOrRemove: Bool { app.role == .admin }
    private var editableRoles: [MemberRole] {
        app.role == .admin ? [.employee, .manager, .admin] : [.employee, .manager]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain).glassSurface(corner: 999)
                Text("Permissions").font(.system(size: 18, weight: .bold))
                Spacer()
                if canInviteOrRemove {
                    Button { showInvite = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .background(Tokens.slate500, in: Circle())
                }
            }
            .padding(.horizontal, 4).padding(.top, 4)

            // Role count grid
            let counts = Dictionary(grouping: members, by: \.role)
            HStack(spacing: 8) {
                ForEach(roles, id: \.self) { r in
                    GlassCard(padding: 10) {
                        VStack(spacing: 1) {
                            Text("\(counts[r]?.count ?? 0)").font(.system(size: 18, weight: .bold))
                            Text(r.label).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Text("Members").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { idx, m in
                        if idx > 0 { Divider().opacity(0.4) }
                        memberRow(m)
                    }
                }
            }

            if canInviteOrRemove && !pendingInvites.isEmpty {
                Text("Pending invites").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(pendingInvites.enumerated()), id: \.offset) { idx, email in
                            if idx > 0 { Divider().opacity(0.4) }
                            HStack(spacing: 12) {
                                Image(systemName: "envelope.badge.fill")
                                    .foregroundStyle(Tokens.pending)
                                    .frame(width: 32, height: 32)
                                    .background(Tokens.pending.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(email).font(.system(size: 13.5, weight: .medium))
                                    Text("Invite sent · Employee access").font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Cancel") { pendingInvites.removeAll { $0 == email } }
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Tokens.rejected)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                        }
                    }
                }
            }

            Text("Approval policy").font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    FormFieldRow(label: "Workspace default threshold",  value: "$100")
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Receipt required over", value: "$75")
                    Divider().opacity(0.4)
                    ToggleRow(label: "Two-step approval", sub: "Over $1,000", isOn: true)
                    Divider().opacity(0.4)
                    FormFieldRow(label: "Allowed categories", value: "Meals, Travel, Software")
                    Divider().opacity(0.4)
                    ToggleRow(label: "Finance reimbursement step", sub: "Manager approves, finance reimburses", isOn: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(isPresented: $showInvite) {
            InviteMemberSheet { email in
                pendingInvites.insert(email, at: 0)
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog("Remove member?", isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button("Remove \(memberToRemove?.name ?? "member")", role: .destructive) {}
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(memberToRemove?.name ?? "This member") will lose access to \(app.company.name).")
        }
    }

    private func memberRow(_ m: Member) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Avatar(color: m.avatarColor, size: 36, label: m.initials)
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.name).font(.system(size: 13, weight: .semibold))
                    Text(m.email).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if canEditRoles {
                    Button {
                        editingID = editingID == m.id ? nil : m.id
                    } label: {
                        Text(m.role.label)
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(m.role.label)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .background(Color.primary.opacity(0.07), in: Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                }
                if canInviteOrRemove {
                    Button {
                        memberToRemove = m
                        showRemoveConfirm = true
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Tokens.rejected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)

            if editingID == m.id, canEditRoles {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(editableRoles, id: \.self) { r in
                            Button {
                                app.setMemberRole(id: m.id, to: r)
                                editingID = nil
                            } label: {
                                Text(r.label)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(m.role == r ? .white : .primary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                            .background(
                                m.role == r ? Tokens.slate500 : Color.clear,
                                in: Capsule()
                            )
                            .overlay(Capsule().strokeBorder(m.role == r ? Color.clear : Color.primary.opacity(0.15)))
                        }
                    }
                    .padding(.horizontal, 12).padding(.bottom, 10)
                }
            }
        }
    }
}

struct InviteMemberSheet: View {
    var onInvite: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Invite member")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 20).padding(.top, 24)

            GlassCard(padding: 16) {
                VStack(spacing: 0) {
                    HStack {
                        Text("Email").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                        Spacer()
                        TextField("teammate@company.com", text: $email)
                            .font(.system(size: 13.5, weight: .medium))
                            .textInputAutocapitalization(.never)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 210)
                    }
                    .padding(.vertical, 11)
                }
            }
            .padding(.horizontal, 20)

            infoBanner(icon: "clock.badge.fill", tint: Tokens.pending,
                       title: "Pending invite",
                       message: "Invited members appear in a pending state until they accept.")
                .padding(.horizontal, 20)

            Spacer()

            Button {
                onInvite(email.isEmpty ? "new.member@company.com" : email)
                dismiss()
            } label: {
                Text("Send invite").primaryActionLabel()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

struct ToggleRow: View {
    let label: String
    var sub: String? = nil
    @State var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 13, weight: .medium))
                if let sub {
                    Text(sub).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn).labelsHidden().tint(Tokens.approved)
        }
        .padding(.vertical, 11)
    }
}
