import Vapor
import Fluent
import FluentPostgresDriver
import PostgresNIO

func configure(_ app: Application) async throws {
    let host = Environment.get("DB_HOST") ?? "localhost"
    let port = Environment.get("DB_PORT").flatMap(Int.init) ?? 5432
    let username = Environment.get("DB_USER") ?? "doener"
    let password = Environment.get("DB_PASSWORD") ?? "doener"
    let database = Environment.get("DB_NAME") ?? "doenerapp"

    let useTLS = Environment.get("DB_TLS") == "require"
    let tls: PostgresConnection.Configuration.TLS = useTLS
        ? (try .require(.init(configuration: .clientDefault)))
        : .disable

    let pgConfig = SQLPostgresConfiguration(
        hostname: host,
        port: port,
        username: username,
        password: password,
        database: database,
        tls: tls
    )
    app.databases.use(.postgres(configuration: pgConfig), as: .psql)

    app.sessionSecret = Environment.get("JWT_SECRET") ?? "dev-secret-change-me"

    app.migrations.add(CreateDoenerPlace())
    app.migrations.add(CreateUser())
    app.migrations.add(CreateFriendship())
    app.migrations.add(CreateReview())
    app.migrations.add(CreateVisit())
    app.migrations.add(AddDimensionRatings())
    app.migrations.add(AddLiveStatus())

    try await app.autoMigrate()
    try routes(app)
}
