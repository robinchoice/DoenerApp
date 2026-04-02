import Vapor
import Fluent
import FluentPostgresDriver

func configure(_ app: Application) async throws {
    app.databases.use(
        .postgres(configuration: .init(
            hostname: Environment.get("DB_HOST") ?? "localhost",
            port: Environment.get("DB_PORT").flatMap(Int.init) ?? 5432,
            username: Environment.get("DB_USER") ?? "doener",
            password: Environment.get("DB_PASSWORD") ?? "doener",
            database: Environment.get("DB_NAME") ?? "doenerapp",
            tls: .disable
        )),
        as: .psql
    )

    // Migrations
    app.migrations.add(CreateDoenerPlace())

    // Routes
    try routes(app)
}
