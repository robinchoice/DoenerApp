import Foundation

enum APIConfig {
    /// Production backend on Fly.io. Override in Settings for local dev.
    static let defaultBaseURL = URL(string: "https://doener-api.fly.dev/api/v1")!

    static let backendOverrideKey = "backendBaseURLOverride"

    /// Resolved backend URL — checks UserDefaults override first so the user can
    /// switch networks at runtime via Settings without recompiling.
    static var baseURL: URL {
        if let raw = UserDefaults.standard.string(forKey: backendOverrideKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !raw.isEmpty,
           let url = URL(string: raw) {
            return url
        }
        return defaultBaseURL
    }
}
