import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

// MARK: – Errors

enum SocialAuthError: LocalizedError {
    case missingURL
    case userCancelled
    case missingTokens
    case identityTokenMissing
    case nonceMissing
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .missingURL:            return "Couldn't build the sign-in URL."
        case .userCancelled:         return "Sign-in was cancelled."
        case .missingTokens:         return "The sign-in didn't return tokens."
        case .identityTokenMissing:  return "Apple Sign-In didn't return an identity token."
        case .nonceMissing:          return "Apple Sign-In nonce was missing."
        case .unknown(let m):        return m
        }
    }
}

// MARK: – Google (and any web-OAuth) via ASWebAuthenticationSession

/// Drives ASWebAuthenticationSession for Supabase's web-OAuth flow.
/// Supabase's `/auth/v1/authorize` redirects back to our custom URL scheme
/// with the tokens in the URL fragment, e.g.:
///
///     com.turfmapp.expense-report://login-callback#access_token=...&refresh_token=...&expires_in=3600&...
///
/// We parse the fragment and hand the tokens to the Supabase client so the
/// rest of the app sees the OAuth user the same way it would a password user.
@MainActor
final class WebOAuthPresenter: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebOAuthPresenter()

    /// Must match the URL scheme declared in Info.plist and the redirect URL
    /// configured in the Supabase dashboard's auth settings.
    static let redirectScheme = "com.turfmapp.expense-report"

    func start(authorizeURL: URL) async throws -> (accessToken: String, refreshToken: String?, expiresIn: Int?) {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizeURL,
                callbackURLScheme: Self.redirectScheme
            ) { callbackURL, error in
                if let error {
                    if (error as NSError).code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                        continuation.resume(throwing: SocialAuthError.userCancelled)
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                guard let callbackURL else {
                    continuation.resume(throwing: SocialAuthError.missingTokens)
                    return
                }
                guard let tokens = Self.parseCallback(callbackURL) else {
                    continuation.resume(throwing: SocialAuthError.missingTokens)
                    return
                }
                continuation.resume(returning: tokens)
            }
            session.presentationContextProvider = self
            // Prefer an ephemeral session so Safari's existing Google cookies
            // don't auto-sign-in a wrong account, and so signOut actually clears
            // the provider's view of the session.
            session.prefersEphemeralWebBrowserSession = true
            if !session.start() {
                continuation.resume(throwing: SocialAuthError.missingURL)
            }
        }
    }

    /// Pull access_token / refresh_token / expires_in out of the URL fragment.
    /// Supabase appends them after a `#`, so URLComponents won't auto-decode them;
    /// we parse manually.
    private static func parseCallback(_ url: URL) -> (accessToken: String, refreshToken: String?, expiresIn: Int?)? {
        let fragment = url.fragment ?? ""
        let queryString = url.query ?? ""
        // Inspect the fragment first (default Supabase behavior), fall back to
        // the query string for hosted-provider flows that put tokens there.
        let payload = fragment.isEmpty ? queryString : fragment
        guard !payload.isEmpty else { return nil }

        var bag: [String: String] = [:]
        for pair in payload.components(separatedBy: "&") {
            let parts = pair.components(separatedBy: "=")
            guard parts.count == 2,
                  let key = parts[0].removingPercentEncoding,
                  let value = parts[1].removingPercentEncoding else { continue }
            bag[key] = value
        }
        guard let access = bag["access_token"], !access.isEmpty else { return nil }
        let refresh = bag["refresh_token"]
        let expires = bag["expires_in"].flatMap(Int.init)
        return (access, refresh, expires)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Pick the foremost foreground window for the current scene; falls
        // back to a new ASPresentationAnchor if we somehow can't find one
        // (e.g. when starting from a background activation).
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)
            ?? ASPresentationAnchor()
    }
}

// MARK: – Apple Sign-In

/// Drives the native Sign in with Apple flow. We generate a fresh nonce per
/// request, send its SHA-256 hash to Apple, and pass the raw nonce + the
/// returned identity token to Supabase. Supabase verifies the token against
/// Apple's keys and the nonce against what was bound to that token.
@MainActor
final class AppleAuthCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = AppleAuthCoordinator()

    private var continuation: CheckedContinuation<(idToken: String, rawNonce: String), Error>?
    private var currentRawNonce: String?

    func requestSignIn() async throws -> (idToken: String, rawNonce: String) {
        let rawNonce = Self.randomNonce()
        currentRawNonce = rawNonce
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(rawNonce)

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        defer { continuation = nil; currentRawNonce = nil }
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: SocialAuthError.identityTokenMissing)
            return
        }
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            continuation?.resume(throwing: SocialAuthError.identityTokenMissing)
            return
        }
        guard let rawNonce = currentRawNonce else {
            continuation?.resume(throwing: SocialAuthError.nonceMissing)
            return
        }
        continuation?.resume(returning: (idToken, rawNonce))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        defer { continuation = nil; currentRawNonce = nil }
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationErrorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            continuation?.resume(throwing: SocialAuthError.userCancelled)
        } else {
            continuation?.resume(throwing: error)
        }
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)
            ?? ASPresentationAnchor()
    }

    // MARK: – Nonce helpers

    /// 32-character URL-safe random nonce. Apple recommends ≥ 32 chars.
    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else { continue }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
