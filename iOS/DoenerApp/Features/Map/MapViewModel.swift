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
    var visitCounts: [Int64: Int] = [:]

    private var modelContext: ModelContext?
    private var lastFetchedRegion: MKCoordinateRegion?
    private var activeFetchTask: Task<Void, Never>?

    /// Skip Overpass entirely above this span — query would time out and the
    /// result would be useless dot-soup anyway.
    private let maxFetchableSpan: Double = 0.5

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCachedPlaces()
        loadVisitCounts()
    }

    func onRegionChanged(_ region: MKCoordinateRegion) async {
        // Skip absurdly large spans — Overpass times out, user gets nothing useful.
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

        isLoading = true
        errorMessage = nil

        do {
            let elements = try await OverpassClient.fetchDoenerPlaces(in: region)

            for element in elements {
                guard let lat = element.coordinateLat, let lon = element.coordinateLon else { continue }
                let tags = element.tags ?? [:]
                let name = tags["name"] ?? "Döner"

                // OSM nodes/ways/relations share an Int64 namespace but IDs can collide.
                // Encode type into the stored ID: nodes positive, ways negative,
                // relations negated + large offset. Cleaned up in Phase 0 (backend Shop entity).
                let osmID: Int64
                switch element.type {
                case "way":      osmID = -element.id
                case "relation": osmID = -(element.id + 1_000_000_000_000)
                default:         osmID = element.id
                }
                let descriptor = FetchDescriptor<CachedPlace>(
                    predicate: #Predicate { $0.osmNodeID == osmID }
                )
                let existing = try modelContext.fetch(descriptor)

                if let place = existing.first {
                    place.name = name
                    place.latitude = lat
                    place.longitude = lon
                    place.address = [tags["addr:street"], tags["addr:housenumber"]].compactMap { $0 }.joined(separator: " ")
                    place.postalCode = tags["addr:postcode"]
                    place.city = tags["addr:city"]
                    place.openingHours = tags["opening_hours"]
                    place.lastSyncedAt = Date()
                } else {
                    let place = CachedPlace(
                        osmNodeID: osmID,
                        name: name,
                        latitude: lat,
                        longitude: lon,
                        address: [tags["addr:street"], tags["addr:housenumber"]].compactMap { $0 }.joined(separator: " "),
                        postalCode: tags["addr:postcode"],
                        city: tags["addr:city"],
                        openingHours: tags["opening_hours"]
                    )
                    modelContext.insert(place)
                }
            }

            try modelContext.save()
            lastFetchedRegion = region
            loadCachedPlaces()

            // Overlay backend community data (ratings, specialNote) onto cached places — non-blocking
            Task { [weak self] in
                await self?.mergeBackendPlaces(region: region, modelContext: modelContext)
            }
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

    // MARK: - Backend Overlay

    private struct BackendPlace: Decodable {
        let osmNodeID: Int64
        let avgRating: Double?
        let reviewCount: Int
        let specialNote: String?
    }

    private func mergeBackendPlaces(region: MKCoordinateRegion, modelContext: ModelContext) async {
        let lat = String(region.center.latitude)
        let lon = String(region.center.longitude)
        // Radius in meters — approximate from span (1° lat ≈ 111km)
        let radiusM = String(Int(region.span.latitudeDelta * 111_000))

        do {
            let backendPlaces: [BackendPlace] = try await APIClient.shared.get(
                "places", query: ["lat": lat, "lon": lon, "radius": radiusM]
            )
            for bp in backendPlaces {
                let osmID = bp.osmNodeID
                let descriptor = FetchDescriptor<CachedPlace>(
                    predicate: #Predicate { $0.osmNodeID == osmID }
                )
                guard let cached = try modelContext.fetch(descriptor).first else { continue }
                cached.avgRating = bp.avgRating
                cached.reviewCount = bp.reviewCount
                if let note = bp.specialNote { cached.specialNote = note }
            }
            try modelContext.save()
            loadCachedPlaces()
        } catch {
            // Backend overlay is best-effort — don't show errors for this
            print("[MapVM] Backend overlay failed: \(error.localizedDescription)")
        }
    }

    func loadVisitCounts() {
        guard let modelContext else { return }
        do {
            let descriptor = FetchDescriptor<Visit>()
            let allVisits = try modelContext.fetch(descriptor)
            visitCounts = Dictionary(grouping: allVisits, by: \.placeOsmNodeID)
                .mapValues(\.count)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
