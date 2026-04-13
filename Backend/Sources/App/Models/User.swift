import Vapor
import Fluent
import DoenerShared

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "apple_user_id")
    var appleUserID: String

    @Field(key: "display_name")
    var displayName: String

    @OptionalField(key: "avatar_url")
    var avatarURL: String?

    @Field(key: "language")
    var language: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @OptionalParent(key: "live_place_id")
    var livePlace: DoenerPlace?

    @OptionalField(key: "live_status_until")
    var liveStatusUntil: Date?

    @OptionalField(key: "live_food_type")
    var liveFoodType: String?

    init() {}

    init(id: UUID? = nil, appleUserID: String, displayName: String, avatarURL: String? = nil, language: String = "de") {
        self.id = id
        self.appleUserID = appleUserID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.language = language
    }

    func toDTO() -> UserDTO {
        UserDTO(
            id: self.id!,
            displayName: self.displayName,
            avatarURL: self.avatarURL,
            language: self.language
        )
    }
}
