import Vapor
import Fluent
import DoenerShared

struct VisitController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware())

        // POST /api/v1/places/:placeID/visits — record a visit (and upsert the place)
        protected.post("places", ":placeID", "visits", use: createVisit)
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
        guard let placeID = req.parameters.get("placeID") else {
            throw Abort(.badRequest, reason: "placeID required")
        }
        let body = try req.content.decode(CreateBody.self)

        let place = try await DoenerPlace.upsert(
            placeID: placeID,
            name: body.name,
            latitude: body.latitude,
            longitude: body.longitude,
            address: body.address,
            postalCode: body.postalCode,
            city: body.city,
            openingHours: body.openingHours,
            on: req.db
        )
        let doenerPlaceID = try place.requireID()
        let userID = try user.requireID()

        let visit = Visit(
            userID: userID,
            placeID: doenerPlaceID,
            visitedAt: body.visitedAt,
            comment: body.comment
        )
        try await visit.save(on: req.db)

        // Set live status for 2 hours
        user.$livePlace.id = doenerPlaceID
        user.liveStatusUntil = Date().addingTimeInterval(2 * 60 * 60)
        user.liveFoodType = body.foodType
        try await user.save(on: req.db)

        return visit.toDTO(userName: user.displayName, placeID: doenerPlaceID, placeName: place.name)
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
