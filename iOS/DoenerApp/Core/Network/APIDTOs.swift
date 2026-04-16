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

struct DevSignInRequest: Codable, Sendable {
    let displayName: String
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

enum FriendshipDirection: String, Codable, Sendable {
    case incoming
    case outgoing
}

struct FriendshipDTO: Codable, Sendable, Identifiable, Equatable {
    let id: UUID
    let user: UserDTO
    let status: FriendshipStatus
    let direction: FriendshipDirection
    let createdAt: Date
}

struct UpdateMeRequest: Codable, Sendable {
    let displayName: String
}

struct CreateFriendRequestBody: Codable, Sendable {
    let addresseeID: UUID
}

// MARK: - Feed

struct FeedItem: Codable, Sendable, Identifiable {
    let id: UUID
    let type: FeedItemType
    let user: UserDTO
    let place: PlaceInfo
    let visit: VisitInfo?
    let review: ReviewInfo?
    let timestamp: Date

    struct PlaceInfo: Codable, Sendable {
        let id: UUID
        let name: String
        let osmNodeID: Int64
        let latitude: Double
        let longitude: Double
        let avgRating: Double?
    }

    struct VisitInfo: Codable, Sendable {
        let id: UUID
        let visitedAt: Date
        let comment: String?
    }

    struct ReviewInfo: Codable, Sendable {
        let id: UUID
        let rating: Int
        let text: String?
    }
}

enum FeedItemType: String, Codable, Sendable {
    case visit
    case review
    case achievement
}

struct FeedPage: Codable, Sendable {
    let items: [FeedItem]
    let cursor: String?
    let hasMore: Bool
}

struct LiveStatusDTO: Codable, Sendable {
    let user: UserDTO
    let placeName: String
    let foodType: String?
    let until: Date
}
