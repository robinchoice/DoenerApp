import SwiftUI
import SwiftData
import MapKit

@MainActor @Observable
final class MapViewModel {
    var places: [CachedPlace] = []
    var selectedPlace: CachedPlace?
    var isLoading = false
    var errorMessage: String?
    var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)

    private var modelContext: ModelContext?
    private var lastFetchedRegion: MKCoordinateRegion?

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadCachedPlaces()
    }

    func onRegionChanged(_ region: MKCoordinateRegion) async {
        guard !isLoading else { return }
        guard shouldFetch(for: region) else { return }

        await fetchPlaces(in: region)
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
                guard let lat = element.lat, let lon = element.lon else { continue }
                let tags = element.tags ?? [:]
                let name = tags["name"] ?? "Döner"

                // Check if place already exists
                let osmID = element.id
                let descriptor = FetchDescriptor<CachedPlace>(
                    predicate: #Predicate { $0.osmNodeID == osmID }
                )
                let existing = try modelContext.fetch(descriptor)

                if let place = existing.first {
                    // Update existing
                    place.name = name
                    place.latitude = lat
                    place.longitude = lon
                    place.address = [tags["addr:street"], tags["addr:housenumber"]].compactMap { $0 }.joined(separator: " ")
                    place.postalCode = tags["addr:postcode"]
                    place.city = tags["addr:city"]
                    place.openingHours = tags["opening_hours"]
                    place.lastSyncedAt = Date()
                } else {
                    // Create new
                    let place = CachedPlace(
                        osmNodeID: element.id,
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
}
