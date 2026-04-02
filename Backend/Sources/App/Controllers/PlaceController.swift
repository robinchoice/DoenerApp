import Vapor
import Fluent
import DoenerShared

struct PlaceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let places = routes.grouped("places")
        places.get(use: nearby)
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
            reviewCount: reviewCount
        )
    }
}
