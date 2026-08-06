import Vapor
import Fluent
import DoenerShared

struct PlaceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let places = routes.grouped("places")
        places.get(use: nearby)
        places.get("search", use: search)
        places.get("top_nearby", use: topNearby)
        places.get("trending", use: trending)
        places.get(":placeID", use: getPlace)
    }

    @Sendable
    func nearby(req: Request) async throws -> [PlaceDTO] {
        guard let lat = req.query[Double.self, at: "lat"],
              let lon = req.query[Double.self, at: "lon"] else {
            throw Abort(.badRequest, reason: "lat and lon query parameters required")
        }
        let radius = req.query[Double.self, at: "radius"] ?? 5000 // meters

        // Simple distance filter using bounding box approximation
        // 1 degree latitude ≈ 111km, 1 degree longitude ≈ 111km * cos(lat)
        let latDelta = radius / 111_000.0
        let lonDelta = radius / (111_000.0 * cos(lat * .pi / 180))

        let places = try await DoenerPlace.query(on: req.db)
            .filter(\.$latitude >= lat - latDelta)
            .filter(\.$latitude <= lat + latDelta)
            .filter(\.$longitude >= lon - lonDelta)
            .filter(\.$longitude <= lon + lonDelta)
            .limit(200)
            .all()

        return places.map { $0.toDTO() }
    }

    /// GET /places/search — replaces the old client-side Overpass/OSM lookup.
    /// Queries Google Places only when nothing nearby has been synced
    /// recently (cost guard), then returns the full cached radius (fresh +
    /// already-known places, community ratings included).
    @Sendable
    func search(req: Request) async throws -> [PlaceDTO] {
        guard let lat = req.query[Double.self, at: "lat"],
              let lon = req.query[Double.self, at: "lon"] else {
            throw Abort(.badRequest, reason: "lat and lon query parameters required")
        }
        let radius = req.query[Double.self, at: "radius"] ?? 1500

        let latDelta = radius / 111_000.0
        let lonDelta = radius / (111_000.0 * cos(lat * .pi / 180))

        func cachedPlacesInRadius() async throws -> [DoenerPlace] {
            try await DoenerPlace.query(on: req.db)
                .filter(\.$latitude >= lat - latDelta)
                .filter(\.$latitude <= lat + latDelta)
                .filter(\.$longitude >= lon - lonDelta)
                .filter(\.$longitude <= lon + lonDelta)
                .limit(200)
                .all()
        }

        // Cost guard: skip Google entirely if this radius was already synced
        // recently — avoids paying Google on every map pan.
        let recentCutoff = Date().addingTimeInterval(-24 * 60 * 60)
        let recentlySyncedCount = try await DoenerPlace.query(on: req.db)
            .filter(\.$latitude >= lat - latDelta)
            .filter(\.$latitude <= lat + latDelta)
            .filter(\.$longitude >= lon - lonDelta)
            .filter(\.$longitude <= lon + lonDelta)
            .filter(\.$updatedAt >= recentCutoff)
            .count()

        guard recentlySyncedCount == 0 else {
            return try await cachedPlacesInRadius().map { $0.toDTO() }
        }

        guard let apiKey = Environment.get("GOOGLE_PLACES_API_KEY") else {
            req.logger.warning("GOOGLE_PLACES_API_KEY not configured — returning cached places only")
            return try await cachedPlacesInRadius().map { $0.toDTO() }
        }

        let googlePlaces = try await GooglePlacesClient.searchNearby(
            latitude: lat, longitude: lon, radiusMeters: radius, apiKey: apiKey, client: req.client
        )

        for gp in googlePlaces {
            guard gp.businessStatus != "CLOSED_PERMANENTLY" else { continue }
            guard GooglePlacesClient.looksLikeDoener(gp) else { continue }

            let (address, postalCode, city) = mapAddress(gp.addressComponents)
            _ = try await DoenerPlace.upsert(
                placeID: gp.id,
                name: gp.displayName.text,
                latitude: gp.location.latitude,
                longitude: gp.location.longitude,
                address: address,
                postalCode: postalCode,
                city: city,
                openingHours: gp.regularOpeningHours?.weekdayDescriptions?.joined(separator: "\n"),
                on: req.db
            )
        }

        return try await cachedPlacesInRadius().map { $0.toDTO() }
    }

    private func mapAddress(
        _ components: [GooglePlacesClient.GooglePlace.AddressComponent]?
    ) -> (address: String?, postalCode: String?, city: String?) {
        guard let components else { return (nil, nil, nil) }
        func value(for type: String) -> String? {
            components.first(where: { $0.types.contains(type) })?.longText
        }
        let street = value(for: "route")
        let houseNumber = value(for: "street_number")
        let address = [street, houseNumber].compactMap { $0 }.joined(separator: " ")
        let postalCode = value(for: "postal_code")
        let city = value(for: "locality") ?? value(for: "postal_town")
        return (address.isEmpty ? nil : address, postalCode, city)
    }

    @Sendable
    func topNearby(req: Request) async throws -> [PlaceDTO] {
        guard let lat = req.query[Double.self, at: "lat"],
              let lon = req.query[Double.self, at: "lon"] else {
            throw Abort(.badRequest, reason: "lat and lon query parameters required")
        }
        let radius = req.query[Double.self, at: "radius"] ?? 3000
        let limit = req.query[Int.self, at: "limit"] ?? 10

        let latDelta = radius / 111_000.0
        let lonDelta = radius / (111_000.0 * cos(lat * .pi / 180))

        let places = try await DoenerPlace.query(on: req.db)
            .filter(\.$latitude >= lat - latDelta)
            .filter(\.$latitude <= lat + latDelta)
            .filter(\.$longitude >= lon - lonDelta)
            .filter(\.$longitude <= lon + lonDelta)
            .filter(\.$reviewCount > 0)
            .sort(\.$avgRating, .descending)
            .limit(limit)
            .all()

        return places.map { $0.toDTO() }
    }

    @Sendable
    func trending(req: Request) async throws -> [PlaceDTO] {
        let days = req.query[Int.self, at: "days"] ?? 7
        let limit = req.query[Int.self, at: "limit"] ?? 10
        let cutoff = Date().addingTimeInterval(-Double(days) * 86400)

        // Collect recent reviews and visits, count per place
        let recentReviews = try await Review.query(on: req.db)
            .filter(\.$createdAt >= cutoff)
            .all()
        let recentVisits = try await Visit.query(on: req.db)
            .filter(\.$visitedAt >= cutoff)
            .all()

        var activityCounts: [UUID: Int] = [:]
        for r in recentReviews { activityCounts[r.$place.id, default: 0] += 1 }
        for v in recentVisits { activityCounts[v.$place.id, default: 0] += 1 }

        let topPlaceIDs = activityCounts.sorted { $0.value > $1.value }
            .prefix(limit)
            .map(\.key)

        guard !topPlaceIDs.isEmpty else { return [] }

        let places = try await DoenerPlace.query(on: req.db)
            .filter(\.$id ~~ topPlaceIDs)
            .all()

        // Preserve activity-count ordering
        let placeMap = Dictionary(uniqueKeysWithValues: places.compactMap { p in
            p.id.map { ($0, p) }
        })
        return topPlaceIDs.compactMap { placeMap[$0]?.toDTO() }
    }

    @Sendable
    func getPlace(req: Request) async throws -> PlaceDTO {
        guard let placeID = req.parameters.get("placeID") else {
            throw Abort(.badRequest)
        }
        guard let place = try await DoenerPlace.query(on: req.db)
            .filter(\.$placeID == placeID)
            .first() else {
            throw Abort(.notFound)
        }
        return place.toDTO()
    }
}

extension DoenerPlace {
    func toDTO() -> PlaceDTO {
        PlaceDTO(
            id: id ?? UUID(),
            placeID: placeID,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            postalCode: postalCode,
            city: city,
            openingHours: openingHours,
            avgRating: avgRating,
            reviewCount: reviewCount,
            specialNote: specialNote
        )
    }
}
