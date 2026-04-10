import Foundation

/// Pushes locally-created reviews to the backend.
/// Fire-and-forget: silently skips if not authenticated, logs other errors to console.
enum ReviewSyncService {
    struct UpsertReviewBody: Encodable {
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

    static func push(
        osmNodeID: Int64,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String?,
        postalCode: String?,
        city: String?,
        openingHours: String?,
        rating: Int,
        sauceRating: Int?,
        fleischRating: Int?,
        brotRating: Int?,
        text: String?,
        specialNote: String?
    ) async {
        let body = UpsertReviewBody(
            rating: rating,
            sauceRating: sauceRating,
            fleischRating: fleischRating,
            brotRating: brotRating,
            text: text,
            specialNote: specialNote,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            postalCode: postalCode,
            city: city,
            openingHours: openingHours
        )
        do {
            let _: ReviewResponse = try await APIClient.shared.post(
                "places/by_osm/\(osmNodeID)/reviews",
                body: body
            )
        } catch APIError.unauthorized {
            // Not signed in — local-only review is fine.
        } catch {
            print("[ReviewSync] failed: \(error.localizedDescription)")
        }
    }
}
