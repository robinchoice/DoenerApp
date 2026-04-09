import Fluent

struct CreateReview: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("reviews")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("place_id", .uuid, .required, .references("doener_places", "id", onDelete: .cascade))
            .field("rating", .int, .required)
            .field("text", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "place_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("reviews").delete()
    }
}
