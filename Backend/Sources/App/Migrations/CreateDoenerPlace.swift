import Fluent

struct CreateDoenerPlace: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("doener_places")
            .id()
            .field("osm_node_id", .int64, .required)
            .field("name", .string, .required)
            .field("latitude", .double, .required)
            .field("longitude", .double, .required)
            .field("address", .string)
            .field("postal_code", .string)
            .field("city", .string)
            .field("opening_hours", .string)
            .field("avg_rating", .double)
            .field("review_count", .int, .required, .sql(.default(0)))
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "osm_node_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("doener_places").delete()
    }
}
