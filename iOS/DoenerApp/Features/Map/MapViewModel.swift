import SwiftUI
import SwiftData
import MapKit

@MainActor @Observable
final class MapViewModel {
    var places: [CachedPlace] = []
    var selectedPlace: CachedPlace?
    var isLoading = false
    var errorMessage: String?
    // Freiburg fallback
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.999, longitude: 7.842),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )))
    var visitCounts: [String: Int] = [:]

    private var modelContext: ModelContext?
    private var lastFetchedRegion: MKCoordinateRegion?
    private var activeFetchTask: Task<Void, Never>?

    /// Skip fetching entirely above this span — the result would be useless
    /// dot-soup anyway.
    private let maxFetchableSpan: Double = 0.5

    private struct SearchPlace: Decodable {
        let placeID: String
        let name: String
        let latitude: Double
        let longitude: Double
        let address: String?
        let postalCode: String?
        let city: String?
        let openingHours: String?
        let avgRating: Double?
        let reviewCount: Int
        let specialNote: String?
    }

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCachedPlaces()
        loadVisitCounts()
    }

    func onRegionChanged(_ region: MKCoordinateRegion) async {
        // Skip absurdly large spans — the query would time out and the
        // result would be useless dot-soup anyway.
        guard region.span.latitudeDelta < maxFetchableSpan,
              region.span.longitudeDelta < maxFetchableSpan else {
            return
        }
        guard shouldFetch(for: region) else { return }

        // Cancel any in-flight fetch — the user has moved on.
        activeFetchTask?.cancel()
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.fetchPlaces(in: region)
        }
        activeFetchTask = task
        await task.value
    }

    private func shouldFetch(for region: MKCoordinateRegion) -> Bool {
        guard let last = lastFetchedRegion else { return true }

        let latDiff = abs(region.center.latitude - last.center.latitude)
        let lonDiff = abs(region.center.longitude - last.center.longitude)

        // Fetch when user has panned more than 30% of the previous span
        return latDiff > last.span.latitudeDelta * 0.3 ||
               lonDiff > last.span.longitudeDelta * 0.3
    }

    func fetchPlaces(in region: MKCoordinateRegion) async {
        guard let modelContext else { return }

        // Cost guard: skip the backend entirely if this region was already
        // synced recently — avoids paying Google on every map pan.
        guard !isRegionCovered(region) else {
            lastFetchedRegion = region
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let lat = String(region.center.latitude)
            let lon = String(region.center.longitude)
            let radiusM = String(Int(region.span.latitudeDelta * 111_000))

            let results: [SearchPlace] = try await APIClient.shared.get(
                "places/search", query: ["lat": lat, "lon": lon, "radius": radiusM]
            )

            for sp in results {
                let placeID = sp.placeID
                let descriptor = FetchDescriptor<CachedPlace>(
                    predicate: #Predicate { $0.placeID == placeID }
                )
                let existing = try modelContext.fetch(descriptor)

                let place: CachedPlace
                if let found = existing.first {
                    found.name = sp.name
                    found.latitude = sp.latitude
                    found.longitude = sp.longitude
                    found.address = sp.address
                    found.postalCode = sp.postalCode
                    found.city = sp.city
                    found.openingHours = sp.openingHours
                    found.lastSyncedAt = Date()
                    place = found
                } else {
                    place = CachedPlace(
                        placeID: sp.placeID,
                        name: sp.name,
                        latitude: sp.latitude,
                        longitude: sp.longitude,
                        address: sp.address,
                        postalCode: sp.postalCode,
                        city: sp.city,
                        openingHours: sp.openingHours
                    )
                    modelContext.insert(place)
                }
                place.avgRating = sp.avgRating
                place.reviewCount = sp.reviewCount
                if let note = sp.specialNote { place.specialNote = note }
            }

            try modelContext.save()
            lastFetchedRegion = region
            recordFetchedRegion(region)
            loadCachedPlaces()
        } catch is CancellationError {
            // Ignore cancellation from region changes
        } catch let urlError as URLError where urlError.code == .cancelled {
            // Ignore cancelled network requests
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadCachedPlaces() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<CachedPlace>(
                sortBy: [SortDescriptor(\.name)]
            )
            places = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Region cache (cost guard)

    private func isRegionCovered(_ region: MKCoordinateRegion) -> Bool {
        guard let modelContext else { return false }
        guard let regions = try? modelContext.fetch(FetchDescriptor<CachedRegion>()) else { return false }
        return regions.contains { cached in
            !cached.isStale && cached.contains(latitude: region.center.latitude, longitude: region.center.longitude)
        }
    }

    private func recordFetchedRegion(_ region: MKCoordinateRegion) {
        guard let modelContext else { return }
        let south = region.center.latitude - region.span.latitudeDelta / 2
        let north = region.center.latitude + region.span.latitudeDelta / 2
        let west = region.center.longitude - region.span.longitudeDelta / 2
        let east = region.center.longitude + region.span.longitudeDelta / 2
        modelContext.insert(CachedRegion(minLat: south, maxLat: north, minLon: west, maxLon: east))
        try? modelContext.save()
    }

    func loadVisitCounts() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Visit>()
            let allVisits = try modelContext.fetch(descriptor)
            visitCounts = Dictionary(grouping: allVisits, by: \.placeID)
                .mapValues(\.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
