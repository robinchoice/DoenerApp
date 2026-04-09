import Vapor
import Fluent
import DoenerShared

struct ReviewController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware())

        // POST /api/v1/places/by_osm/:osmNodeID/reviews — upsert place + review
        protected.post("places", "by_osm", ":osmNodeID", "reviews", use: upsertReview)

        // GET /api/v1/places/by_osm/:osmNodeID/reviews — public list of reviews for a place
        routes.get("places", "by_osm", ":osmNodeID", "reviews", use: listReviewsByOSM)
    }

    /// Body for review upsert. Includes the OSM place metadata so the backend
    /// can lazily create the DoenerPlace row if it doesn't exist yet.
    struct UpsertBody: Content {
        let rating: Int
        let text: String?
        // Place metadata used to upsert the DoenerPlace if it doesn't exist
        let name: String
        let latitude: Double
        let longitude: Double
        let address: String?
        let postalCode: String?
        let city: String?
        let openingHours: String?
    }

    @Sendable
    func upsertReview(req: Request) async throws -> ReviewDTO {
        let user = try req.auth.require(User.self)
        guard let osmIDString = req.parameters.get("osmNodeID"),
              let osmNodeID = Int64(osmIDString) else {
            throw Abort(.badRequest, reason: "osmNodeID must be Int64")
        }
        let body = try req.content.decode(UpsertBody.self)
        guard (1...5).contains(body.rating) else {
            throw Abort(.badRequest, reason: "rating must be 1-5")
        }

        // Upsert the place
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

        // Upsert the review (one per user-place)
        let review: Review
        if let existing = try await Review.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$place.$id == placeID)
            .first() {
            existing.rating = body.rating
            existing.text = body.text
            try await existing.save(on: req.db)
            review = existing
        } else {
            let r = Review(userID: userID, placeID: placeID, rating: body.rating, text: body.text)
            try await r.save(on: req.db)
            review = r
        }

        // Recompute aggregate rating + count on the place
        try await DoenerPlace.recomputeRatingAggregates(placeID: placeID, on: req.db)

        return review.toDTO(userName: user.displayName, placeID: placeID)
    }

    @Sendable
    func listReviewsByOSM(req: Request) async throws -> [ReviewDTO] {
        guard let osmIDString = req.parameters.get("osmNodeID"),
              let osmNodeID = Int64(osmIDString) else {
            throw Abort(.badRequest, reason: "osmNodeID must be Int64")
        }
        guard let place = try await DoenerPlace.query(on: req.db)
            .filter(\.$osmNodeID == osmNodeID)
            .first() else {
            return []
        }
        let placeID = try place.requireID()

        let reviews = try await Review.query(on: req.db)
            .filter(\.$place.$id == placeID)
            .sort(\.$createdAt, .descending)
            .with(\.$user)
            .all()

        return reviews.map { $0.toDTO(userName: $0.user.displayName, placeID: placeID) }
    }
}

extension Review {
    func toDTO(userName: String, placeID: UUID) -> ReviewDTO {
        ReviewDTO(
            id: id ?? UUID(),
            userID: $user.id,
            userName: userName,
            placeID: placeID,
            rating: rating,
            text: text,
            imageURLs: [],
            createdAt: createdAt ?? Date(),
            updatedAt: updatedAt ?? Date()
        )
    }
}

extension DoenerPlace {
    /// Find an existing place by OSM node ID, or create one. Updates non-id fields
    /// when found so we keep the cached metadata fresh.
    static func upsert(
        osmNodeID: Int64,
        name: String,
        latitude: Double,
        longitude: Double,
        address: String?,
        postalCode: String?,
        city: String?,
        openingHours: String?,
        on db: any Database
    ) async throws -> DoenerPlace {
        if let existing = try await DoenerPlace.query(on: db)
            .filter(\.$osmNodeID == osmNodeID)
            .first() {
            existing.name = name
            existing.latitude = latitude
            existing.longitude = longitude
            existing.address = address
            existing.postalCode = postalCode
            existing.city = city
            existing.openingHours = openingHours
            try await existing.save(on: db)
            return existing
        }
        let place = DoenerPlace(
            osmNodeID: osmNodeID,
            name: name,
            latitude: latitude,
            longitude: longitude,
            address: address,
            postalCode: postalCode,
            city: city,
            openingHours: openingHours
        )
        try await place.save(on: db)
        return place
    }

    static func recomputeRatingAggregates(placeID: UUID, on db: any Database) async throws {
        let reviews = try await Review.query(on: db)
            .filter(\.$place.$id == placeID)
            .all()
        guard let place = try await DoenerPlace.find(placeID, on: db) else { return }
        if reviews.isEmpty {
            place.avgRating = nil
            place.reviewCount = 0
        } else {
            let total = reviews.reduce(0) { $0 + $1.rating }
            place.avgRating = Double(total) / Double(reviews.count)
            place.reviewCount = reviews.count
        }
        try await place.save(on: db)
    }
}
