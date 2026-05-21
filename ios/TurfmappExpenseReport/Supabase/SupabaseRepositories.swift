import Foundation
import CryptoKit

struct RepositoryContainer: Sendable {
    let auth: any AuthRepository
    let workspaces: any WorkspaceRepository
    let projects: any ProjectRepository
    let expenses: any ExpenseRepository
    let attachments: any AttachmentRepository
    let receiptScans: any ReceiptScanRepository

    static func configured() -> RepositoryContainer {
        guard let url = AppEnvironment.supabaseURL,
              let key = AppEnvironment.supabasePublishableKey else {
            // A release build must never silently serve mock data. If the
            // Supabase credentials are missing every call surfaces a clear
            // "not configured" error through the existing error banners.
            #if DEBUG
            return mock()
            #else
            return notConfigured()
            #endif
        }

        let client = SupabaseRESTClient(baseURL: url, anonKey: key)
        return RepositoryContainer(
            auth: SupabaseAuthRepository(client: client),
            workspaces: SupabaseWorkspaceRepository(client: client),
            projects: SupabaseProjectRepository(client: client),
            expenses: SupabaseExpenseRepository(client: client),
            attachments: SupabaseAttachmentRepository(client: client),
            receiptScans: SupabaseReceiptScanRepository(client: client, functionName: AppEnvironment.receiptScanFunctionName)
        )
    }

    static func mock() -> RepositoryContainer {
        let container = MockRepositoryContainer.make()
        return RepositoryContainer(
            auth: container.auth,
            workspaces: container.workspaces,
            projects: container.projects,
            expenses: container.expenses,
            attachments: container.attachments,
            receiptScans: container.receiptScans
        )
    }

    static func notConfigured() -> RepositoryContainer {
        let stub = NotConfiguredRepository()
        return RepositoryContainer(
            auth: stub,
            workspaces: stub,
            projects: stub,
            expenses: stub,
            attachments: stub,
            receiptScans: stub
        )
    }
}

/// Every call fails with `.notConfigured` so a misconfigured release build
/// shows an actionable error instead of fabricated data.
struct NotConfiguredRepository: AuthRepository, WorkspaceRepository, ProjectRepository, ExpenseRepository, AttachmentRepository, ReceiptScanRepository {
    private var error: SupabaseRepositoryError { .notConfigured }

    func signIn(email: String, password: String) async throws { throw error }
    func signUp(email: String, password: String) async throws { throw error }
    func signOut() async throws { throw error }
    func hasPersistedSession() async -> Bool { false }
    func currentUserId() async throws -> String? { throw error }
    func currentUserProfile() async throws -> DomainUserProfile? { throw error }
    func updateDisplayName(_ name: String) async throws { throw error }
    func updateAvatarUrl(_ url: String?) async throws { throw error }
    func uploadBrandingImage(path: String, contentType: String, data: Data) async throws -> String { throw error }
    func sendPasswordResetEmail(_ email: String) async throws { throw error }
    func updatePassword(_ newPassword: String) async throws { throw error }
    func signOutAllSessions() async throws { throw error }

    func listWorkspacesForCurrentUser() async throws -> [DomainWorkspace] { throw error }
    func listMembers(workspaceId: String) async throws -> [DomainWorkspaceMember] { throw error }
    func listInvites(workspaceId: String) async throws -> [WorkspaceInvite] { throw error }
    func listCategories(workspaceId: String) async throws -> [DomainCategory] { throw error }
    func createWorkspace(name: String, defaultCurrency: String) async throws -> DomainWorkspace { throw error }
    func acceptInvite(id: String) async throws -> DomainWorkspace { throw error }
    func inviteMember(workspaceId: String, email: String, role: WorkspaceRole) async throws -> WorkspaceInvite { throw error }
    func cancelInvite(id: String) async throws { throw error }
    func updateMemberRole(id: String, role: WorkspaceRole) async throws -> DomainWorkspaceMember { throw error }
    func removeMember(id: String) async throws { throw error }
    func listNotifications(workspaceId: String) async throws -> [DomainNotification] { throw error }
    func markNotificationRead(id: String) async throws { throw error }
    func updateWorkspaceLogo(workspaceId: String, logoUrl: String?) async throws -> DomainWorkspace { throw error }
    func updateWorkspace(workspaceId: String, name: String, defaultCurrency: String) async throws -> DomainWorkspace { throw error }

    func listProjects(workspaceId: String) async throws -> [DomainProject] { throw error }
    func createProject(_ project: DomainProject) async throws -> DomainProject { throw error }
    func updateProject(_ project: DomainProject) async throws -> DomainProject { throw error }
    func archiveProject(id: String) async throws { throw error }

    func listExpenses(filters: ExpenseFilters) async throws -> [DomainExpense] { throw error }
    func listEvents(expenseId: String) async throws -> [ExpenseWorkflowEvent] { throw error }
    func createDraft(_ input: ExpenseDraftInput) async throws -> DomainExpense { throw error }
    func updateDraft(id: String, _ input: ExpenseDraftInput) async throws -> DomainExpense { throw error }
    func backfillFXSnapshot(id: String, amount: MoneyAmount, baseCurrency: String, date: Date) async throws -> DomainExpense { throw error }
    func submitExpense(id: String) async throws -> DomainExpense { throw error }
    func resubmitExpense(id: String) async throws -> DomainExpense { throw error }
    func cancelExpense(id: String, reason: String?) async throws -> DomainExpense { throw error }
    func approveExpense(id: String, note: String?) async throws -> DomainExpense { throw error }
    func rejectExpense(id: String, reason: String) async throws -> DomainExpense { throw error }
    func confirmPurchase(id: String, input: PurchaseConfirmationInput) async throws -> DomainExpense { throw error }
    func markReimbursed(id: String, input: ReimbursementInput) async throws -> DomainExpense { throw error }
    func archiveExpense(id: String) async throws -> DomainExpense { throw error }
    func unarchiveExpense(id: String) async throws -> DomainExpense { throw error }
    func deleteExpense(id: String) async throws { throw error }

    func listAttachments(expenseId: String) async throws -> [ExpenseAttachment] { throw error }
    func uploadAttachment(expenseId: String, kind: ExpenseAttachment.Kind, fileName: String, contentType: String, data: Data) async throws -> ExpenseAttachment { throw error }
    func deleteAttachment(id: String) async throws { throw error }

    func startScan(attachmentId: String) async throws -> ReceiptScanResult { throw error }
    func getScanResult(id: String) async throws -> ReceiptScanResult { throw error }
    func confirmScanField(scanId: String, fieldId: String, normalizedValue: String) async throws -> ReceiptScanResult { throw error }
}

enum SupabaseRepositoryError: LocalizedError {
    case notConfigured
    case missingSession
    case confirmationRequired
    case unsupported(String)
    case requestFailed(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase is not configured."
        case .missingSession:
            return "Sign in before using this workspace."
        case .confirmationRequired:
            return "Check your email to confirm this account, then sign in."
        case .unsupported(let feature):
            return "\(feature) is not connected to Supabase yet."
        case .requestFailed(let status, let message):
            // Supabase error bodies are typically JSON like {"msg": "...", "error_code": "..."}.
            // Surface that human message when present; fall back to the raw body otherwise.
            if let data = message.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let msg = json["msg"] as? String ?? json["message"] as? String ?? json["error_description"] as? String {
                    return msg
                }
            }
            return "Request failed (\(status)). \(message)"
        case .invalidResponse:
            return "Supabase returned an unexpected response."
        }
    }
}

actor SupabaseRESTClient {
    struct AuthSession: Codable {
        let accessToken: String?
        let refreshToken: String?
        let user: AuthUser?
        /// Seconds until `accessToken` expires from the moment it was issued.
        /// Supabase returns this on every token grant; we use it (plus the
        /// time we saved) to know when to refresh.
        let expiresIn: Int?
        /// Wall-clock time at which we saved this session. Combined with
        /// `expiresIn` to derive a real expiration.
        var savedAt: Date?

        var expiresAt: Date? {
            guard let savedAt, let expiresIn else { return nil }
            return savedAt.addingTimeInterval(TimeInterval(expiresIn))
        }
    }

    struct AuthUser: Codable {
        let id: String
        let email: String?
    }

    let baseURL: URL
    let anonKey: String

    /// The expense app lives in its own Postgres schema (isolated from the
    /// shared `public` schema). Sent to PostgREST via Accept/Content-Profile.
    static let postgrestSchema = "turfmapp_expenses"

    private let sessionDefaultsKey = "supabase.auth.session"
    private var session: AuthSession?

    init(baseURL: URL, anonKey: String) {
        self.baseURL = baseURL
        self.anonKey = anonKey
        if let data = UserDefaults.standard.data(forKey: sessionDefaultsKey) {
            session = try? JSONDecoder().decode(AuthSession.self, from: data)
        }
    }

    func signIn(email: String, password: String) async throws {
        clearSession()
        let body = ["email": email, "password": password]
        let session: AuthSession = try await authRequest(path: "token?grant_type=password", body: body)
        guard session.accessToken?.isEmpty == false else {
            throw SupabaseRepositoryError.confirmationRequired
        }
        save(session)
    }

    func signUp(email: String, password: String) async throws {
        clearSession()
        let body = ["email": email, "password": password]
        let session: AuthSession = try await authRequest(path: "signup", body: body)
        if session.accessToken?.isEmpty == false {
            save(session)
        }
    }

    func signOut() {
        clearSession()
    }

    func sendPasswordResetEmail(_ email: String) async throws {
        let body = ["email": email]
        let _: EmptyResponse = try await authRequest(path: "recover", body: body)
    }

    func updatePassword(_ newPassword: String) async throws {
        let data = try JSONEncoder.supabase.encode(["password": newPassword])
        let _: EmptyResponse = try await request(path: "auth/v1/user", method: "PUT", body: data, requiresAuth: true)
    }

    func signOutAllSessions() async throws {
        let _: EmptyResponse = try await request(
            path: "auth/v1/logout",
            method: "POST",
            queryItems: [URLQueryItem(name: "scope", value: "global")],
            body: Data("{}".utf8),
            requiresAuth: true
        )
        clearSession()
    }

    private func clearSession() {
        session = nil
        UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
    }

    func currentUserId() -> String? {
        session?.user?.id ?? userIdFromJWT(session?.accessToken)
    }

    func hasAccessToken() -> Bool {
        session?.accessToken?.isEmpty == false
    }

    /// True when the persisted session looks usable: has a refresh token
    /// (we can always recover from an expired access token) OR has an
    /// access token that hasn't expired yet.
    func hasPersistedSession() -> Bool {
        guard let session else { return false }
        if let refresh = session.refreshToken, !refresh.isEmpty { return true }
        if let expiresAt = session.expiresAt { return expiresAt > Date().addingTimeInterval(30) }
        return session.accessToken?.isEmpty == false
    }

    /// Refresh the access token using the saved refresh token. Idempotent;
    /// callers don't need to know whether one is in flight. Throws if the
    /// refresh fails — caller should treat that as a hard sign-out signal.
    func refreshSessionIfNeeded() async throws {
        guard let current = session else { throw SupabaseRepositoryError.missingSession }
        // Refresh slightly before expiry so a long request started right at
        // the boundary doesn't fail.
        if let expiresAt = current.expiresAt, expiresAt > Date().addingTimeInterval(30) {
            return
        }
        guard let refreshToken = current.refreshToken, !refreshToken.isEmpty else {
            throw SupabaseRepositoryError.missingSession
        }
        let body = ["refresh_token": refreshToken]
        let session: AuthSession = try await authRequest(path: "token?grant_type=refresh_token", body: body)
        guard session.accessToken?.isEmpty == false else {
            throw SupabaseRepositoryError.missingSession
        }
        save(session)
    }

    func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem] = []) async throws -> T {
        try await request(path: "rest/v1/\(path)", method: "GET", queryItems: queryItems, body: Optional<Data>.none)
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        _ path: String,
        body: RequestBody,
        preferRepresentation: Bool = true
    ) async throws -> ResponseBody {
        let data = try JSONEncoder.supabase.encode(body)
        let headers = preferRepresentation ? ["Prefer": "return=representation"] : [:]
        return try await request(path: "rest/v1/\(path)", method: "POST", headers: headers, body: data)
    }

    func patch<RequestBody: Encodable, ResponseBody: Decodable>(
        _ path: String,
        body: RequestBody
    ) async throws -> ResponseBody {
        let data = try JSONEncoder.supabase.encode(body)
        return try await request(path: "rest/v1/\(path)", method: "PATCH", headers: ["Prefer": "return=representation"], body: data)
    }

    func rpc<RequestBody: Encodable, ResponseBody: Decodable>(_ name: String, body: RequestBody) async throws -> ResponseBody {
        let data = try JSONEncoder.supabase.encode(body)
        return try await request(path: "rest/v1/rpc/\(name)", method: "POST", body: data)
    }

    func invokeFunction<RequestBody: Encodable, ResponseBody: Decodable>(_ name: String, body: RequestBody) async throws -> ResponseBody {
        let data = try JSONEncoder.supabase.encode(body)
        return try await request(path: "functions/v1/\(name)", method: "POST", body: data)
    }

    /// Uploads raw bytes to a private Storage bucket. `objectPath` must be the
    /// full key within the bucket (e.g. "<workspace>/<expense>/<uuid>-name.jpg").
    func uploadStorageObject(bucket: String, objectPath: String, contentType: String, data: Data) async throws {
        guard let accessToken = session?.accessToken else { throw SupabaseRepositoryError.missingSession }
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedPath = objectPath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        guard let url = URL(string: "\(base)/storage/v1/object/\(bucket)/\(encodedPath)") else {
            throw SupabaseRepositoryError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = data
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseRepositoryError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseRepositoryError.requestFailed(http.statusCode, String(data: responseData, encoding: .utf8) ?? "")
        }
    }

    func publicStorageURL(bucket: String, objectPath: String) -> String {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let encodedPath = objectPath
            .split(separator: "/", omittingEmptySubsequences: false)
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? String($0) }
            .joined(separator: "/")
        return "\(base)/storage/v1/object/public/\(bucket)/\(encodedPath)"
    }

    func currentMembershipId(workspaceId: String) async throws -> String {
        struct Row: Decodable { let id: String }
        let rows: [Row] = try await get(
            "workspace_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let id = rows.first?.id else { throw SupabaseRepositoryError.missingSession }
        return id
    }

    private func authRequest<T: Decodable, Body: Encodable>(path: String, body: Body) async throws -> T {
        let data = try JSONEncoder.supabase.encode(body)
        return try await request(path: "auth/v1/\(path)", method: "POST", body: data, requiresAuth: false, decoder: .supabase)
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        body: Data?,
        requiresAuth: Bool = true,
        decoder: JSONDecoder = .supabase
    ) async throws -> T {
        let base = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var components = URLComponents(string: "\(base)/\(path)")
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else { throw SupabaseRepositoryError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requiresAuth {
            // Refresh transparently if the access token is at/past expiry.
            // We swallow refresh failures here so the original 401/403 from
            // the downstream call reaches the caller as a single signal.
            try? await refreshSessionIfNeeded()
            guard let accessToken = session?.accessToken else { throw SupabaseRepositoryError.missingSession }
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        // The expense schema lives in its own Postgres schema, not `public`,
        // so PostgREST needs the profile header to resolve tables/RPC.
        if path.hasPrefix("rest/v1/") {
            let profileHeader = (method == "GET" || method == "HEAD") ? "Accept-Profile" : "Content-Profile"
            request.setValue(Self.postgrestSchema, forHTTPHeaderField: profileHeader)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SupabaseRepositoryError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw SupabaseRepositoryError.requestFailed(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        return try decoder.decode(T.self, from: data)
    }

    private func save(_ session: AuthSession) {
        var stamped = session
        stamped.savedAt = Date()
        self.session = stamped
        if let data = try? JSONEncoder().encode(stamped) {
            UserDefaults.standard.set(data, forKey: sessionDefaultsKey)
        }
    }

    private func userIdFromJWT(_ token: String?) -> String? {
        guard let token,
              let payload = token.split(separator: ".").dropFirst().first else {
            return nil
        }
        var base64 = String(payload).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64 += "="
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json["sub"] as? String
    }
}

struct EmptyResponse: Decodable {}

struct SupabaseAuthRepository: AuthRepository {
    let client: SupabaseRESTClient

    func signIn(email: String, password: String) async throws {
        try await client.signIn(email: email, password: password)
    }

    func signUp(email: String, password: String) async throws {
        try await client.signUp(email: email, password: password)
        if await !client.hasAccessToken() {
            throw SupabaseRepositoryError.confirmationRequired
        }
    }

    func signOut() async throws {
        await client.signOut()
    }

    func hasPersistedSession() async -> Bool {
        await client.hasPersistedSession()
    }

    func currentUserId() async throws -> String? {
        await client.currentUserId()
    }

    func updateDisplayName(_ name: String) async throws {
        guard let uid = await client.currentUserId() else { throw SupabaseRepositoryError.missingSession }
        let _: [EmptyResponse] = try await client.patch("users?id=eq.\(uid)", body: ["display_name": name])
    }

    func currentUserProfile() async throws -> DomainUserProfile? {
        guard let uid = await client.currentUserId() else { return nil }
        struct Row: Decodable {
            let id: String
            let email: String
            let displayName: String
            let avatarUrl: String?
        }
        let rows: [Row] = try await client.get(
            "users",
            queryItems: [
                URLQueryItem(name: "select", value: "id,email,display_name,avatar_url"),
                URLQueryItem(name: "id", value: "eq.\(uid)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { return nil }
        return DomainUserProfile(id: row.id, email: row.email, displayName: row.displayName, avatarUrl: row.avatarUrl)
    }

    func updateAvatarUrl(_ url: String?) async throws {
        guard let uid = await client.currentUserId() else { throw SupabaseRepositoryError.missingSession }
        struct Body: Encodable { let avatarUrl: String? }
        let _: [EmptyResponse] = try await client.patch("users?id=eq.\(uid)", body: Body(avatarUrl: url))
    }

    func uploadBrandingImage(path: String, contentType: String, data: Data) async throws -> String {
        try await client.uploadStorageObject(bucket: "branding", objectPath: path, contentType: contentType, data: data)
        return await client.publicStorageURL(bucket: "branding", objectPath: path)
    }

    func sendPasswordResetEmail(_ email: String) async throws {
        try await client.sendPasswordResetEmail(email)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.updatePassword(newPassword)
    }

    func signOutAllSessions() async throws {
        try await client.signOutAllSessions()
    }
}

struct SupabaseWorkspaceRepository: WorkspaceRepository {
    let client: SupabaseRESTClient

    func listWorkspacesForCurrentUser() async throws -> [DomainWorkspace] {
        let rows: [WorkspaceMembershipRow] = try await client.get(
            "workspace_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "id,role,status,workspaces(id,name,abbr,brand_color,default_currency,logo_url)"),
                URLQueryItem(name: "status", value: "eq.active")
            ]
        )
        return rows.compactMap { row in
            guard let workspace = row.workspaces else { return nil }
            return DomainWorkspace(
                id: workspace.id,
                name: workspace.name,
                abbr: workspace.abbr,
                brandColorHex: workspace.brandColor,
                defaultCurrency: workspace.defaultCurrency,
                currentUserRole: row.role,
                logoUrl: workspace.logoUrl
            )
        }
    }

    func listMembers(workspaceId: String) async throws -> [DomainWorkspaceMember] {
        let rows: [WorkspaceMemberRow] = try await client.get(
            "workspace_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "id,workspace_id,user_id,role,status,users(display_name,email,avatar_url)"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.active")
            ]
        )
        return rows.map { row in
            DomainWorkspaceMember(
                id: row.id,
                workspaceId: row.workspaceId,
                userId: row.userId,
                displayName: row.users?.displayName ?? "Member",
                email: row.users?.email ?? "",
                role: row.role,
                status: row.status,
                avatarColorHex: "4B5563"
            )
        }
    }

    func listInvites(workspaceId: String) async throws -> [WorkspaceInvite] {
        let rows: [WorkspaceInviteRow] = try await client.get(
            "workspace_invites",
            queryItems: [
                URLQueryItem(name: "select", value: "id,workspace_id,email,role,status,expires_at"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.pending")
            ]
        )
        return rows.map {
            WorkspaceInvite(id: $0.id, workspaceId: $0.workspaceId, email: $0.email, role: $0.role, status: $0.status, expiresAt: $0.expiresAt)
        }
    }

    func listCategories(workspaceId: String) async throws -> [DomainCategory] {
        struct CategoryRow: Decodable {
            let id: String
            let workspaceId: String
            let name: String
            let icon: String
        }
        let rows: [CategoryRow] = try await client.get(
            "categories",
            queryItems: [
                URLQueryItem(name: "select", value: "id,workspace_id,name,icon"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "is_active", value: "eq.true"),
                URLQueryItem(name: "order", value: "name.asc")
            ]
        )
        return rows.map { DomainCategory(id: $0.id, workspaceId: $0.workspaceId, name: $0.name, icon: $0.icon) }
    }

    func createWorkspace(name: String, defaultCurrency: String) async throws -> DomainWorkspace {
        struct Body: Encodable {
            let workspaceName: String
            let defaultCurrency: String

            enum CodingKeys: String, CodingKey {
                case workspaceName = "workspace_name"
                case defaultCurrency = "default_currency"
            }
        }

        let row: WorkspaceRow = try await client.rpc(
            "create_workspace_with_admin",
            body: Body(workspaceName: name, defaultCurrency: defaultCurrency)
        )
        return DomainWorkspace(
            id: row.id,
            name: row.name,
            abbr: row.abbr,
            brandColorHex: row.brandColor,
            defaultCurrency: row.defaultCurrency,
            currentUserRole: .admin,
            logoUrl: row.logoUrl
        )
    }

    func acceptInvite(id: String) async throws -> DomainWorkspace {
        // Server-side RPC: the joiner isn't a workspace member yet, so they
        // can't insert into workspace_memberships directly. The SECURITY DEFINER
        // function verifies the invite is addressed to their auth email,
        // marks it accepted, and creates the membership atomically.
        struct Args: Encodable { let inviteId: String }
        let membership: WorkspaceMemberRow = try await client.rpc(
            "accept_workspace_invite",
            body: Args(inviteId: id)
        )
        // Load the workspace this membership belongs to.
        let workspaceRows: [WorkspaceRow] = try await client.get(
            "workspaces",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(membership.workspaceId)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = workspaceRows.first else { throw SupabaseRepositoryError.invalidResponse }
        return DomainWorkspace(
            id: row.id,
            name: row.name,
            abbr: row.abbr,
            brandColorHex: row.brandColor,
            defaultCurrency: row.defaultCurrency,
            currentUserRole: membership.role,
            logoUrl: row.logoUrl
        )
    }

    func inviteMember(workspaceId: String, email: String, role: WorkspaceRole) async throws -> WorkspaceInvite {
        let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let currentUserId = await client.currentUserId() ?? ""
        let rows: [WorkspaceInviteRow] = try await client.post(
            "workspace_invites",
            body: WorkspaceInviteInsert(workspaceId: workspaceId, email: email.lowercased(), role: role, invitedByUserId: currentUserId, expiresAt: expiresAt)
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        let invite = WorkspaceInvite(id: row.id, workspaceId: row.workspaceId, email: row.email, role: row.role, status: row.status, expiresAt: row.expiresAt)

        // Fire-and-forget email send. Failure here is non-fatal — the invite
        // row exists, and the admin can re-trigger from the UI. Swallowing
        // intentionally so a misconfigured Resend secret doesn't block the
        // create-invite flow.
        struct EmailBody: Encodable { let inviteId: String }
        let _: EmptyResponse? = try? await client.invokeFunction(
            "send-workspace-invite",
            body: EmailBody(inviteId: invite.id)
        )

        return invite
    }

    func cancelInvite(id: String) async throws {
        let _: [WorkspaceInviteRow] = try await client.patch(
            "workspace_invites?id=eq.\(id)",
            body: ["status": WorkspaceInvite.Status.cancelled.rawValue]
        )
    }

    func updateMemberRole(id: String, role: WorkspaceRole) async throws -> DomainWorkspaceMember {
        let rows: [WorkspaceMemberRow] = try await client.patch(
            "workspace_memberships?id=eq.\(id)",
            body: ["role": role.rawValue]
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return DomainWorkspaceMember(id: row.id, workspaceId: row.workspaceId, userId: row.userId, displayName: row.users?.displayName ?? "Member", email: row.users?.email ?? "", role: row.role, status: row.status, avatarColorHex: "4B5563")
    }

    func removeMember(id: String) async throws {
        let _: [WorkspaceMemberRow] = try await client.patch(
            "workspace_memberships?id=eq.\(id)",
            body: ["status": "removed", "removed_at": ISO8601DateFormatter().string(from: Date())]
        )
    }

    func listNotifications(workspaceId: String) async throws -> [DomainNotification] {
        struct NotificationRow: Decodable {
            let id: String
            let workspaceId: String
            let recipientMembershipId: String
            let kind: NotificationEventType
            let title: String
            let body: String
            let readAt: Date?
            let createdAt: Date
            let expenseId: String?
        }
        let rows: [NotificationRow] = try await client.get(
            "notifications",
            queryItems: [
                URLQueryItem(name: "select", value: "id,workspace_id,recipient_membership_id,kind,title,body,read_at,created_at,expense_id"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "50")
            ]
        )
        return rows.map {
            DomainNotification(
                id: $0.id,
                workspaceId: $0.workspaceId,
                recipientMembershipId: $0.recipientMembershipId,
                eventType: $0.kind,
                channel: .inApp,
                title: $0.title,
                body: $0.body,
                deepLinkRoute: "",
                isRead: $0.readAt != nil,
                createdAt: $0.createdAt,
                expenseId: $0.expenseId
            )
        }
    }

    func markNotificationRead(id: String) async throws {
        let _: [EmptyResponse] = try await client.patch(
            "notifications?id=eq.\(id)",
            body: ["read_at": ISO8601DateFormatter().string(from: Date())]
        )
    }

    func updateWorkspace(workspaceId: String, name: String, defaultCurrency: String) async throws -> DomainWorkspace {
        struct Body: Encodable {
            let name: String
            let defaultCurrency: String
        }
        let rows: [WorkspaceRow] = try await client.patch(
            "workspaces?id=eq.\(workspaceId)",
            body: Body(name: name, defaultCurrency: defaultCurrency.uppercased())
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        let role = try await currentRole(workspaceId: workspaceId)
        return DomainWorkspace(
            id: row.id, name: row.name, abbr: row.abbr,
            brandColorHex: row.brandColor, defaultCurrency: row.defaultCurrency,
            currentUserRole: role, logoUrl: row.logoUrl
        )
    }

    private func currentRole(workspaceId: String) async throws -> WorkspaceRole {
        struct RoleRow: Decodable { let role: WorkspaceRole }
        let rows: [RoleRow] = try await client.get(
            "workspace_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "role"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        return rows.first?.role ?? .admin
    }

    func updateWorkspaceLogo(workspaceId: String, logoUrl: String?) async throws -> DomainWorkspace {
        struct Body: Encodable { let logoUrl: String? }
        let rows: [WorkspaceRow] = try await client.patch(
            "workspaces?id=eq.\(workspaceId)",
            body: Body(logoUrl: logoUrl)
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        // Re-read current role since PATCH only returns the workspace row.
        struct RoleRow: Decodable { let role: WorkspaceRole }
        let roleRows: [RoleRow] = (try? await client.get(
            "workspace_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "role"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )) ?? []
        let role = roleRows.first?.role ?? .admin
        return DomainWorkspace(
            id: row.id,
            name: row.name,
            abbr: row.abbr,
            brandColorHex: row.brandColor,
            defaultCurrency: row.defaultCurrency,
            currentUserRole: role,
            logoUrl: row.logoUrl
        )
    }
}

struct SupabaseProjectRepository: ProjectRepository {
    let client: SupabaseRESTClient

    func listProjects(workspaceId: String) async throws -> [DomainProject] {
        let rows: [SupabaseProjectRow] = try await client.get(
            "projects",
            queryItems: [
                URLQueryItem(name: "select", value: "*,project_category_rules(category_id),project_memberships(role,workspace_membership_id)"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.map { $0.domainProject(currentMembershipId: nil) }
    }

    func createProject(_ project: DomainProject) async throws -> DomainProject {
        let ownerMembershipId = try await currentMembershipId(workspaceId: project.workspaceId)
        let newId = UUID().uuidString
        let _: EmptyResponse = try await client.post(
            "projects",
            body: ProjectInsert(id: newId, project: project, ownerMembershipId: ownerMembershipId),
            preferRepresentation: false
        )
        let rows: [SupabaseProjectRow] = try await client.get(
            "projects",
            queryItems: [
                URLQueryItem(name: "select", value: "*,project_category_rules(category_id),project_memberships(role,workspace_membership_id)"),
                URLQueryItem(name: "id", value: "eq.\(newId)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainProject(currentMembershipId: ownerMembershipId)
    }

    func updateProject(_ project: DomainProject) async throws -> DomainProject {
        let rows: [SupabaseProjectRow] = try await client.patch("projects?id=eq.\(project.id)", body: ProjectUpdate(project: project))
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainProject(currentMembershipId: nil)
    }

    func archiveProject(id: String) async throws {
        let _: [SupabaseProjectRow] = try await client.patch(
            "projects?id=eq.\(id)",
            body: ["status": "archived", "archived_at": ISO8601DateFormatter().string(from: Date())]
        )
    }

    private func currentMembershipId(workspaceId: String) async throws -> String {
        let rows: [CurrentMembershipRow] = try await client.get(
            "workspace_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let id = rows.first?.id else { throw SupabaseRepositoryError.missingSession }
        return id
    }
}

struct SupabaseExpenseRepository: ExpenseRepository {
    let client: SupabaseRESTClient

    func listExpenses(filters: ExpenseFilters) async throws -> [DomainExpense] {
        var query = [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "workspace_id", value: "eq.\(filters.workspaceId)"),
            URLQueryItem(name: "deleted_at", value: "is.null"),
            URLQueryItem(name: "order", value: "created_at.desc")
        ]
        if let projectId = filters.projectId {
            query.append(URLQueryItem(name: "project_id", value: "eq.\(projectId)"))
        }
        if let status = filters.status {
            query.append(URLQueryItem(name: "status", value: "eq.\(status.rawValue)"))
        }
        if let kind = filters.kind {
            query.append(URLQueryItem(name: "type", value: "eq.\(kind.rawValue)"))
        }
        let rows: [SupabaseExpenseRow] = try await client.get("expenses", queryItems: query)
        return rows.map(\.domainExpense)
    }

    func listEvents(expenseId: String) async throws -> [ExpenseWorkflowEvent] {
        let rows: [ExpenseEventRow] = try await client.get(
            "expense_events",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "expense_id", value: "eq.\(expenseId)"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.map(\.domainEvent)
    }

    func createDraft(_ input: ExpenseDraftInput) async throws -> DomainExpense {
        let membershipId = try await currentMembershipId(workspaceId: input.workspaceId)
        let newId = UUID().uuidString
        let fx = await snapshotFX(amount: input.amount, baseCurrency: input.baseCurrency, date: Date())
        // Prefer: return=minimal avoids RETURNING * which would trigger the SELECT
        // RLS policy on the freshly-inserted row and fail with 42501.
        let _: EmptyResponse = try await client.post(
            "expenses",
            body: ExpenseInsert(id: newId, input: input, submittedByMembershipId: membershipId, fx: fx),
            preferRepresentation: false
        )
        let rows: [SupabaseExpenseRow] = try await client.get(
            "expenses",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(newId)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    func updateDraft(id: String, _ input: ExpenseDraftInput) async throws -> DomainExpense {
        // Re-snapshot FX on every update — the user may have changed the native
        // amount or currency. Cache on the server keeps repeat conversions cheap.
        let fx = await snapshotFX(amount: input.amount, baseCurrency: input.baseCurrency, date: Date())
        let rows: [SupabaseExpenseRow] = try await client.patch(
            "expenses?id=eq.\(id)",
            body: ExpenseDraftUpdate(input: input, fx: fx)
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    func backfillFXSnapshot(id: String, amount: MoneyAmount, baseCurrency: String, date: Date) async throws -> DomainExpense {
        // Resolve the snapshot via the same edge function that create/update use —
        // identical cache, identical fallback. Skip the row if conversion fails;
        // the next launch will retry. The RPC bypasses the workflow-state
        // UPDATE policies (FX fields aren't workflow state) and is idempotent —
        // it only stamps rows whose snapshot is currently null.
        guard let fx = await snapshotFX(amount: amount, baseCurrency: baseCurrency, date: date) else {
            throw SupabaseRepositoryError.invalidResponse
        }
        let _: EmptyResponse = try await client.rpc(
            "backfill_expense_fx",
            body: BackfillExpenseFXArgs(
                expenseId: id,
                baseCurrency: fx.baseCurrency,
                amountInBaseMinor: fx.amountInBaseMinor,
                fxRate: fx.fxRate,
                fxRateAsOf: fx.fxRateAsOf,
                fxSource: fx.fxSource
            )
        )
        // Re-read the row so the caller sees the freshly-stamped snapshot.
        let rows: [SupabaseExpenseRow] = try await client.get(
            "expenses",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    /// Asks the `convert-currency` edge function to snapshot an FX rate for
    /// the given amount + target base currency on `date`. Returns nil when
    /// the base currency is unknown, the pair is unsupported, or the call
    /// fails — in which case the expense is inserted without FX fields and
    /// will get backfilled later. Never throws; FX problems must not block
    /// the user from saving their expense.
    private func snapshotFX(amount: MoneyAmount, baseCurrency: String?, date: Date) async -> FXSnapshot? {
        guard let base = baseCurrency else { return nil }
        do {
            let req = ConvertCurrencyRequest(
                amount: amount.minorUnits,
                from: amount.currency,
                to: base,
                date: Self.dateFormatter.string(from: date)
            )
            let resp: ConvertCurrencyResponse = try await client.invokeFunction("convert-currency", body: req)
            return FXSnapshot(
                baseCurrency: base,
                amountInBaseMinor: resp.converted,
                fxRate: resp.rate,
                fxRateAsOf: Self.dateFormatter.date(from: resp.asOf) ?? date,
                fxSource: resp.source
            )
        } catch {
            return nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    func submitExpense(id: String) async throws -> DomainExpense {
        try await invokeSubmit(id: id)
    }

    func resubmitExpense(id: String) async throws -> DomainExpense {
        try await invokeSubmit(id: id)
    }

    /// Routes the draft → submitted transition through the `submit_expense`
    /// SECURITY DEFINER RPC instead of a direct PATCH. The PATCH path fails
    /// RLS WITH CHECK because the `route_submitted_expense` BEFORE trigger
    /// rewrites `status` to the routed value (pending_manager_approval, etc.),
    /// which falls outside the submitter UPDATE policy's allowed set. The
    /// RPC enforces equivalent authorization server-side (caller is the
    /// original submitter, status is submittable) before letting the trigger
    /// route.
    private func invokeSubmit(id: String) async throws -> DomainExpense {
        let _: EmptyResponse = try await client.rpc(
            "submit_expense",
            body: SubmitExpenseArgs(expenseId: id)
        )
        // Re-read so the caller sees the routed final status, not 'submitted'.
        let rows: [SupabaseExpenseRow] = try await client.get(
            "expenses",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    func cancelExpense(id: String, reason: String?) async throws -> DomainExpense {
        try await updateStatus(id: id, status: .cancelled)
    }

    func approveExpense(id: String, note: String?) async throws -> DomainExpense {
        try await updateStatus(id: id, status: .approved)
    }

    func rejectExpense(id: String, reason: String) async throws -> DomainExpense {
        try await updateStatus(id: id, status: .rejected)
    }

    func confirmPurchase(id: String, input: PurchaseConfirmationInput) async throws -> DomainExpense {
        let rows: [SupabaseExpenseRow] = try await client.patch(
            "expenses?id=eq.\(id)",
            body: ExpensePurchaseUpdate(input: input)
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    func markReimbursed(id: String, input: ReimbursementInput) async throws -> DomainExpense {
        try await updateStatus(id: id, status: .reimbursed)
    }

    func archiveExpense(id: String) async throws -> DomainExpense {
        let rows: [SupabaseExpenseRow] = try await client.patch(
            "expenses?id=eq.\(id)",
            body: ExpenseArchiveUpdate(status: .archived, isArchived: true)
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    func unarchiveExpense(id: String) async throws -> DomainExpense {
        let rows: [SupabaseExpenseRow] = try await client.patch(
            "expenses?id=eq.\(id)",
            body: ExpenseArchiveUpdate(status: .draft, isArchived: false)
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    func deleteExpense(id: String) async throws {
        let _: [SupabaseExpenseRow] = try await client.patch(
            "expenses?id=eq.\(id)",
            body: ExpenseDeleteUpdate(deletedAt: Date())
        )
    }

    private func updateStatus(id: String, status: ExpenseWorkflowStatus) async throws -> DomainExpense {
        let rows: [SupabaseExpenseRow] = try await client.patch("expenses?id=eq.\(id)", body: ExpenseStatusUpdate(status: status))
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domainExpense
    }

    private func currentMembershipId(workspaceId: String) async throws -> String {
        let rows: [CurrentMembershipRow] = try await client.get(
            "workspace_memberships",
            queryItems: [
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "workspace_id", value: "eq.\(workspaceId)"),
                URLQueryItem(name: "status", value: "eq.active"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let id = rows.first?.id else { throw SupabaseRepositoryError.missingSession }
        return id
    }
}

struct SupabaseAttachmentRepository: AttachmentRepository {
    let client: SupabaseRESTClient
    let bucket = "receipts"

    func listAttachments(expenseId: String) async throws -> [ExpenseAttachment] {
        let rows: [AttachmentRow] = try await client.get(
            "attachments",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "expense_id", value: "eq.\(expenseId)"),
                URLQueryItem(name: "deleted_at", value: "is.null"),
                URLQueryItem(name: "order", value: "created_at.desc")
            ]
        )
        return rows.map(\.domain)
    }

    func uploadAttachment(expenseId: String, kind: ExpenseAttachment.Kind, fileName: String, contentType: String, data: Data) async throws -> ExpenseAttachment {
        guard !data.isEmpty else { throw SupabaseRepositoryError.invalidResponse }

        struct ExpenseRef: Decodable { let workspaceId: String }
        let refs: [ExpenseRef] = try await client.get(
            "expenses",
            queryItems: [
                URLQueryItem(name: "select", value: "workspace_id"),
                URLQueryItem(name: "id", value: "eq.\(expenseId)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let workspaceId = refs.first?.workspaceId else { throw SupabaseRepositoryError.invalidResponse }
        let membershipId = try await client.currentMembershipId(workspaceId: workspaceId)

        let safeName = fileName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "_")
        let storageKey = "\(workspaceId)/\(expenseId)/\(UUID().uuidString)-\(safeName)"

        try await client.uploadStorageObject(bucket: bucket, objectPath: storageKey, contentType: contentType, data: data)

        let attachmentId = UUID().uuidString
        let _: EmptyResponse = try await client.post(
            "attachments",
            body: AttachmentInsert(
                id: attachmentId,
                workspaceId: workspaceId,
                expenseId: expenseId,
                uploadedByMembershipId: membershipId,
                kind: kind,
                fileName: safeName,
                contentType: contentType,
                fileSizeBytes: data.count,
                storageKey: storageKey,
                sha256: data.sha256Hex
            ),
            preferRepresentation: false
        )
        let rows: [AttachmentRow] = try await client.get(
            "attachments",
            queryItems: [
                URLQueryItem(name: "select", value: "*"),
                URLQueryItem(name: "id", value: "eq.\(attachmentId)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domain
    }

    func deleteAttachment(id: String) async throws {
        let _: [AttachmentRow] = try await client.patch(
            "attachments?id=eq.\(id)",
            body: ["deleted_at": ISO8601DateFormatter().string(from: Date())]
        )
    }
}

struct SupabaseReceiptScanRepository: ReceiptScanRepository {
    let client: SupabaseRESTClient
    let functionName: String

    func startScan(attachmentId: String) async throws -> ReceiptScanResult {
        struct Body: Encodable { let attachmentId: String }
        let row: ReceiptScanRow = try await client.invokeFunction(functionName, body: Body(attachmentId: attachmentId))
        return row.domain
    }

    func getScanResult(id: String) async throws -> ReceiptScanResult {
        let rows: [ReceiptScanRow] = try await client.get(
            "receipt_scans",
            queryItems: [
                URLQueryItem(name: "select", value: "*,receipt_scan_fields(*)"),
                URLQueryItem(name: "id", value: "eq.\(id)"),
                URLQueryItem(name: "limit", value: "1")
            ]
        )
        guard let row = rows.first else { throw SupabaseRepositoryError.invalidResponse }
        return row.domain
    }

    func confirmScanField(scanId: String, fieldId: String, normalizedValue: String) async throws -> ReceiptScanResult {
        struct FieldUpdate: Encodable {
            let normalizedValue: String
            let confirmedByUser = true
            let confidence = ScanFieldConfidence.manual
        }
        let _: [ReceiptScanFieldRow] = try await client.patch(
            "receipt_scan_fields?id=eq.\(fieldId)",
            body: FieldUpdate(normalizedValue: normalizedValue)
        )
        return try await getScanResult(id: scanId)
    }
}

private struct AttachmentRow: Decodable {
    let id: String
    let workspaceId: String
    let expenseId: String
    let kind: ExpenseAttachment.Kind
    let fileName: String
    let contentType: String
    let storageKey: String
    let createdAt: Date

    var domain: ExpenseAttachment {
        ExpenseAttachment(
            id: id,
            workspaceId: workspaceId,
            expenseId: expenseId,
            kind: kind,
            fileName: fileName,
            contentType: contentType,
            storageKey: storageKey,
            createdAt: createdAt
        )
    }
}

private struct AttachmentInsert: Encodable {
    let id: String
    let workspaceId: String
    let expenseId: String
    let uploadedByMembershipId: String
    let kind: ExpenseAttachment.Kind
    let fileName: String
    let contentType: String
    let fileSizeBytes: Int
    let storageKey: String
    let sha256: String
}

private struct ReceiptScanFieldRow: Decodable {
    let id: String
    let fieldName: String
    let extractedValue: String
    let normalizedValue: String?
    let confidence: ScanFieldConfidence
    let confirmedByUser: Bool

    var domain: ReceiptScanField {
        ReceiptScanField(
            id: id,
            fieldName: fieldName,
            extractedValue: extractedValue,
            normalizedValue: normalizedValue,
            confidence: confidence,
            confirmedByUser: confirmedByUser
        )
    }
}

private struct ReceiptScanRow: Decodable {
    let id: String
    let attachmentId: String
    let expenseId: String
    let status: ReceiptScanStatus
    let errorMessage: String?
    let receiptScanFields: [ReceiptScanFieldRow]?

    var domain: ReceiptScanResult {
        ReceiptScanResult(
            id: id,
            attachmentId: attachmentId,
            expenseId: expenseId,
            status: status,
            fields: (receiptScanFields ?? []).map(\.domain),
            errorMessage: errorMessage
        )
    }
}

private extension Data {
    var sha256Hex: String {
        let digest = SHA256.hash(data: self)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct WorkspaceRow: Codable {
    let id: String
    let name: String
    let abbr: String
    let brandColor: String
    let defaultCurrency: String
    let logoUrl: String?
}

private struct WorkspaceMembershipRow: Codable {
    let id: String
    let role: WorkspaceRole
    let status: String
    let workspaces: WorkspaceRow?
}

private struct WorkspaceMemberRow: Codable {
    let id: String
    let workspaceId: String
    let userId: String
    let role: WorkspaceRole
    let status: String
    let users: UserRow?
}

private struct UserRow: Codable {
    let displayName: String
    let email: String
    let avatarURL: String?
}

private struct WorkspaceInviteRow: Codable {
    let id: String
    let workspaceId: String
    let email: String
    let role: WorkspaceRole
    let status: WorkspaceInvite.Status
    let expiresAt: Date
}

private struct WorkspaceInviteInsert: Encodable {
    let workspaceId: String
    let email: String
    let role: WorkspaceRole
    let invitedByUserId: String
    let expiresAt: Date
}

private struct CurrentMembershipRow: Codable {
    let id: String
}

private struct SupabaseProjectRow: Codable {
    let id: String
    let workspaceId: String
    let name: String
    let ownerMembershipId: String
    let status: String
    let visibility: String
    let budgetAmountMinor: Int
    let budgetCurrency: String
    let budgetPeriod: String
    let approvalThresholdMinor: Int
    let receiptRequiredThresholdMinor: Int
    let routingMode: ProjectRoutingMode
    let overBudgetBehavior: OverBudgetBehavior
    let projectCategoryRules: [ProjectCategoryRuleRow]?
    let projectMemberships: [ProjectMembershipRow]?

    func domainProject(currentMembershipId: String?) -> DomainProject {
        DomainProject(
            id: id,
            workspaceId: workspaceId,
            name: name,
            budget: MoneyAmount(minorUnits: budgetAmountMinor, currency: budgetCurrency),
            budgetPeriod: budgetPeriod,
            ownerMembershipId: ownerMembershipId,
            visibility: visibility,
            routingMode: routingMode,
            overBudgetBehavior: overBudgetBehavior,
            allowedCategoryIds: projectCategoryRules?.map(\.categoryId) ?? [],
            approvalThreshold: MoneyAmount(minorUnits: approvalThresholdMinor, currency: budgetCurrency),
            receiptRequiredThreshold: MoneyAmount(minorUnits: receiptRequiredThresholdMinor, currency: budgetCurrency),
            currentUserProjectRole: projectMemberships?.first { $0.workspaceMembershipId == currentMembershipId }?.role,
            isArchived: status == "archived"
        )
    }
}

private struct ProjectCategoryRuleRow: Codable {
    let categoryId: String
}

private struct ProjectMembershipRow: Codable {
    let workspaceMembershipId: String
    let role: ProjectRole
}

private struct ProjectInsert: Encodable {
    let id: String
    let workspaceId: String
    let name: String
    let ownerMembershipId: String
    let visibility: String
    let budgetAmountMinor: Int
    let budgetCurrency: String
    let budgetPeriod: String
    let approvalThresholdMinor: Int
    let receiptRequiredThresholdMinor: Int
    let routingMode: ProjectRoutingMode
    let overBudgetBehavior: OverBudgetBehavior

    init(id: String, project: DomainProject, ownerMembershipId: String) {
        self.id = id
        workspaceId = project.workspaceId
        name = project.name
        self.ownerMembershipId = ownerMembershipId
        visibility = project.visibility
        budgetAmountMinor = project.budget.minorUnits
        budgetCurrency = project.budget.currency
        budgetPeriod = project.budgetPeriod
        approvalThresholdMinor = project.approvalThreshold.minorUnits
        receiptRequiredThresholdMinor = project.receiptRequiredThreshold.minorUnits
        routingMode = project.routingMode
        overBudgetBehavior = project.overBudgetBehavior
    }
}

private struct ProjectUpdate: Encodable {
    let name: String
    let visibility: String
    let budgetAmountMinor: Int
    let budgetPeriod: String
    let approvalThresholdMinor: Int
    let receiptRequiredThresholdMinor: Int
    let routingMode: ProjectRoutingMode
    let overBudgetBehavior: OverBudgetBehavior

    init(project: DomainProject) {
        name = project.name
        visibility = project.visibility
        budgetAmountMinor = project.budget.minorUnits
        budgetPeriod = project.budgetPeriod
        approvalThresholdMinor = project.approvalThreshold.minorUnits
        receiptRequiredThresholdMinor = project.receiptRequiredThreshold.minorUnits
        routingMode = project.routingMode
        overBudgetBehavior = project.overBudgetBehavior
    }
}

private struct SupabaseExpenseRow: Codable {
    let id: String
    let workspaceId: String
    let projectId: String
    let submittedByMembershipId: String
    let type: ExpenseKind
    let status: ExpenseWorkflowStatus
    let merchant: String
    let amountMinor: Int
    let currency: String
    /// FX snapshot, all nullable for rows created before the FX-snapshot feature
    /// shipped (those rows get backfilled on next launch).
    let baseCurrency: String?
    let amountInBaseMinor: Int?
    let fxRate: Double?
    let fxRateAsOf: Date?
    let fxSource: String?
    let categoryId: String
    let businessPurpose: String
    let purchaseDate: Date?
    let neededByDate: Date?
    let createdAt: Date
    let submittedAt: Date?
    let isArchived: Bool

    var domainExpense: DomainExpense {
        let amountInBase: MoneyAmount?
        if let inBase = amountInBaseMinor, let baseCur = baseCurrency {
            amountInBase = MoneyAmount(minorUnits: inBase, currency: baseCur)
        } else {
            amountInBase = nil
        }
        return DomainExpense(
            id: id,
            workspaceId: workspaceId,
            projectId: projectId,
            submittedByMembershipId: submittedByMembershipId,
            kind: type,
            status: status,
            merchant: merchant,
            amount: MoneyAmount(minorUnits: amountMinor, currency: currency),
            amountInBase: amountInBase,
            fxRate: fxRate,
            fxRateAsOf: fxRateAsOf,
            fxSource: fxSource,
            categoryId: categoryId,
            businessPurpose: businessPurpose,
            purchaseDate: purchaseDate,
            neededByDate: neededByDate,
            createdAt: createdAt,
            submittedAt: submittedAt,
            isArchived: isArchived
        )
    }
}

/// Snapshot returned by the `convert-currency` edge function and stamped onto
/// expense rows at create/update time. Same shape on insert and patch paths.
struct FXSnapshot {
    let baseCurrency: String
    let amountInBaseMinor: Int
    let fxRate: Double
    let fxRateAsOf: Date
    let fxSource: String
}

private struct ConvertCurrencyRequest: Encodable {
    let amount: Int
    let from: String
    let to: String
    let date: String
}

private struct ConvertCurrencyResponse: Decodable {
    let rate: Double
    let converted: Int
    let source: String
    let asOf: String
}

private struct ExpenseInsert: Encodable {
    let id: String
    let workspaceId: String
    let projectId: String
    let submittedByMembershipId: String
    let type: ExpenseKind
    let status: ExpenseWorkflowStatus
    let merchant: String
    let amountMinor: Int
    let currency: String
    let baseCurrency: String?
    let amountInBaseMinor: Int?
    let fxRate: Double?
    let fxRateAsOf: Date?
    let fxSource: String?
    let categoryId: String
    let businessPurpose: String
    let purchaseDate: Date?
    let neededByDate: Date?

    init(id: String, input: ExpenseDraftInput, submittedByMembershipId: String, fx: FXSnapshot?) {
        self.id = id
        workspaceId = input.workspaceId
        projectId = input.projectId
        self.submittedByMembershipId = submittedByMembershipId
        type = input.kind
        status = .draft
        merchant = input.merchant
        amountMinor = input.amount.minorUnits
        currency = input.amount.currency
        baseCurrency = fx?.baseCurrency
        amountInBaseMinor = fx?.amountInBaseMinor
        fxRate = fx?.fxRate
        fxRateAsOf = fx?.fxRateAsOf
        fxSource = fx?.fxSource
        categoryId = input.categoryId
        businessPurpose = input.businessPurpose
        purchaseDate = input.purchaseDate
        neededByDate = input.neededByDate
    }
}

private struct ExpenseDraftUpdate: Encodable {
    let type: ExpenseKind
    let merchant: String
    let amountMinor: Int
    let currency: String
    let baseCurrency: String?
    let amountInBaseMinor: Int?
    let fxRate: Double?
    let fxRateAsOf: Date?
    let fxSource: String?
    let categoryId: String
    let businessPurpose: String
    let purchaseDate: Date?
    let neededByDate: Date?

    init(input: ExpenseDraftInput, fx: FXSnapshot?) {
        type = input.kind
        merchant = input.merchant
        amountMinor = input.amount.minorUnits
        currency = input.amount.currency
        baseCurrency = fx?.baseCurrency
        amountInBaseMinor = fx?.amountInBaseMinor
        fxRate = fx?.fxRate
        fxRateAsOf = fx?.fxRateAsOf
        fxSource = fx?.fxSource
        categoryId = input.categoryId
        businessPurpose = input.businessPurpose
        purchaseDate = input.purchaseDate
        neededByDate = input.neededByDate
    }
}

/// Arguments to the `turfmapp_expenses.submit_expense` SECURITY DEFINER RPC.
/// One field, one purpose: kick off the draft → submitted routing on the
/// server side without tripping the submitter UPDATE policy's WITH CHECK.
private struct SubmitExpenseArgs: Encodable {
    let expenseId: String
}

/// Arguments to the `turfmapp_expenses.backfill_expense_fx` SECURITY DEFINER
/// RPC. Calling it stamps the FX snapshot on a single row IF that row's
/// snapshot is currently null — the RPC enforces idempotency server-side.
/// We can't PATCH directly because the RLS UPDATE policies are workflow-state
/// scoped (drafts/manager/finance queues), and FX backfill needs to touch
/// rows in any state.
private struct BackfillExpenseFXArgs: Encodable {
    let expenseId: String
    let baseCurrency: String
    let amountInBaseMinor: Int
    let fxRate: Double
    let fxRateAsOf: Date
    let fxSource: String

    // Postgres function param names use snake_case; Codable's keyEncodingStrategy
    // (in JSONEncoder.supabase) converts camelCase to snake_case automatically.
    // So `expenseId` ↔ `expense_id`, etc. — no manual CodingKeys needed.
}

private struct ExpensePurchaseUpdate: Encodable {
    let status = ExpenseWorkflowStatus.purchaseConfirmed
    let amountMinor: Int
    let purchaseDate: Date

    init(input: PurchaseConfirmationInput) {
        amountMinor = input.finalAmount.minorUnits
        purchaseDate = input.purchaseDate
    }
}

private struct ExpenseStatusUpdate: Encodable {
    let status: ExpenseWorkflowStatus
}

private struct ExpenseArchiveUpdate: Encodable {
    let status: ExpenseWorkflowStatus
    let isArchived: Bool
}

private struct ExpenseDeleteUpdate: Encodable {
    let deletedAt: Date
}

private struct ExpenseEventRow: Codable {
    let id: String
    let expenseId: String
    let actorMembershipId: String
    let eventType: String
    let fromStatus: ExpenseWorkflowStatus?
    let toStatus: ExpenseWorkflowStatus?
    let note: String?
    let createdAt: Date

    var domainEvent: ExpenseWorkflowEvent {
        ExpenseWorkflowEvent(id: id, expenseId: expenseId, actorMembershipId: actorMembershipId, fromStatus: fromStatus, toStatus: toStatus, eventType: eventType, note: note, createdAt: createdAt)
    }
}

private extension JSONEncoder {
    static var supabase: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var supabase: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = SupabaseDateParser.iso8601WithFractionalSeconds.date(from: value) {
                return date
            }
            if let date = SupabaseDateParser.iso8601.date(from: value) {
                return date
            }
            if let date = SupabaseDateParser.dateOnly.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid Supabase date: \(value)")
        }
        return decoder
    }
}

private enum SupabaseDateParser {
    static var iso8601WithFractionalSeconds: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    static var iso8601: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    static var dateOnly: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
