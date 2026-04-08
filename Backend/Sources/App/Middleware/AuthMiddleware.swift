import Vapor
import Fluent

struct AuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let bearer = request.headers.bearerAuthorization else {
            throw Abort(.unauthorized, reason: "Missing Bearer token")
        }
        let session = try SessionToken.verify(bearer.token, secret: request.application.sessionSecret)
        guard let user = try await User.find(session.userID, on: request.db) else {
            throw Abort(.unauthorized, reason: "User not found")
        }
        request.auth.login(user)
        return try await next.respond(to: request)
    }
}

extension User: Authenticatable {}
