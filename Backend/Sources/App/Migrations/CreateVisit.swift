import Fluent

struct CreateVisit: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("visits")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("place_id", .uuid, .required, .references("doener_places", "id", onDelete: .cascade))
            .field("visited_at", .datetime, .required)
            .field("comment", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("visits").delete()
    }
}
