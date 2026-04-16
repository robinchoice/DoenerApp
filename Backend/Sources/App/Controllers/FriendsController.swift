import Vapor
import Fluent
import DoenerShared

struct FriendsController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware())
        protected.get("users", "search", use: search)
        protected.get("friends", use: list)
        protected.post("friends", "requests", use: request)
        protected.post("friends", "requests", ":friendshipID", "accept", use: accept)
        protected.delete("friends", ":friendshipID", use: remove)
    }

    // GET /users/search?displayName=...
    @Sendable
    func search(req: Request) async throws -> [UserDTO] {
        guard let name = req.query[String.self, at: "displayName"], !name.isEmpty else {
            throw Abort(.badRequest, reason: "displayName query required")
        }
        let me = try req.auth.require(User.self)
        let myID = try me.requireID()
        let results = try await User.query(on: req.db)
            .filter(\.$displayName == name)
            .all()
        return results.compactMap { user in
            (try? user.requireID()) == myID ? nil : user.toDTO()
        }
    }

    // GET /friends
    @Sendable
    func list(req: Request) async throws -> [FriendshipDTO] {
        let me = try req.auth.require(User.self)
        let myID = try me.requireID()

        let asRequester = try await Friendship.query(on: req.db)
            .filter(\.$requester.$id == myID)
            .with(\.$requester)
            .with(\.$addressee)
            .all()
        let asAddressee = try await Friendship.query(on: req.db)
            .filter(\.$addressee.$id == myID)
            .with(\.$requester)
            .with(\.$addressee)
            .all()
        let rows = asRequester + asAddressee

        return try rows.map { f in
            let isRequester = try f.requester.requireID() == myID
            let other = isRequester ? f.addressee : f.requester
            return FriendshipDTO(
                id: try f.requireID(),
                user: other.toDTO(),
                status: FriendshipStatus(rawValue: f.status.rawValue) ?? .pending,
                direction: isRequester ? .outgoing : .incoming,
                createdAt: f.createdAt ?? Date()
            )
        }
    }

    // POST /friends/requests   { addresseeID: UUID }
    @Sendable
    func request(req: Request) async throws -> FriendshipDTO {
        struct Body: Content { let addresseeID: UUID }
        let body = try req.content.decode(Body.self)
        let me = try req.auth.require(User.self)
        let myID = try me.requireID()

        guard body.addresseeID != myID else {
            throw Abort(.badRequest, reason: "Cannot friend yourself")
        }
        guard let addressee = try await User.find(body.addresseeID, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }

        // Already exists in either direction?
        let existingForward = try await Friendship.query(on: req.db)
            .filter(\.$requester.$id == myID)
            .filter(\.$addressee.$id == body.addresseeID)
            .with(\.$requester)
            .with(\.$addressee)
            .first()
        let existingReverse = try await Friendship.query(on: req.db)
            .filter(\.$requester.$id == body.addresseeID)
            .filter(\.$addressee.$id == myID)
            .with(\.$requester)
            .with(\.$addressee)
            .first()
        if let existing = existingForward ?? existingReverse {
            let isRequester = try existing.requester.requireID() == myID
            let other = isRequester ? existing.addressee : existing.requester
            return FriendshipDTO(
                id: try existing.requireID(),
                user: other.toDTO(),
                status: FriendshipStatus(rawValue: existing.status.rawValue) ?? .pending,
                direction: isRequester ? .outgoing : .incoming,
                createdAt: existing.createdAt ?? Date()
            )
        }

        let f = Friendship(requesterID: myID, addresseeID: body.addresseeID, status: .pending)
        try await f.save(on: req.db)

        return FriendshipDTO(
            id: try f.requireID(),
            user: addressee.toDTO(),
            status: .pending,
            direction: .outgoing,
            createdAt: f.createdAt ?? Date()
        )
    }

    // POST /friends/requests/:friendshipID/accept
    @Sendable
    func accept(req: Request) async throws -> FriendshipDTO {
        guard let id = req.parameters.get("friendshipID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let me = try req.auth.require(User.self)
        let myID = try me.requireID()

        guard let f = try await Friendship.query(on: req.db)
            .filter(\.$id == id)
            .with(\.$requester).with(\.$addressee)
            .first() else {
            throw Abort(.notFound)
        }
        // Only the addressee can accept
        guard try f.addressee.requireID() == myID else {
            throw Abort(.forbidden, reason: "Only addressee can accept")
        }
        f.status = .accepted
        try await f.save(on: req.db)

        return FriendshipDTO(
            id: try f.requireID(),
            user: f.requester.toDTO(),
            status: .accepted,
            direction: .incoming,
            createdAt: f.createdAt ?? Date()
        )
    }

    // DELETE /friends/:friendshipID
    @Sendable
    func remove(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("friendshipID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        let me = try req.auth.require(User.self)
        let myID = try me.requireID()

        guard let f = try await Friendship.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        guard f.$requester.id == myID || f.$addressee.id == myID else {
            throw Abort(.forbidden)
        }
        try await f.delete(on: req.db)
        return .noContent
    }
}
