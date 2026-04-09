import Foundation

enum APIConfig {
    /// Default Mac LAN IP serving the dev backend.
    /// Update if your network changes: `ipconfig getifaddr en0`
    static let defaultBaseURL = URL(string: "http://192.168.178.23:8080/api/v1")!

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
