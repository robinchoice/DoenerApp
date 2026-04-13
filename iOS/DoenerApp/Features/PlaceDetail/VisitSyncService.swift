import Foundation

/// Pushes locally-created visits to the backend.
/// Returns false if the request failed and the operation should be queued for retry.
enum VisitSyncService {
    struct CreateVisitBody: Codable {
        let visitedAt: Date
        let comment: String?
        let foodType: String?
        let name: String
        let latitude: Double
        let longitude: Double
        let address: String?
        let postalCode: String?
        let city: String?
        let openingHours: String?
    }

    struct VisitResponse: Decodable {
        let id: UUID
    }

    /// Returns true if succeeded or unauthorized (no queue needed), false if network failed (should queue).
    @discardableResult
    static func push(osmNodeID: Int64, body: CreateVisitBody) async -> Bool {
        do {
            let _: VisitResponse = try await APIClient.shared.post(
                "places/by_osm/\(osmNodeID)/visits",
                body: body
            )
            return true
        } catch APIError.unauthorized {
            return true
        } catch {
            print("[VisitSync] failed: \(error.localizedDescription)")
            return false
        }
    }
}
