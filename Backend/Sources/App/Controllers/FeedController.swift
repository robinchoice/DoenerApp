import Vapor
import Fluent
import DoenerShared
import Foundation

struct FeedPage: Content {
    let items: [FeedItem]
    let cursor: String?
    let hasMore: Bool
}

struct FeedController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware())
        protected.get("feed", use: feed)
        protected.get("feed", "live", use: liveStatuses)
        protected.delete("me", "live-status", use: clearLiveStatus)
    }

    // Helper: accepted friend IDs in both directions
    static func acceptedFriendIDs(for userID: UUID, on db: any Database) async throws -> [UUID] {
        let asRequester = try await Friendship.query(on: db)
            .filter(\.$requester.$id == userID)
            .filter(\.$status == .accepted)
            .all()
        let asAddressee = try await Friendship.query(on: db)
            .filter(\.$addressee.$id == userID)
            .filter(\.$status == .accepted)
            .all()
        return asRequester.map { $0.$addressee.id } + asAddressee.map { $0.$requester.id }
    }

    // GET /feed?limit=20&cursor=<iso8601>
    @Sendable
    func feed(req: Request) async throws -> FeedPage {
        let me = try req.auth.require(User.self)
        let myID = try me.requireID()
        let pageSize = min(req.query[Int.self, at: "limit"] ?? 20, 50)

        let friendIDs = try await Self.acceptedFriendIDs(for: myID, on: req.db)
        guard !friendIDs.isEmpty else {
            return FeedPage(items: [], cursor: nil, hasMore: false)
        }

        let formatter = ISO8601DateFormatter()
        let cursorDate: Date? = req.query[String.self, at: "cursor"].flatMap { formatter.date(from: $0) }

        // Fetch visits from friends
        var visitQuery = Visit.query(on: req.db)
            .filter(\.$user.$id ~~ friendIDs)
            .with(\.$user)
            .with(\.$place)
            .sort(\.$visitedAt, .descending)
            .limit(pageSize)
        if let cursor = cursorDate {
            visitQuery = visitQuery.filter(\.$visitedAt < cursor)
        }
        let visits = try await visitQuery.all()

        // Fetch reviews from friends
        var reviewQuery = Review.query(on: req.db)
            .filter(\.$user.$id ~~ friendIDs)
            .with(\.$user)
            .with(\.$place)
            .sort(\.$createdAt, .descending)
            .limit(pageSize)
        if let cursor = cursorDate {
            reviewQuery = reviewQuery.filter(\.$createdAt < cursor)
        }
        let reviews = try await reviewQuery.all()

        // Build FeedItems
        var items: [FeedItem] = []
        for v in visits {
            let placeID = try v.place.requireID()
            items.append(FeedItem(
                id: v.id ?? UUID(),
                type: .visit,
                user: v.user.toDTO(),
                place: v.place.toDTO(),
                visit: v.toDTO(userName: v.user.displayName, placeID: placeID, placeName: v.place.name),
                review: nil,
                timestamp: v.visitedAt
            ))
        }
        for r in reviews {
            let placeID = try r.place.requireID()
            items.append(FeedItem(
                id: r.id ?? UUID(),
                type: .review,
                user: r.user.toDTO(),
                place: r.place.toDTO(),
                visit: nil,
                review: r.toDTO(userName: r.user.displayName, placeID: placeID),
                timestamp: r.createdAt ?? Date()
            ))
        }

        items.sort { $0.timestamp > $1.timestamp }
        let hasMore = items.count > pageSize
        let page = Array(items.prefix(pageSize))
        let nextCursor = hasMore ? formatter.string(from: page.last!.timestamp) : nil

        return FeedPage(items: page, cursor: nextCursor, hasMore: hasMore)
    }

    // GET /feed/live
    @Sendable
    func liveStatuses(req: Request) async throws -> [LiveStatusDTO] {
        let me = try req.auth.require(User.self)
        let myID = try me.requireID()

        let friendIDs = try await Self.acceptedFriendIDs(for: myID, on: req.db)
        guard !friendIDs.isEmpty else { return [] }

        let friends = try await User.query(on: req.db)
            .filter(\.$id ~~ friendIDs)
            .with(\.$livePlace)
            .all()

        let now = Date()
        return friends.compactMap { user in
            guard let until = user.liveStatusUntil, until > now,
                  let place = user.livePlace else { return nil }
            return LiveStatusDTO(
                user: user.toDTO(),
                placeName: place.name,
                foodType: user.liveFoodType,
                until: until
            )
        }
    }

    // DELETE /me/live-status
    @Sendable
    func clearLiveStatus(req: Request) async throws -> HTTPStatus {
        let me = try req.auth.require(User.self)
        me.$livePlace.id = nil
        me.liveStatusUntil = nil
        me.liveFoodType = nil
        try await me.save(on: req.db)
        return .noContent
    }
}
