import Vapor
import Fluent
import DoenerShared

struct VisitController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware())

        // POST /api/v1/places/by_osm/:osmNodeID/visits — record a visit (and upsert the place)
        protected.post("places", "by_osm", ":osmNodeID", "visits", use: createVisit)
    }

    /// Same shape as the review upsert body — backend lazily creates the
    /// DoenerPlace row if it doesn't exist yet.
    struct CreateBody: Content {
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

    @Sendable
    func createVisit(req: Request) async throws -> VisitDTO {
        let user = try req.auth.require(User.self)
        guard let osmIDString = req.parameters.get("osmNodeID"),
              let osmNodeID = Int64(osmIDString) else {
            throw Abort(.badRequest, reason: "osmNodeID must be Int64")
        }
        let body = try req.content.decode(CreateBody.self)

        let place = try await DoenerPlace.upsert(
            osmNodeID: osmNodeID,
            name: body.name,
            latitude: body.latitude,
            longitude: body.longitude,
            address: body.address,
            postalCode: body.postalCode,
            city: body.city,
            openingHours: body.openingHours,
            on: req.db
        )
        let placeID = try place.requireID()
        let userID = try user.requireID()

        let visit = Visit(
            userID: userID,
            placeID: placeID,
            visitedAt: body.visitedAt,
            comment: body.comment
        )
        try await visit.save(on: req.db)

        // Set live status for 2 hours
        user.$livePlace.id = placeID
        user.liveStatusUntil = Date().addingTimeInterval(2 * 60 * 60)
        user.liveFoodType = body.foodType
        try await user.save(on: req.db)

        return visit.toDTO(userName: user.displayName, placeID: placeID, placeName: place.name)
    }
}

extension Visit {
    func toDTO(userName: String, placeID: UUID, placeName: String) -> VisitDTO {
        VisitDTO(
            id: id ?? UUID(),
            userID: $user.id,
            userName: userName,
            placeID: placeID,
            placeName: placeName,
            visitedAt: visitedAt,
            comment: comment
        )
    }
}
