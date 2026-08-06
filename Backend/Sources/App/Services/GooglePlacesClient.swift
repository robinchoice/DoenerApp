import Vapor

/// Thin wrapper around the Google Places API (New) — replaces the previous
/// live client-side Overpass/OSM lookup. Called from the backend so the API
/// key stays server-side and request volume can be governed centrally.
enum GooglePlacesClient {
    struct SearchNearbyResponse: Decodable {
        let places: [GooglePlace]?
    }

    struct GooglePlace: Decodable {
        struct DisplayName: Decodable { let text: String }
        struct Location: Decodable { let latitude: Double; let longitude: Double }
        struct OpeningHours: Decodable { let weekdayDescriptions: [String]? }
        struct AddressComponent: Decodable {
            let longText: String?
            let shortText: String?
            let types: [String]
        }

        let id: String
        let displayName: DisplayName
        let location: Location
        let types: [String]?
        let businessStatus: String?
        let formattedAddress: String?
        let addressComponents: [AddressComponent]?
        let regularOpeningHours: OpeningHours?
    }

    enum PlacesError: Error, LocalizedError {
        case requestFailed(UInt)

        var errorDescription: String? {
            switch self {
            case .requestFailed(let status): "Google Places request failed with status \(status)"
            }
        }
    }

    private static let fieldMask = [
        "places.id",
        "places.displayName",
        "places.location",
        "places.types",
        "places.businessStatus",
        "places.formattedAddress",
        "places.addressComponents",
        "places.regularOpeningHours",
    ].joined(separator: ",")

    static func searchNearby(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        apiKey: String,
        client: any Client
    ) async throws -> [GooglePlace] {
        let requestBody: [String: Any] = [
            "includedTypes": ["restaurant", "meal_takeaway"],
            "maxResultCount": 20,
            "locationRestriction": [
                "circle": [
                    "center": ["latitude": latitude, "longitude": longitude],
                    "radius": min(max(radiusMeters, 1), 50_000),
                ],
            ],
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: requestBody)

        let response = try await client.post("https://places.googleapis.com/v1/places:searchNearby") { req in
            req.headers.replaceOrAdd(name: "Content-Type", value: "application/json")
            req.headers.replaceOrAdd(name: "X-Goog-Api-Key", value: apiKey)
            req.headers.replaceOrAdd(name: "X-Goog-FieldMask", value: fieldMask)
            req.body = ByteBuffer(data: bodyData)
        }

        guard response.status == .ok, let buffer = response.body else {
            throw PlacesError.requestFailed(response.status.code)
        }

        let data = Data(buffer: buffer)
        let decoded = try JSONDecoder().decode(SearchNearbyResponse.self, from: data)
        return decoded.places ?? []
    }

    /// Same name-keyword heuristic previously used against OSM tags/names —
    /// Google Places has no "cuisine=kebab" equivalent, so filtering stays
    /// name-based.
    static func looksLikeDoener(_ place: GooglePlace) -> Bool {
        let name = place.displayName.text
        let pattern = "(?i)(d[öo]ner|keba[bp]|dürüm|shawarma|falafel|yufka|lahmacun|imbiss)"
        return name.range(of: pattern, options: .regularExpression) != nil
    }
}
