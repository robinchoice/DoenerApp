import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
            .field("apple_user_id", .string, .required)
            .field("display_name", .string, .required)
            .field("avatar_url", .string)
            .field("language", .string, .required, .sql(.default("de")))
            .field("created_at", .datetime)
            .unique(on: "apple_user_id")
            .unique(on: "display_name")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
