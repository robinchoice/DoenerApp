import Fluent

struct CreateFeedback: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("feedback")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("message", .string, .required)
            .field("screenshot_base64", .string)
            .field("app_version", .string)
            .field("build_number", .string)
            .field("created_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("feedback").delete()
    }
}
