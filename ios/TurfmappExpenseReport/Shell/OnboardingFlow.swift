import SwiftUI
import PhotosUI

// MARK: – Progress chrome

/// Top-of-screen progress indicator shared by every onboarding step.
///
/// Shows three connected dots (filled up to `current`) plus a small "Step N
/// of 3" label. We render the dots manually rather than using `ProgressView`
/// so the visual matches the glass / pill aesthetic used elsewhere.
struct OnboardingProgress: View {
    let current: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(tr("onboarding.step.label", current, total))
                .font(.system(size: 10.5, weight: .bold))
                .tracking(0.8)
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                ForEach(0..<total, id: \.self) { index in
                    Capsule()
                        .fill(index < current ? Tokens.slate500 : Color.primary.opacity(0.12))
                        .frame(height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 12)
    }
}

// MARK: – Step 0: Welcome

struct WelcomeView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onGetStarted: () -> Void
    var onSignIn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 60)

            // Big app glyph — matches the light AppIcon
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(LinearGradient(
                        colors: [Tokens.slate500, Tokens.aiPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 96, height: 96)
                    .shadow(color: Tokens.aiPurple.opacity(0.25), radius: 24, y: 12)
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .leading, spacing: 8) {
                Text(tr("onboarding.welcome.title"))
                    .font(.system(size: 34, weight: .bold))
                Text(tr("onboarding.welcome.subtitle"))
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            GlassCard(padding: Tokens.padCard) {
                VStack(alignment: .leading, spacing: 14) {
                    featureRow(icon: "sparkles", tint: Tokens.aiPurple,
                               title: tr("onboarding.welcome.feature.scan.title"),
                               subtitle: tr("onboarding.welcome.feature.scan.subtitle"))
                    featureRow(icon: "chart.line.uptrend.xyaxis", tint: Tokens.approved,
                               title: tr("onboarding.welcome.feature.approve.title"),
                               subtitle: tr("onboarding.welcome.feature.approve.subtitle"))
                    featureRow(icon: "person.3.fill", tint: Tokens.slate500,
                               title: tr("onboarding.welcome.feature.workspace.title"),
                               subtitle: tr("onboarding.welcome.feature.workspace.subtitle"))
                }
            }

            Spacer()

            VStack(spacing: 10) {
                // Social sign-in is the fastest path for new users, so we
                // surface it directly on the welcome screen. After a
                // successful flow the repository has already loaded the
                // session; we just flip app.signIn and let the router move
                // us to ProfileSetup (or straight to Home if a workspace
                // already exists for this user).
                SocialAuthButtons(
                    onGoogle: {
                        Task {
                            let ok = await repositoryApp.signInWithGoogle()
                            if ok { finishSocialSignIn() }
                        }
                    },
                    onApple: {
                        Task {
                            let ok = await repositoryApp.signInWithApple()
                            if ok { finishSocialSignIn() }
                        }
                    }
                )

                Button(action: onGetStarted) {
                    Text(tr("onboarding.welcome.get_started"))
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Tokens.slate500)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5))
                }
                .buttonStyle(.plain)

                Button(action: onSignIn) {
                    Text(tr("onboarding.welcome.have_account"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.slate500)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 22)
    }

    private func finishSocialSignIn() {
        guard repositoryApp.lastError == nil else { return }
        let signedInEmail = repositoryApp.currentUserProfile?.email ?? ""
        app.signIn(email: signedInEmail, needsSetup: repositoryApp.workspaces.isEmpty)
        if let workspace = repositoryApp.selectedWorkspace {
            app.company = workspace.legacyCompany
            app.role = workspace.currentUserRole.appRole
        }
    }

    private func featureRow(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(
                    LinearGradient(colors: [tint, tint.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 10)
                )
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13.5, weight: .semibold))
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: – Step 1: Profile

struct ProfileSetupView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    @State private var name = ""
    @State private var nickname = ""
    @State private var avatarPick: PhotosPickerItem? = nil
    @State private var avatarPreviewData: Data? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingProgress(current: 1, total: 2)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Spacer(minLength: 24)

                    Text(tr("setup.profile.title")).font(.system(size: 30, weight: .bold))
                    Text(tr("setup.profile.subtitle"))
                        .font(.system(size: 14)).foregroundStyle(.secondary)

                    // Avatar picker — circular tile in a glass card to keep
                    // the upload affordance visible without crowding the form.
                    GlassCard(padding: Tokens.padCard) {
                        HStack(spacing: 14) {
                            PhotosPicker(selection: $avatarPick, matching: .images) {
                                avatarPreview
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(tr("setup.profile.avatar.title"))
                                    .font(.system(size: 13.5, weight: .semibold))
                                Text(tr("setup.profile.avatar.subtitle"))
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    GlassCard(padding: Tokens.padCard) {
                        VStack(spacing: 0) {
                            setupField(tr("setup.profile.fullname"), placeholder: tr("setup.profile.fullname.placeholder"), text: $name)
                            Divider().opacity(0.4)
                            setupField(tr("setup.profile.nickname"), placeholder: tr("setup.profile.nickname.placeholder"), text: $nickname)
                        }
                    }

                    if let saveError {
                        infoBanner(icon: "exclamationmark.triangle.fill", tint: Tokens.rejected,
                                   title: tr("setup.profile.save_failed"),
                                   message: saveError)
                    }

                    Button { Task { await saveProfile() } } label: {
                        HStack(spacing: 8) {
                            if isSaving { ProgressView().tint(.white).scaleEffect(0.8) }
                            Text(tr("common.continue"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity).padding(16)
                        .background(Tokens.slate500, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 22)
            }
        }
        .onChange(of: avatarPick) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run { avatarPreviewData = data }
                }
            }
        }
        .task {
            // Pre-fill from existing profile so a user who interrupts onboarding
            // doesn't retype their name on relaunch.
            if let profile = repositoryApp.currentUserProfile {
                if name.isEmpty { name = profile.displayName }
            }
        }
    }

    private var avatarPreview: some View {
        ZStack {
            if let data = avatarPreviewData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Tokens.slate500.opacity(0.12))
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Tokens.slate500)
                    )
            }
        }
        .overlay(
            Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
        )
    }

    private func saveProfile() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSaving = true
        saveError = nil
        defer { isSaving = false }

        // Persist display name to Supabase. updateDisplayName returns false on
        // failure and the error is already captured in repositoryApp.lastError.
        let ok = await repositoryApp.updateDisplayName(trimmed)
        guard ok else {
            saveError = repositoryApp.lastError ?? tr("setup.profile.save_failed")
            return
        }

        // Avatar is optional; failure here doesn't block the flow — we just
        // log it and continue. The user can re-try from the profile screen later.
        if let data = avatarPreviewData {
            _ = await repositoryApp.setUserAvatar(data: data, contentType: "image/jpeg", fileExtension: "jpg")
        }

        await MainActor.run {
            app.completeProfile(name: trimmed, nickname: nickname)
        }
    }

    private func setupField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        HStack {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
            Spacer()
            TextField(placeholder, text: text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 220)
        }
        .padding(.vertical, 12)
    }
}

// MARK: – Step 3: Completion

struct OnboardingCompletionView: View {
    @EnvironmentObject var app: AppState
    @EnvironmentObject var repositoryApp: RepositoryAppState
    var onSubmitExpense: () -> Void
    var onInviteTeammate: () -> Void
    var onBrowseSettings: () -> Void
    var onGoHome: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer(minLength: 60)

            // Confetti-ish badge — sparkle in a gradient circle.
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Tokens.approved, Tokens.aiPurple],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 84, height: 84)
                    .shadow(color: Tokens.approved.opacity(0.3), radius: 20, y: 10)
                Image(systemName: "checkmark")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .center, spacing: 4) {
                Text(tr("onboarding.done.title")).font(.system(size: 28, weight: .bold))
                Text(workspaceSummary).font(.system(size: 13)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    actionTile(
                        icon: "camera.viewfinder",
                        tint: Tokens.aiPurple,
                        title: tr("onboarding.done.action.submit"),
                        subtitle: tr("onboarding.done.action.submit.subtitle"),
                        action: onSubmitExpense
                    )
                    Divider().opacity(0.4)
                    actionTile(
                        icon: "person.crop.circle.badge.plus",
                        tint: Tokens.approved,
                        title: tr("onboarding.done.action.invite"),
                        subtitle: tr("onboarding.done.action.invite.subtitle"),
                        action: onInviteTeammate
                    )
                    Divider().opacity(0.4)
                    actionTile(
                        icon: "gearshape.fill",
                        tint: Tokens.slate500,
                        title: tr("onboarding.done.action.settings"),
                        subtitle: tr("onboarding.done.action.settings.subtitle"),
                        action: onBrowseSettings
                    )
                }
            }

            Spacer()

            Button(action: onGoHome) {
                Text(tr("onboarding.done.go_home")).primaryActionLabel()
            }
            .buttonStyle(.plain)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 22)
    }

    private var workspaceSummary: String {
        let name = repositoryApp.selectedWorkspace?.name ?? app.company.name
        let currency = repositoryApp.selectedWorkspace?.defaultCurrency ?? "USD"
        return "\(name) · \(currency)"
    }

    private func actionTile(icon: String, tint: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        LinearGradient(colors: [tint, tint.opacity(0.75)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 10)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(Color.primary)
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }
}
