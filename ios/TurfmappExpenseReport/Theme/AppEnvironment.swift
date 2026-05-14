import Foundation

enum AppEnvironment {
    static let receiptScanFunctionName = "scan-receipt"

    static var supabaseURL: URL? {
        guard let value = infoValue("SUPABASE_URL"),
              !value.isEmpty,
              !value.contains("YOUR_PROJECT_REF") else {
            return nil
        }
        return URL(string: value)
    }

    static var supabasePublishableKey: String? {
        guard let value = infoValue("SUPABASE_PUBLISHABLE_KEY"),
              !value.isEmpty,
              !value.contains("sb_publishable_your_key") else {
            return nil
        }
        return value
    }

    static var isSupabaseConfigured: Bool {
        supabaseURL != nil && supabasePublishableKey != nil
    }

    private static func infoValue(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
