import Foundation

/// Pushes locally-created visits to the backend.
/// Fire-and-forget: silently skips if not authenticated, logs other errors to console.
enum VisitSyncService {
    struct CreateVisitBody: Encodable {
        let visitedAt: Date
        let comment: String?
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

    static func push(
        osmNodeID: Int64,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String?,
        postalCode: String?,
        city: String?,
        openingHours: String?,
        visitedAt: Date,
        comment: String?
    ) async {
        let body = CreateVisitBody(
            visitedAt: visitedAt,
            comment: comment,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            postalCode: postalCode,
            city: city,
            openingHours: openingHours
        )
        do {
            let _: VisitResponse = try await APIClient.shared.post(
                "places/by_osm/\(osmNodeID)/visits",
                body: body
            )
        } catch APIError.unauthorized {
            // Not signed in — local-only visit is fine.
        } catch {
            print("[VisitSync] failed: \(error.localizedDescription)")
        }
    }
}
