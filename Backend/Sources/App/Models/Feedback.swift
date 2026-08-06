import Vapor
import Fluent

final class Feedback: Model, Content, @unchecked Sendable {
    static let schema = "feedback"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Field(key: "message")
    var message: String

    @OptionalField(key: "screenshot_base64")
    var screenshotBase64: String?

    @OptionalField(key: "app_version")
    var appVersion: String?

    @OptionalField(key: "build_number")
    var buildNumber: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, message: String, screenshotBase64: String? = nil,
         appVersion: String? = nil, buildNumber: String? = nil) {
        self.id = id
        self.$user.id = userID
        self.message = message
        self.screenshotBase64 = screenshotBase64
        self.appVersion = appVersion
        self.buildNumber = buildNumber
    }
}
