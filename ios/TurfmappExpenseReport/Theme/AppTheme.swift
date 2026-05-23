import SwiftUI

enum AppRole: String, CaseIterable, Identifiable {
    case employee, manager, finance, admin
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var needsSetup: Bool = false
    @Published var profileComplete: Bool = false
    @Published var workspaceReady: Bool = false
    @Published var userName: String = ""
    @Published var userNickname: String = ""
    @Published var userEmail: String = ""
    @Published var role: AppRole = .employee
    @Published var company: Company = AppState.defaultCompany

    /// Neutral placeholder used until a real workspace is selected. The app no
    /// longer ships any mock workspace data.
    static let defaultCompany = Company(id: "", name: "Workspace", abbr: "WS", color: Tokens.slate500)

    func signIn(email: String, needsSetup: Bool = false, role: AppRole? = nil) {
        userEmail = email.isEmpty ? userEmail : email
        isAuthenticated = true
        self.needsSetup = needsSetup
        if !needsSetup {
            profileComplete = true
            workspaceReady = true
            self.role = role ?? .employee
        }
    }

    func signOut() {
        isAuthenticated = false
        needsSetup = false
        profileComplete = false
        workspaceReady = false
        role = .employee
        company = AppState.defaultCompany
    }

    func completeProfile(name: String, nickname: String) {
        userName = name.isEmpty ? userName : name
        userNickname = nickname.isEmpty ? userNickname : nickname
        profileComplete = true
        role = .employee
    }

    /// Rewind from WorkspaceSetup back to ProfileSetup. The saved name + avatar
    /// stay (RepositoryAppState already wrote them to Supabase) so the user
    /// just sees their values pre-filled when ProfileSetup re-renders.
    func returnToProfileSetup() {
        profileComplete = false
        workspaceReady = false
        needsSetup = true
    }
}

extension View {
    /// Background appropriate for the app — provides content for liquid glass to refract.
    func appBackground() -> some View {
        self.background(
            ZStack {
                LinearGradient(colors: [
                    Color(hex: 0xEEF1F8),
                    Color(hex: 0xE4E8F2)
                ], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

                Circle()
                    .fill(Tokens.slate500.opacity(0.45))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 120, y: -260)

                Circle()
                    .fill(Tokens.aiPurple.opacity(0.35))
                    .frame(width: 240, height: 240)
                    .blur(radius: 60)
                    .offset(x: -120, y: 200)
            }
        )
    }
}
