import Foundation
import Vapor
import Crypto

/// Tiny self-rolled signed token: "<base64url(payload)>.<base64url(hmac-sha256)>".
/// Payload: "<userID>:<expiry-unix-seconds>"
struct SessionToken {
    let userID: UUID
    let expiresAt: Date

    static func issue(for userID: UUID, secret: String, ttl: TimeInterval = 60 * 60 * 24 * 365) -> String {
        let exp = Int(Date().addingTimeInterval(ttl).timeIntervalSince1970)
        let payload = "\(userID.uuidString):\(exp)"
        let sig = sign(payload: payload, secret: secret)
        return "\(b64(payload.data(using: .utf8)!)).\(b64(sig))"
    }

    static func verify(_ token: String, secret: String) throws -> SessionToken {
        let parts = token.split(separator: ".")
        guard parts.count == 2,
              let payloadData = unb64(String(parts[0])),
              let sigData = unb64(String(parts[1])),
              let payload = String(data: payloadData, encoding: .utf8) else {
            throw Abort(.unauthorized, reason: "Malformed session token")
        }
        let expected = sign(payload: payload, secret: secret)
        guard sigData == expected else {
            throw Abort(.unauthorized, reason: "Invalid session signature")
        }
        let pieces = payload.split(separator: ":")
        guard pieces.count == 2,
              let userID = UUID(uuidString: String(pieces[0])),
              let exp = TimeInterval(String(pieces[1])) else {
            throw Abort(.unauthorized, reason: "Invalid session payload")
        }
        let expiresAt = Date(timeIntervalSince1970: exp)
        guard expiresAt > Date() else {
            throw Abort(.unauthorized, reason: "Session expired")
        }
        return SessionToken(userID: userID, expiresAt: expiresAt)
    }

    private static func sign(payload: String, secret: String) -> Data {
        let key = SymmetricKey(data: Data(secret.utf8))
        let mac = HMAC<SHA256>.authenticationCode(for: Data(payload.utf8), using: key)
        return Data(mac)
    }

    private static func b64(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func unb64(_ str: String) -> Data? {
        var s = str.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while s.count % 4 != 0 { s += "=" }
        return Data(base64Encoded: s)
    }
}

struct SessionSecretKey: StorageKey {
    typealias Value = String
}

extension Application {
    var sessionSecret: String {
        get { storage[SessionSecretKey.self] ?? "dev-secret-change-me" }
        set { storage[SessionSecretKey.self] = newValue }
    }
}
