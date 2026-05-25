import SwiftUI
import UIKit

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
    ///
    /// Adapts to light and dark mode:
    /// - Light: soft cool-gray gradient (#EEF1F8 → #E4E8F2) with slate +
    ///   purple ambient blobs. Materials read as off-white over this.
    /// - Dark: deep slate gradient (#0E1117 → #1A1F2C) with dimmer blobs.
    ///   Materials read as off-black, and Color.primary (now white) has
    ///   enough contrast against the dark base.
    ///
    /// Without this adaptation the gradient stayed light in dark mode, which
    /// pushed system materials toward a too-bright translucent grey and made
    /// any text using Color.primary (now white) hard to read.
    func appBackground() -> some View {
        self.background(
            ZStack {
                LinearGradient(
                    colors: [
                        Color.appBackgroundTop,
                        Color.appBackgroundBottom
                    ],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Tokens.slate500.opacity(0.35))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: 120, y: -260)

                Circle()
                    .fill(Tokens.aiPurple.opacity(0.28))
                    .frame(width: 240, height: 240)
                    .blur(radius: 60)
                    .offset(x: -120, y: 200)
            }
        )
    }
}

extension Color {
    /// Two-stop background gradient that flips between light and dark mode.
    /// Defined via UIColor's `init(dynamicProvider:)` so SwiftUI re-resolves
    /// the colour automatically when the trait collection changes (manual
    /// override, system setting, time-of-day, etc.).
    static let appBackgroundTop = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 14/255,  green: 17/255,  blue: 23/255,  alpha: 1)   // #0E1117
            : UIColor(red: 238/255, green: 241/255, blue: 248/255, alpha: 1)   // #EEF1F8
    })

    static let appBackgroundBottom = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 26/255,  green: 31/255,  blue: 44/255,  alpha: 1)   // #1A1F2C
            : UIColor(red: 228/255, green: 232/255, blue: 242/255, alpha: 1)   // #E4E8F2
    })
}
