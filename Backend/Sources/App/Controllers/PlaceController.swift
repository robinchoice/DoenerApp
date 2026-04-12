import Vapor
import Fluent
import DoenerShared

struct PlaceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let places = routes.grouped("places")
        places.get(use: nearby)
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
        guard let place = try await DoenerPlace.find(req.parameters.get("placeID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return place.toDTO()
    }
}

extension DoenerPlace {
    func toDTO() -> PlaceDTO {
        PlaceDTO(
            id: id ?? UUID(),
            osmNodeID: osmNodeID,
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
