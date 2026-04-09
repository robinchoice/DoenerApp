import Vapor
import Fluent

final class Review: Model, Content, @unchecked Sendable {
    static let schema = "reviews"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "place_id")
    var place: DoenerPlace

    @Field(key: "rating")
    var rating: Int

    @OptionalField(key: "text")
    var text: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, userID: UUID, placeID: UUID, rating: Int, text: String? = nil) {
        self.id = id
        self.$user.id = userID
        self.$place.id = placeID
        self.rating = rating
        self.text = text
    }
}
