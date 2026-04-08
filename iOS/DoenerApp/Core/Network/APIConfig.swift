import Foundation

enum APIConfig {
    /// Mac LAN IP serving the dev backend.
    /// Update if your network changes: `ipconfig getifaddr en0`
    static let baseURL = URL(string: "http://192.168.178.23:8080/api/v1")!
}
