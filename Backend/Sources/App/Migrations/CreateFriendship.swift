import Fluent
import SQLKit

struct CreateFriendship: AsyncMigration {
    func prepare(on database: Database) async throws {
        let status = try await database.enum("friendship_status")
            .case("pending")
            .case("accepted")
            .create()

        try await database.schema("friendships")
            .id()
            .field("requester_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("addressee_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("status", status, .required)
            .field("created_at", .datetime)
            .unique(on: "requester_id", "addressee_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("friendships").delete()
        try await database.enum("friendship_status").delete()
    }
}
