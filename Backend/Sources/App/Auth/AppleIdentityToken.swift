import Foundation
import Vapor

/// Trust-mode Apple identity token decoder for LAN-only dev builds.
/// We decode the JWT payload without verifying the signature — fine for sideload testing,
/// must be replaced with proper Apple JWKS verification before any public deployment.
struct AppleIdentityToken {
    let sub: String      // Apple's stable user ID
    let email: String?

    static func decodeUnverified(_ token: String) throws -> AppleIdentityToken {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else {
            throw Abort(.unauthorized, reason: "Malformed identity token")
        }
        var payload = String(parts[1])
        // Base64URL → Base64 padding
        payload = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload += "=" }
        guard let data = Data(base64Encoded: payload),
              let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String else {
            throw Abort(.unauthorized, reason: "Invalid identity token payload")
        }
        return AppleIdentityToken(sub: sub, email: json["email"] as? String)
    }
}
