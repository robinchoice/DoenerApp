import Vapor
import Fluent
import DoenerShared

struct AuthController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let auth = routes.grouped("auth")
        auth.post("apple", use: signInWithApple)

        let protected = routes.grouped(AuthMiddleware())
        protected.get("auth", "me", use: me)
        protected.patch("users", "me", use: updateMe)
    }

    // POST /auth/apple
    @Sendable
    func signInWithApple(req: Request) async throws -> AuthResponse {
        let body = try req.content.decode(AppleSignInRequest.self)
        let apple = try AppleIdentityToken.decodeUnverified(body.identityToken)

        let user: User
        if let existing = try await User.query(on: req.db)
            .filter(\.$appleUserID == apple.sub)
            .first() {
            user = existing
        } else {
            // Need a unique displayName. Use provided name, fallback to a random one.
            let baseName = body.displayName?.trimmingCharacters(in: .whitespaces) ?? "Döner-Fan"
            let displayName = try await uniqueDisplayName(base: baseName, on: req.db)
            user = User(appleUserID: apple.sub, displayName: displayName)
            try await user.save(on: req.db)
        }

        let signed = SessionToken.issue(for: try user.requireID(), secret: req.application.sessionSecret)

        return AuthResponse(
            accessToken: signed,
            refreshToken: signed, // single-token model for dev
            user: user.toDTO()
        )
    }

    // GET /auth/me
    @Sendable
    func me(req: Request) async throws -> UserDTO {
        let user = try req.auth.require(User.self)
        return user.toDTO()
    }

    // PATCH /users/me
    @Sendable
    func updateMe(req: Request) async throws -> UserDTO {
        struct Body: Content { let displayName: String }
        let body = try req.content.decode(Body.self)
        let user = try req.auth.require(User.self)

        let trimmed = body.displayName.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, trimmed.count <= 30 else {
            throw Abort(.badRequest, reason: "displayName must be 2–30 chars")
        }

        // Uniqueness check (excluding self)
        if let existing = try await User.query(on: req.db)
            .filter(\.$displayName == trimmed)
            .first(),
           try existing.requireID() != (try user.requireID()) {
            throw Abort(.conflict, reason: "displayName already taken")
        }

        user.displayName = trimmed
        try await user.save(on: req.db)
        return user.toDTO()
    }

    private func uniqueDisplayName(base: String, on db: any Database) async throws -> String {
        var candidate = base
        var suffix = 0
        while try await User.query(on: db).filter(\.$displayName == candidate).first() != nil {
            suffix += 1
            candidate = "\(base)-\(suffix)"
        }
        return candidate
    }
}
