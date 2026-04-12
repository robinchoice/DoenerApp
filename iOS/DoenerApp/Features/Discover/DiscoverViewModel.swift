import SwiftUI
import SwiftData
import CoreLocation

@MainActor @Observable
final class DiscoverViewModel {
    var searchQuery = ""
    var searchResults: [CachedPlace] = []
    var nearbyPlaces: [DiscoverPlace] = []
    var trendingPlaces: [DiscoverPlace] = []
    var recentReviews: [FeedEntry] = []
    var isLoading = false

    private var modelContext: ModelContext?
    private var locationManager: LocationManager?

    struct DiscoverPlace: Identifiable, Decodable {
        let id: UUID
        let osmNodeID: Int64
        let name: String
        let latitude: Double
        let longitude: Double
        let address: String?
        let city: String?
        let avgRating: Double?
        let reviewCount: Int
        let specialNote: String?
    }

    func setup(modelContext: ModelContext, locationManager: LocationManager) {
        self.modelContext = modelContext
        self.locationManager = locationManager
    }

    func refresh() async {
        isLoading = true
        async let n: () = loadNearby()
        async let t: () = loadTrending()
        loadRecentReviews()
        await n
        await t
        isLoading = false
    }

    func search() {
        guard let modelContext else { return }
        let query = searchQuery
        guard !query.isEmpty else { searchResults = []; return }

        let descriptor = FetchDescriptor<CachedPlace>(
            sortBy: [SortDescriptor(\.name)]
        )
        guard let all = try? modelContext.fetch(descriptor) else {
            searchResults = []
            return
        }
        searchResults = all.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    private func loadNearby() async {
        guard let loc = locationManager?.userLocation else { return }
        let lat = String(loc.coordinate.latitude)
        let lon = String(loc.coordinate.longitude)
        do {
            nearbyPlaces = try await APIClient.shared.get(
                "places/top_nearby", query: ["lat": lat, "lon": lon, "radius": "5000", "limit": "10"]
            )
        } catch {
            print("[Discover] nearby failed: \(error.localizedDescription)")
        }
    }

    private func loadTrending() async {
        do {
            trendingPlaces = try await APIClient.shared.get(
                "places/trending", query: ["days": "7", "limit": "10"]
            )
        } catch {
            print("[Discover] trending failed: \(error.localizedDescription)")
        }
    }

    private func loadRecentReviews() {
        guard let modelContext else { return }
        var descriptor = FetchDescriptor<Review>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 10
        guard let reviews = try? modelContext.fetch(descriptor) else { return }
        recentReviews = reviews.map { review in
            FeedEntry(
                id: review.persistentModelID.hashValue,
                type: .review,
                placeName: review.placeName,
                timestamp: review.createdAt,
                comment: review.text,
                rating: review.rating
            )
        }
    }

    /// Upsert a backend DiscoverPlace into SwiftData so PlaceDetailView can use it
    func cachedPlace(for dp: DiscoverPlace) -> CachedPlace? {
        guard let modelContext else { return nil }
        let osmID = dp.osmNodeID
        let descriptor = FetchDescriptor<CachedPlace>(
            predicate: #Predicate { $0.osmNodeID == osmID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.avgRating = dp.avgRating
            existing.reviewCount = dp.reviewCount
            if let note = dp.specialNote { existing.specialNote = note }
            try? modelContext.save()
            return existing
        }
        let place = CachedPlace(
            osmNodeID: dp.osmNodeID,
            name: dp.name,
            latitude: dp.latitude,
            longitude: dp.longitude,
            address: dp.address,
            city: dp.city
        )
        place.avgRating = dp.avgRating
        place.reviewCount = dp.reviewCount
        place.specialNote = dp.specialNote
        modelContext.insert(place)
        try? modelContext.save()
        return place
    }
}
