import Foundation
import SwiftData
import MapKit

@Model
final class CachedPlace {
    @Attribute(.unique) var osmNodeID: Int64
    var name: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var postalCode: String?
    var city: String?
    var openingHours: String?
    var avgRating: Double?
    var reviewCount: Int
    var lastSyncedAt: Date

    // Local-only fields
    var userNote: String?
    var specialNote: String?
    var userRating: Int?
    var isFavorite: Bool

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(osmNodeID: Int64, name: String, latitude: Double, longitude: Double,
         address: String? = nil, postalCode: String? = nil, city: String? = nil,
         openingHours: String? = nil) {
        self.osmNodeID = osmNodeID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.postalCode = postalCode
        self.city = city
        self.openingHours = openingHours
        self.avgRating = nil
        self.reviewCount = 0
        self.lastSyncedAt = Date()
        self.isFavorite = false
    }
}

@Model
final class CachedRegion {
    var minLatitude: Double
    var maxLatitude: Double
    var minLongitude: Double
    var maxLongitude: Double
    var lastFetched: Date

    init(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        self.minLatitude = minLat
        self.maxLatitude = maxLat
        self.minLongitude = minLon
        self.maxLongitude = maxLon
        self.lastFetched = Date()
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        latitude >= minLatitude && latitude <= maxLatitude &&
        longitude >= minLongitude && longitude <= maxLongitude
    }

    var isStale: Bool {
        Date().timeIntervalSince(lastFetched) > 24 * 60 * 60
    }
}

@Model
final class Visit {
    var placeOsmNodeID: Int64
    var placeName: String
    var visitedAt: Date
    var comment: String?
    var foodType: String?

    init(placeOsmNodeID: Int64, placeName: String, visitedAt: Date = Date(),
         comment: String? = nil, foodType: String? = nil) {
        self.placeOsmNodeID = placeOsmNodeID
        self.placeName = placeName
        self.visitedAt = visitedAt
        self.comment = comment
        self.foodType = foodType
    }
}

@Model
final class Review {
    var placeOsmNodeID: Int64
    var placeName: String
    var rating: Int // 1-5
    var sauceRating: Int?
    var fleischRating: Int?
    var brotRating: Int?
    var text: String?
    var createdAt: Date
    var updatedAt: Date

    init(placeOsmNodeID: Int64, placeName: String, rating: Int,
         sauceRating: Int? = nil, fleischRating: Int? = nil, brotRating: Int? = nil,
         text: String? = nil) {
        self.placeOsmNodeID = placeOsmNodeID
        self.placeName = placeName
        self.rating = rating
        self.sauceRating = sauceRating
        self.fleischRating = fleischRating
        self.brotRating = brotRating
        self.text = text
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class CachedFriendship {
    @Attribute(.unique) var id: UUID
    var userID: UUID
    var displayName: String
    var avatarURL: String?
    var status: String   // "pending" / "accepted"
    var direction: String // "incoming" (other → me) / "outgoing" (me → other)
    var createdAt: Date

    init(id: UUID, userID: UUID, displayName: String, avatarURL: String? = nil,
         status: String, direction: String, createdAt: Date) {
        self.id = id
        self.userID = userID
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.status = status
        self.direction = direction
        self.createdAt = createdAt
    }
}

@Model
final class MissingShopReport {
    var name: String
    var addressOrHint: String?
    var latitude: Double?
    var longitude: Double?
    var note: String?
    var createdAt: Date

    init(name: String, addressOrHint: String? = nil, latitude: Double? = nil,
         longitude: Double? = nil, note: String? = nil) {
        self.name = name
        self.addressOrHint = addressOrHint
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.createdAt = Date()
    }
}

@Model
final class PendingSyncOperation {
    var entityType: String
    var entityID: String
    var operationType: String // create, update, delete
    var payload: Data
    var createdAt: Date
    var retryCount: Int

    init(entityType: String, entityID: String, operationType: String, payload: Data) {
        self.entityType = entityType
        self.entityID = entityID
        self.operationType = operationType
        self.payload = payload
        self.createdAt = Date()
        self.retryCount = 0
    }
}
