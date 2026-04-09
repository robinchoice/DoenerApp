import Foundation
import MapKit

struct OverpassClient {
    private static let servers = [
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass-api.de/api/interpreter",
    ]

    struct OverpassElement: Decodable {
        let id: Int64
        let type: String?
        let lat: Double?
        let lon: Double?
        let center: Center?
        let tags: [String: String]?

        struct Center: Decodable {
            let lat: Double
            let lon: Double
        }

        /// Coordinate to use on the map. Nodes have lat/lon directly,
        /// ways/relations carry their centroid in `center` (out center).
        var coordinateLat: Double? { lat ?? center?.lat }
        var coordinateLon: Double? { lon ?? center?.lon }
    }

    private struct OverpassResponse: Decodable {
        let elements: [OverpassElement]
    }

    static func fetchDoenerPlaces(in region: MKCoordinateRegion) async throws -> [OverpassElement] {
        let center = region.center
        let span = region.span

        let south = center.latitude - span.latitudeDelta / 2
        let north = center.latitude + span.latitudeDelta / 2
        let west = center.longitude - span.longitudeDelta / 2
        let east = center.longitude + span.longitudeDelta / 2

        let bbox = "\(south),\(west),\(north),\(east)"

        // nwr = node + way + relation: many shops are tagged as building polygons (ways),
        // not nodes. `out center` gives ways/relations a centroid we can pin on the map.
        // Cuisine + name regex are deliberately wide — many döner shops in OSM are tagged
        // as turkish/arab/lebanese without the explicit kebab tag, or only via name.
        let query = """
        [out:json][timeout:25];
        (
          nwr["cuisine"~"kebab|döner|doner|kebap|turkish|arab|lebanese|syrian|mediterranean|falafel|shawarma",i]["amenity"~"restaurant|fast_food"](\(bbox));
          nwr["name"~"[Dd](ö|oe)ner|[Kk]eba[bp]|[Dd]ürüm|[Ss]hawarma|[Ff]alafel|[Yy]ufka|[Ll]ahmacun|[Ii]mbiss",i]["amenity"~"restaurant|fast_food"](\(bbox));
        );
        out center tags;
        """

        var lastError: Error = OverpassError.requestFailed

        for server in servers {
            do {
                var request = URLRequest(url: URL(string: server)!)
                request.httpMethod = "POST"
                var components = URLComponents()
                components.queryItems = [URLQueryItem(name: "data", value: query)]
                request.httpBody = components.percentEncodedQuery?.data(using: .utf8)
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.timeoutInterval = 20

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    continue
                }

                let decoded = try JSONDecoder().decode(OverpassResponse.self, from: data)

                var seen = Set<String>()
                return decoded.elements.filter { element in
                    guard element.coordinateLat != nil, element.coordinateLon != nil else { return false }
                    // Dedupe across types: a shop can match both queries, and node/way IDs overlap.
                    let key = "\(element.type ?? "n"):\(element.id)"
                    return seen.insert(key).inserted
                }
            } catch {
                lastError = error
                continue
            }
        }

        throw lastError
    }

    enum OverpassError: Error, LocalizedError {
        case requestFailed

        var errorDescription: String? {
            switch self {
            case .requestFailed: "Döner-Läden konnten nicht geladen werden. Bitte versuch es gleich nochmal."
            }
        }
    }
}
