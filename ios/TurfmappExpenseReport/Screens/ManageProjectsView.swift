import SwiftUI

struct ManageProjectsView: View {
    @EnvironmentObject var app: AppState
    @State private var showCreate = false
    @State private var editingThresholdFor: Project? = nil
    @State private var viewingProject: Project? = nil
    @State private var projectName = ""
    @State private var projectBudget = ""
    @State private var projectOwner = ""
    @State private var projectThreshold = "100"
    @State private var projectVisibility = "Team"
    var onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain).glassSurface(corner: 999)

                Text("Manage projects").font(.system(size: 18, weight: .bold))
                Spacer()
                Button {
                    projectName = ""
                    projectBudget = ""
                    projectOwner = app.userName
                    projectThreshold = "100"
                    projectVisibility = "Team"
                    showCreate.toggle()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 34, height: 34)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .background(Tokens.slate500, in: Circle())
            }
            .padding(.horizontal, 4).padding(.top, 4)

            if showCreate {
                createForm
            }

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(app.currentProjects.enumerated()), id: \.element.id) { idx, p in
                        if idx > 0 { Divider().opacity(0.4) }
                        projectRow(p)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 100)
        .sheet(item: $editingThresholdFor) { project in
            ThresholdEditorSheet(project: project) { newValue in
                app.setProjectThreshold(id: project.id, to: newValue)
            }
            .presentationDetents([.height(280)])
        }
        .sheet(item: $viewingProject) { project in
            ProjectDetailSheet(project: project)
                .environmentObject(app)
                .presentationDetents([.medium])
        }
    }

    private func projectRow(_ p: Project) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                viewingProject = p
            } label: {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4).fill(p.color).frame(width: 6, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(p.name).font(.system(size: 13.5, weight: .semibold))
                        Text("\(p.owner) · \(p.visibility)")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            HStack {
                Text("$\(Int(p.spent / 1000))k spent")
                Spacer()
                Text("$\(Int(p.budget / 1000))k budget")
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)

            ProgressView(value: p.progress).progressViewStyle(.linear).tint(p.color)

            Button { editingThresholdFor = p } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Tokens.approved)
                    Text("Auto-approve under")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(money(p.autoApproveThreshold))
                        .font(.system(size: 13, weight: .semibold))
                    Image(systemName: "pencil")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(10)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private var createForm: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("New project").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button { showCreate = false } label: {
                        Image(systemName: "xmark").foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 10)

                createField("Name", text: $projectName, placeholder: "Untitled project")
                Divider().opacity(0.4)
                createField("Budget", text: $projectBudget, placeholder: "25000", prefix: "$")
                Divider().opacity(0.4)
                createField("Owner", text: $projectOwner, placeholder: app.userName)
                Divider().opacity(0.4)
                createField("Auto-approve under", text: $projectThreshold, placeholder: "100", prefix: "$")

                Text("Visibility")
                    .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                    .padding(.top, 12).padding(.bottom, 6)

                ForEach(["Private", "Team", "Org-wide"], id: \.self) { v in
                    Button {
                        projectVisibility = v
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                Circle().strokeBorder(Color.secondary.opacity(0.4), lineWidth: 1.5).frame(width: 18, height: 18)
                                if v == projectVisibility {
                                    Circle().fill(Tokens.slate500).frame(width: 9, height: 9)
                                }
                            }
                            Text(v).font(.system(size: 13))
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    app.addProject(
                        name: projectName,
                        budget: Double(projectBudget) ?? 0,
                        owner: projectOwner,
                        visibility: projectVisibility,
                        threshold: Double(projectThreshold) ?? 100
                    )
                    showCreate = false
                } label: {
                    Text("Create project")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 12))
                .padding(.top, 10)
            }
        }
    }

    private func createField(_ label: String, text: Binding<String>, placeholder: String, prefix: String = "") -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            if !prefix.isEmpty {
                Text(prefix).font(.system(size: 13.5, weight: .medium)).foregroundStyle(.secondary)
            }
            TextField(placeholder, text: text)
                .font(.system(size: 13.5, weight: .medium))
                .multilineTextAlignment(.trailing)
                .keyboardType(prefix == "$" ? .numberPad : .default)
                .frame(maxWidth: 180)
        }
        .padding(.vertical, 11)
    }
}

// MARK: – Threshold editor sheet

struct ThresholdEditorSheet: View {
    let project: Project
    var onSave: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String

    init(project: Project, onSave: @escaping (Double) -> Void) {
        self.project = project
        self.onSave = onSave
        _amountText = State(initialValue: String(format: "%.0f", project.autoApproveThreshold))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Auto-approve threshold").font(.system(size: 18, weight: .bold))
                Text(project.name).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .padding(.top, 24).padding(.horizontal, 20)

            Text("Expenses at or below this amount on this project will skip manager approval.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)

            HStack {
                Text("$").font(.system(size: 28, weight: .bold)).foregroundStyle(.secondary)
                TextField("0", text: $amountText)
                    .font(.system(size: 36, weight: .bold))
                    .keyboardType(.numberPad)
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                if let v = Double(amountText), v >= 0 { onSave(v) }
                dismiss()
            } label: {
                Text("Save").primaryActionLabel()
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }
}

struct ProjectDetailSheet: View {
    let project: Project
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name).font(.system(size: 20, weight: .bold))
                    Text("\(project.owner) · \(project.visibility)").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .background(Color.primary.opacity(0.06), in: Circle())
            }
            .padding(.top, 24).padding(.horizontal, 20)

            VStack(spacing: 0) {
                FormFieldRow(label: "Budget", value: money(project.budget), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: "Spent", value: money(project.spent), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: "Auto-approve under", value: money(project.autoApproveThreshold), showChevron: false)
                Divider().opacity(0.4)
                FormFieldRow(label: "Visibility", value: project.visibility.capitalized, showChevron: false)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 10) {
                Text("Assigned members")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                HStack(spacing: -8) {
                    ForEach(app.currentMembers.prefix(4)) { member in
                        Avatar(color: member.avatarColor, size: 34, label: member.initials)
                            .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1))
                    }
                    Spacer()
                    Text("\(app.currentMembers.count) total")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 20)

            infoBanner(icon: "slider.horizontal.3", tint: Tokens.slate500,
                       title: "Project policy",
                       message: "Project-level policy overrides workspace defaults for approval threshold, visibility, and assigned members.")
                .padding(.horizontal, 20)

            infoBanner(icon: "archivebox.fill", tint: Tokens.pending,
                       title: "Archive state covered",
                       message: "A production project detail should support archive/delete confirmation before hiding a project.")
                .padding(.horizontal, 20)

            Spacer()
        }
    }
}
