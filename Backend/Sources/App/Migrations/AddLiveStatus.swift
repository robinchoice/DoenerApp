import Fluent

struct AddLiveStatus: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("users")
            .field("live_place_id", .uuid, .references("doener_places", "id", onDelete: .setNull))
            .field("live_status_until", .datetime)
            .field("live_food_type", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("users")
            .deleteField("live_place_id")
            .deleteField("live_status_until")
            .deleteField("live_food_type")
            .update()
    }
}
