import Vapor
import Fluent

final class Visit: Model, Content, @unchecked Sendable {
    static let schema = "visits"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "place_id")
    var place: DoenerPlace

    @Field(key: "visited_at")
    var visitedAt: Date

    @OptionalField(key: "comment")
    var comment: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, placeID: UUID, visitedAt: Date = Date(), comment: String? = nil) {
        self.id = id
        self.$user.id = userID
        self.$place.id = placeID
        self.visitedAt = visitedAt
        self.comment = comment
    }
}
