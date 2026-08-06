import Fluent

struct AddGooglePlaceID: AsyncMigration {
    func prepare(on database: Database) async throws {
        // No prod reviews/visits worth keeping — wipe places (cascades to
        // reviews/visits via FK) and swap the OSM Int64 node ID for a
        // Google Place ID (String).
        try await DoenerPlace.query(on: database).delete()

        try await database.schema("doener_places")
            .deleteField("osm_node_id")
            .field("google_place_id", .string, .required)
            .unique(on: "google_place_id")
            .update()
    }

    func revert(on database: Database) async throws {
        try await DoenerPlace.query(on: database).delete()

        try await database.schema("doener_places")
            .deleteField("google_place_id")
            .field("osm_node_id", .int64, .required)
            .unique(on: "osm_node_id")
            .update()
    }
}
