import Vapor
import Fluent
import DoenerShared

struct FeedbackController: RouteCollection {
    func boot(routes: any RoutesBuilder) throws {
        let protected = routes.grouped(AuthMiddleware())

        // POST /api/v1/feedback — tester bug reports / feedback, optional screenshot as base64
        protected.on(.POST, "feedback", body: .collect(maxSize: "5mb"), use: createFeedback)
    }

    struct CreateBody: Content {
        let message: String
        let screenshotBase64: String?
        let appVersion: String?
        let buildNumber: String?
    }

    @Sendable
    func createFeedback(req: Request) async throws -> FeedbackDTO {
        let user = try req.auth.require(User.self)
        let body = try req.content.decode(CreateBody.self)
        let trimmedMessage = body.message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw Abort(.badRequest, reason: "message must not be empty")
        }
        let userID = try user.requireID()

        let feedback = Feedback(
            userID: userID,
            message: trimmedMessage,
            screenshotBase64: body.screenshotBase64,
            appVersion: body.appVersion,
            buildNumber: body.buildNumber
        )
        try await feedback.save(on: req.db)

        return feedback.toDTO()
    }
}

extension Feedback {
    func toDTO() -> FeedbackDTO {
        FeedbackDTO(id: id ?? UUID(), message: message, createdAt: createdAt ?? Date())
    }
}
