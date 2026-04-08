import Foundation

struct UserDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let avatarURL: String?
    let language: String
}

struct AppleSignInRequest: Codable, Sendable {
    let identityToken: String
    let displayName: String?
}

struct AuthResponse: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let user: UserDTO
}

enum FriendshipStatus: String, Codable, Sendable {
    case pending
    case accepted
    case blocked
}

struct FriendshipDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let user: UserDTO
    let status: FriendshipStatus
    let createdAt: Date
}

struct UpdateMeRequest: Codable, Sendable {
    let displayName: String
}

struct CreateFriendRequestBody: Codable, Sendable {
    let addresseeID: UUID
}
