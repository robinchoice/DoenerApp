import Vapor

func routes(_ app: Application) throws {
    let api = app.grouped("api", "v1")

    api.get("health") { _ in
        ["status": "ok"]
    }

    try api.register(collection: PlaceController())
}
