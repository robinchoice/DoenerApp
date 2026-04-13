import Foundation

/// Pushes locally-created reviews to the backend.
/// Returns false if the request failed and the operation should be queued for retry.
enum ReviewSyncService {
    struct UpsertReviewBody: Codable {
        let rating: Int
        let sauceRating: Int?
        let fleischRating: Int?
        let brotRating: Int?
        let text: String?
        let specialNote: String?
        let name: String
        let latitude: Double
        let longitude: Double
        let address: String?
        let postalCode: String?
        let city: String?
        let openingHours: String?
    }

    struct ReviewResponse: Decodable {
        let id: UUID
    }

    /// Returns true if succeeded or unauthorized (no queue needed), false if network failed (should queue).
    @discardableResult
    static func push(osmNodeID: Int64, body: UpsertReviewBody) async -> Bool {
        do {
            let _: ReviewResponse = try await APIClient.shared.post(
                "places/by_osm/\(osmNodeID)/reviews",
                body: body
            )
            return true
        } catch APIError.unauthorized {
            return true
        } catch {
            print("[ReviewSync] failed: \(error.localizedDescription)")
            return false
        }
    }
}
