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

        // GET /api/v1/places/by_osm/:osmNodeID/summary — community summary
        routes.get("places", "by_osm", ":osmNodeID", "summary", use: placeSummary)
    }

    /// Body for review upsert. Includes the OSM place metadata so the backend
    /// can lazily create the DoenerPlace row if it doesn't exist yet.
    struct UpsertBody: Content {
        let rating: Int
        let sauceRating: Int?
        let fleischRating: Int?
        let brotRating: Int?
        let text: String?
        let specialNote: String?
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
        for (name, value) in [("sauceRating", body.sauceRating), ("fleischRating", body.fleischRating), ("brotRating", body.brotRating)] {
            if let v = value, !(1...5).contains(v) {
                throw Abort(.badRequest, reason: "\(name) must be 1-5")
            }
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
            existing.sauceRating = body.sauceRating
            existing.fleischRating = body.fleischRating
            existing.brotRating = body.brotRating
            existing.text = body.text
            try await existing.save(on: req.db)
            review = existing
        } else {
            let r = Review(userID: userID, placeID: placeID, rating: body.rating,
                           sauceRating: body.sauceRating, fleischRating: body.fleischRating,
                           brotRating: body.brotRating, text: body.text)
            try await r.save(on: req.db)
            review = r
        }

        // Always update special note — nil means "clear"
        place.specialNote = body.specialNote
        try await place.save(on: req.db)

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

    @Sendable
    func placeSummary(req: Request) async throws -> PlaceSummaryDTO {
        guard let osmIDString = req.parameters.get("osmNodeID"),
              let osmNodeID = Int64(osmIDString) else {
            throw Abort(.badRequest, reason: "osmNodeID must be Int64")
        }
        guard let place = try await DoenerPlace.query(on: req.db)
            .filter(\.$osmNodeID == osmNodeID)
            .first() else {
            return PlaceSummaryDTO(reviewCount: 0, avgRating: nil, avgSauceRating: nil,
                                   avgFleischRating: nil, avgBrotRating: nil,
                                   topDimension: nil, summaryText: "Noch keine Bewertungen.")
        }
        let placeID = try place.requireID()
        let reviews = try await Review.query(on: req.db)
            .filter(\.$place.$id == placeID)
            .all()

        guard !reviews.isEmpty else {
            return PlaceSummaryDTO(reviewCount: 0, avgRating: nil, avgSauceRating: nil,
                                   avgFleischRating: nil, avgBrotRating: nil,
                                   topDimension: nil, summaryText: "Noch keine Bewertungen.")
        }

        let count = reviews.count
        let avgRating = Double(reviews.reduce(0) { $0 + $1.rating }) / Double(count)

        // Dimension averages (only from reviews that have them)
        func dimAvg(_ extract: (Review) -> Int?) -> Double? {
            let vals = reviews.compactMap(extract)
            guard !vals.isEmpty else { return nil }
            return Double(vals.reduce(0, +)) / Double(vals.count)
        }
        let avgSauce = dimAvg(\.sauceRating)
        let avgFleisch = dimAvg(\.fleischRating)
        let avgBrot = dimAvg(\.brotRating)

        // Find top dimension
        let dims: [(String, Double)] = [
            ("Soße", avgSauce), ("Fleisch", avgFleisch), ("Brot", avgBrot)
        ].compactMap { name, avg in avg.map { (name, $0) } }
        let topDim = dims.max(by: { $0.1 < $1.1 })?.0

        // Build summary text
        var parts: [String] = []
        let ratingWord: String
        switch Int(avgRating.rounded()) {
        case 5: ratingWord = "ausgezeichnet"
        case 4: ratingWord = "gut"
        case 3: ratingWord = "okay"
        case 2: ratingWord = "mäßig"
        default: ratingWord = "schlecht"
        }
        parts.append("\(count) \(count == 1 ? "Bewertung" : "Bewertungen"), insgesamt \(ratingWord) (\(String(format: "%.1f", avgRating))/5).")

        if let top = topDim, let topAvg = dims.first(where: { $0.0 == top })?.1, topAvg >= 3.5 {
            parts.append("\(top) wird besonders gelobt (\(String(format: "%.1f", topAvg))/5).")
        }

        if let note = place.specialNote, !note.isEmpty {
            parts.append("Bekannt für: \(note).")
        }

        // Extract snippets from review texts
        let texts = reviews.compactMap(\.text).filter { !$0.isEmpty }
        if let latest = texts.first {
            let snippet = latest.count > 80 ? String(latest.prefix(77)) + "…" : latest
            parts.append("\u{201E}\(snippet)\u{201C}")
        }

        return PlaceSummaryDTO(
            reviewCount: count,
            avgRating: avgRating,
            avgSauceRating: avgSauce,
            avgFleischRating: avgFleisch,
            avgBrotRating: avgBrot,
            topDimension: topDim,
            summaryText: parts.joined(separator: " ")
        )
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
            sauceRating: sauceRating,
            fleischRating: fleischRating,
            brotRating: brotRating,
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
