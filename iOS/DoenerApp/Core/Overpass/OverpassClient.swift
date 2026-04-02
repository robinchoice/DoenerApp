import Foundation
import MapKit

struct OverpassClient {
    private static let servers = [
        "https://overpass.kumi.systems/api/interpreter",
        "https://overpass-api.de/api/interpreter",
    ]

    struct OverpassElement: Decodable {
        let id: Int64
        let lat: Double?
        let lon: Double?
        let tags: [String: String]?
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

        let query = """
        [out:json][timeout:10];
        (
          node["cuisine"~"kebab|döner|doner|kebap"]["amenity"~"restaurant|fast_food"](\(bbox));
          node["name"~"[Dd](ö|oe)ner|[Kk]ebab|[Kk]ebap"]["amenity"~"restaurant|fast_food"](\(bbox));
        );
        out body;
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

                var seen = Set<Int64>()
                return decoded.elements.filter { element in
                    guard element.lat != nil, element.lon != nil else { return false }
                    return seen.insert(element.id).inserted
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
