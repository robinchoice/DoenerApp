import Fluent

struct AddDimensionRatings: AsyncMigration {
    func prepare(on database: any Database) async throws {
        try await database.schema("reviews")
            .field("sauce_rating", .int)
            .field("fleisch_rating", .int)
            .field("brot_rating", .int)
            .update()
        try await database.schema("doener_places")
            .field("special_note", .string)
            .update()
    }

    func revert(on database: any Database) async throws {
        try await database.schema("reviews")
            .deleteField("sauce_rating")
            .deleteField("fleisch_rating")
            .deleteField("brot_rating")
            .update()
        try await database.schema("doener_places")
            .deleteField("special_note")
            .update()
    }
}
