import Vapor
import Fluent
import DoenerShared

final class DoenerPlace: Model, Content, @unchecked Sendable {
    static let schema = "doener_places"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "google_place_id")
    var placeID: String

    @Field(key: "name")
    var name: String

    @Field(key: "latitude")
    var latitude: Double

    @Field(key: "longitude")
    var longitude: Double

    @OptionalField(key: "address")
    var address: String?

    @OptionalField(key: "postal_code")
    var postalCode: String?

    @OptionalField(key: "city")
    var city: String?

    @OptionalField(key: "opening_hours")
    var openingHours: String?

    @OptionalField(key: "avg_rating")
    var avgRating: Double?

    @Field(key: "review_count")
    var reviewCount: Int

    @OptionalField(key: "special_note")
    var specialNote: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(id: UUID? = nil, placeID: String, name: String, latitude: Double, longitude: Double,
         address: String? = nil, postalCode: String? = nil, city: String? = nil,
         openingHours: String? = nil) {
        self.id = id
        self.placeID = placeID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.postalCode = postalCode
        self.city = city
        self.openingHours = openingHours
        self.avgRating = nil
        self.reviewCount = 0
    }
}
