import SwiftUI

struct PermissionsView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var editingID: String? = nil
    @State private var showInvite = false
    @State private var memberToRemove: DomainWorkspaceMember? = nil
    @State private var showRemoveConfirm = false
    var onBack: () -> Void

    private let roles = WorkspaceRole.allCases
    private var members: [DomainWorkspaceMember] { repositoryApp.members }
    /// Role editing is admin-only — this must match the server's
    /// "admins can manage memberships" RLS policy. Managers previously saw
    /// an editor whose writes RLS silently rejected.
    private var canEditRoles: Bool { app.role == .admin }
    private var canInviteOrRemove: Bool { app.role == .admin }
    private var editableRoles: [WorkspaceRole] { [.employee, .manager, .finance, .admin] }

    /// True when this member is the only active admin. Demoting or removing
    /// them would leave the workspace unmanageable (memberships, invites,
    /// projects are all admin-gated), so the UI locks the row; the server
    /// trigger enforces the same rule against direct API calls.
    private func isLastActiveAdmin(_ m: DomainWorkspaceMember) -> Bool {
        m.role == .admin && members.filter { $0.role == .admin && $0.status == "active" }.count <= 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.pressable).glassSurface(corner: 999)
                Text(tr("permissions.title")).font(.system(size: 18, weight: .bold))
                Spacer()
                if canInviteOrRemove {
                    Button { showInvite = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 34, height: 34)
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.pressable)
                    .background(Tokens.slate500, in: Circle())
                }
            }
            .padding(.horizontal, 4).padding(.top, 4)

            // Answers "what do these roles apply to?" up front: workspace-wide,
            // as opposed to the per-project access set inside each project.
            Text(tr("permissions.scope_note"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 4)

            if let lastError = repositoryApp.lastError {
                infoBanner(
                    icon: "exclamationmark.shield.fill",
                    tint: Tokens.rejected,
                    title: tr("common.error"),
                    message: lastError
                )
            }

            // Role count grid
            let counts = Dictionary(grouping: members, by: \.role)
            HStack(spacing: 8) {
                ForEach(roles, id: \.self) { r in
                    GlassCard(padding: 10) {
                        VStack(spacing: 1) {
                            Text("\(counts[r]?.count ?? 0)").font(.system(size: 18, weight: .bold))
                            Text(tr("role.\(r.rawValue)")).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            Text(tr("permissions.members")).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(members.enumerated()), id: \.element.id) { idx, m in
                        if idx > 0 { Divider().opacity(0.4) }
                        memberRow(m)
                    }
                }
            }

            if canInviteOrRemove && !repositoryApp.invites.isEmpty {
                Text(tr("permissions.invites")).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)
                GlassCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(repositoryApp.invites.enumerated()), id: \.element.id) { idx, invite in
                            if idx > 0 { Divider().opacity(0.4) }
                            inviteRow(invite)
                        }
                    }
                }
            }

            Text(tr("permissions.role_capabilities")).font(.system(size: 13, weight: .semibold)).padding(.horizontal, 4)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    roleCapabilityRow(tr("role.employee"), icon: "person.fill", tint: Tokens.slate500,
                                      description: tr("role.employee.description"))
                    Divider().opacity(0.4)
                    roleCapabilityRow(tr("role.manager"), icon: "checkmark.shield.fill", tint: Tokens.approved,
                                      description: tr("role.manager.description"))
                    Divider().opacity(0.4)
                    roleCapabilityRow(tr("role.finance"), icon: "banknote.fill", tint: Tokens.aiPurple,
                                      description: tr("role.finance.description"))
                    Divider().opacity(0.4)
                    roleCapabilityRow(tr("role.admin"), icon: "crown.fill", tint: Tokens.pending,
                                      description: tr("role.admin.description"))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(isPresented: $showInvite) {
            InviteMemberSheet(
                availableRoles: editableRoles,
                projects: repositoryApp.projects.filter { !$0.isArchived }
            ) { email, role, projectId, projectRole in
                Task {
                    await repositoryApp.inviteMember(
                        email: email, role: role,
                        projectId: projectId, projectRole: projectRole
                    )
                }
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(tr("permissions.confirm_remove.title", memberToRemove?.displayName ?? tr("role.member")), isPresented: $showRemoveConfirm, titleVisibility: .visible) {
            Button(tr("permissions.remove"), role: .destructive) {
                if let memberToRemove {
                    Task { await repositoryApp.removeMember(id: memberToRemove.id) }
                }
            }
            Button(tr("common.cancel"), role: .cancel) {}
        } message: {
            Text(tr("permissions.confirm_remove.message"))
        }
        // Fresh fetch on every entry so admins see the up-to-date member +
        // invite list. Throttled (20s) so re-entering quickly is a no-op.
        .task {
            await repositoryApp.refreshIfStale()
        }
    }

    /// Renders a single pending invite. The 6-digit code is the headline since
    /// that's what the admin needs to read out to the invitee; email + role are
    /// secondary metadata.
    private func inviteRow(_ invite: WorkspaceInvite) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "envelope.badge.fill")
                    .foregroundStyle(Tokens.pending)
                    .frame(width: 32, height: 32)
                    .background(Tokens.pending.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 1) {
                    Text(invite.email).font(.system(size: 13.5, weight: .medium)).lineLimit(1)
                    Text(tr("role.\(invite.role.rawValue)"))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(tr("common.cancel")) {
                    Task { await repositoryApp.cancelInvite(id: invite.id) }
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Tokens.rejected)
            }

            // Code + copy. Tapping the row copies; the chip on the right is
            // a redundant affordance so users discover the tap target.
            Button {
                UIPasteboard.general.string = invite.code
            } label: {
                HStack(spacing: 12) {
                    Text(invite.code)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(Color.primary)
                    Spacer()
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(tr("permissions.invite.copy"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Tokens.slate500)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.pressable)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private func roleCapabilityRow(_ title: String, icon: String, tint: Color, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(description).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }

    private func memberRow(_ m: DomainWorkspaceMember) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Avatar(color: m.avatarColor, size: 36, label: m.initials)
                VStack(alignment: .leading, spacing: 1) {
                    Text(m.displayName).font(.system(size: 13, weight: .semibold))
                    Text(m.email).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                if canEditRoles && !isLastActiveAdmin(m) {
                    Button {
                        editingID = editingID == m.id ? nil : m.id
                    } label: {
                        Text(tr("role.\(m.role.rawValue)"))
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 11).padding(.vertical, 5)
                            .background(Color.primary.opacity(0.07), in: Capsule())
                            .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                    }
                    .buttonStyle(.pressable)
                } else {
                    HStack(spacing: 4) {
                        if isLastActiveAdmin(m) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.tertiary)
                        }
                        Text(tr("role.\(m.role.rawValue)"))
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .padding(.horizontal, 11).padding(.vertical, 5)
                    .background(Color.primary.opacity(0.07), in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                }
                if canInviteOrRemove && !isLastActiveAdmin(m) {
                    Button {
                        memberToRemove = m
                        showRemoveConfirm = true
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Tokens.rejected)
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 12)

            if editingID == m.id, canEditRoles, !isLastActiveAdmin(m) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(editableRoles, id: \.self) { r in
                            Button {
                                Task { await repositoryApp.updateMemberRole(id: m.id, role: r) }
                                editingID = nil
                            } label: {
                                Text(tr("role.\(r.rawValue)"))
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(m.role == r ? .white : .primary)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                            }
                            .buttonStyle(.pressable)
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
    let availableRoles: [WorkspaceRole]
    /// Active projects the admin can scope this invite to. Empty → the
    /// project-scope picker is hidden entirely and the invite stays
    /// workspace-only.
    let projects: [DomainProject]
    /// (email, workspaceRole, projectId?, projectRole?) — project args are
    /// nil for workspace-only invites and both non-nil for project-scoped.
    var onInvite: (String, WorkspaceRole, String?, ProjectRole?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var role: WorkspaceRole = .employee
    @State private var scopedProjectId: String? = nil
    @State private var scopedProjectRole: ProjectRole = .submitter

    var body: some View {
        SheetScaffold(
            header: { SheetHeader(title: tr("permissions.invite_member"), onClose: { dismiss() }) },
            content: {
                VStack(alignment: .leading, spacing: 16) {
                    GlassCard(padding: Tokens.padCard) {
                        VStack(spacing: 0) {
                            HStack {
                                Text(tr("permissions.invite.email")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                                Spacer()
                                TextField("teammate@company.com", text: $email)
                                    .font(.system(size: 13.5, weight: .medium))
                                    .textInputAutocapitalization(.never)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 210)
                            }
                            .padding(.vertical, 11)
                            Divider().opacity(0.4)
                            HStack {
                                Text(tr("permissions.invite.role")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                                Spacer()
                                Picker(tr("permissions.invite.role"), selection: $role) {
                                    ForEach(availableRoles, id: \.self) { r in
                                        Text(tr("role.\(r.rawValue)")).tag(r)
                                    }
                                }
                                .pickerStyle(.menu)
                                .font(.system(size: 13.5, weight: .medium))
                            }
                            .padding(.vertical, 11)
                        }
                    }

                    // Optional project scoping. When a project is picked, the
                    // invitee will also become a member of that project at the
                    // chosen project role when they accept the code. Defaults to
                    // workspace-only ("No specific project").
                    if !projects.isEmpty {
                        GlassCard(padding: Tokens.padCard) {
                            VStack(spacing: 0) {
                                HStack {
                                    Text(tr("permissions.invite.project")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                                    Spacer()
                                    Menu {
                                        Button(tr("permissions.invite.no_project")) { scopedProjectId = nil }
                                        Divider()
                                        ForEach(projects, id: \.id) { p in
                                            Button(p.name) { scopedProjectId = p.id }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(scopedProjectName).font(.system(size: 13.5, weight: .medium))
                                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .semibold))
                                        }
                                        .foregroundStyle(Color.primary)
                                    }
                                }
                                .padding(.vertical, 11)
                                if scopedProjectId != nil {
                                    Divider().opacity(0.4)
                                    HStack {
                                        Text(tr("projects.member.role")).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                                        Spacer()
                                        Picker(tr("projects.member.role"), selection: $scopedProjectRole) {
                                            ForEach(ProjectRole.allCases, id: \.self) { r in
                                                Text(r.label).tag(r)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        .font(.system(size: 13.5, weight: .medium))
                                    }
                                    .padding(.vertical, 11)
                                }
                            }
                        }
                    }

                    infoBanner(icon: "clock.badge.fill", tint: Tokens.pending,
                               title: tr("permissions.invites"),
                               message: tr("setup.workspace.invite_required.message"))
                }
            },
            footer: {
                Button {
                    onInvite(email, role, scopedProjectId, scopedProjectId != nil ? scopedProjectRole : nil)
                    dismiss()
                } label: {
                    Text(tr("permissions.invite.send")).primaryActionLabel()
                }
                .buttonStyle(.pressable)
                .disabled(!canSend)
            }
        )
    }

    private var scopedProjectName: String {
        guard let id = scopedProjectId,
              let project = projects.first(where: { $0.id == id }) else {
            return tr("permissions.invite.no_project")
        }
        return project.name
    }

    /// Treat anything without "name@domain" shape as not-yet-ready. Stops
    /// the previous fallback that invited a fake `new.member@company.com`
    /// when the field was empty.
    private var canSend: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let at = trimmed.firstIndex(of: "@"),
              at != trimmed.startIndex,
              at != trimmed.index(before: trimmed.endIndex) else { return false }
        let domain = trimmed[trimmed.index(after: at)...]
        return domain.contains(".")
    }
}

struct ToggleRow: View {
    let label: String
    var sub: String? = nil
    @Binding var isOn: Bool

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
