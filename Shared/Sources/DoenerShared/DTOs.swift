import Foundation

// MARK: - Auth

public struct AppleSignInRequest: Codable, Sendable {
    public let identityToken: String
    public let displayName: String?

    public init(identityToken: String, displayName: String?) {
        self.identityToken = identityToken
        self.displayName = displayName
    }
}

public struct AuthResponse: Codable, Sendable {
    public let accessToken: String
    public let refreshToken: String
    public let user: UserDTO

    public init(accessToken: String, refreshToken: String, user: UserDTO) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.user = user
    }
}

public struct RefreshTokenRequest: Codable, Sendable {
    public let refreshToken: String

    public init(refreshToken: String) {
        self.refreshToken = refreshToken
    }
}

// MARK: - User

public struct UserDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let displayName: String
    public let avatarURL: String?
    public let language: String

    public init(id: UUID, displayName: String, avatarURL: String?, language: String) {
        self.id = id
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.language = language
    }
}

// MARK: - Place

public struct PlaceDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let osmNodeID: Int64
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let address: String?
    public let postalCode: String?
    public let city: String?
    public let openingHours: String?
    public let avgRating: Double?
    public let reviewCount: Int

    public init(id: UUID, osmNodeID: Int64, name: String, latitude: Double, longitude: Double,
                address: String?, postalCode: String?, city: String?, openingHours: String?,
                avgRating: Double?, reviewCount: Int) {
        self.id = id
        self.osmNodeID = osmNodeID
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.postalCode = postalCode
        self.city = city
        self.openingHours = openingHours
        self.avgRating = avgRating
        self.reviewCount = reviewCount
    }
}

// MARK: - Review

public struct ReviewDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let userID: UUID
    public let userName: String
    public let placeID: UUID
    public let rating: Int
    public let text: String?
    public let imageURLs: [String]
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: UUID, userID: UUID, userName: String, placeID: UUID, rating: Int,
                text: String?, imageURLs: [String], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userID = userID
        self.userName = userName
        self.placeID = placeID
        self.rating = rating
        self.text = text
        self.imageURLs = imageURLs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct CreateReviewRequest: Codable, Sendable {
    public let rating: Int
    public let text: String?

    public init(rating: Int, text: String?) {
        self.rating = rating
        self.text = text
    }
}

// MARK: - Note

public struct NoteDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let placeID: UUID
    public let content: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(id: UUID, placeID: UUID, content: String, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.placeID = placeID
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Visit

public struct VisitDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let userID: UUID
    public let userName: String
    public let placeID: UUID
    public let placeName: String
    public let visitedAt: Date
    public let comment: String?

    public init(id: UUID, userID: UUID, userName: String, placeID: UUID, placeName: String,
                visitedAt: Date, comment: String?) {
        self.id = id
        self.userID = userID
        self.userName = userName
        self.placeID = placeID
        self.placeName = placeName
        self.visitedAt = visitedAt
        self.comment = comment
    }
}

// MARK: - Feed

public struct FeedItem: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: FeedItemType
    public let user: UserDTO
    public let place: PlaceDTO
    public let visit: VisitDTO?
    public let review: ReviewDTO?
    public let timestamp: Date

    public init(id: UUID, type: FeedItemType, user: UserDTO, place: PlaceDTO,
                visit: VisitDTO?, review: ReviewDTO?, timestamp: Date) {
        self.id = id
        self.type = type
        self.user = user
        self.place = place
        self.visit = visit
        self.review = review
        self.timestamp = timestamp
    }
}

public enum FeedItemType: String, Codable, Sendable {
    case visit
    case review
    case achievement
}

// MARK: - Friendship

public struct FriendshipDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let user: UserDTO
    public let status: FriendshipStatus
    public let createdAt: Date

    public init(id: UUID, user: UserDTO, status: FriendshipStatus, createdAt: Date) {
        self.id = id
        self.user = user
        self.status = status
        self.createdAt = createdAt
    }
}

public enum FriendshipStatus: String, Codable, Sendable {
    case pending
    case accepted
    case blocked
}

// MARK: - Stamps

public struct StampCardDTO: Codable, Sendable {
    public let totalStamps: Int
    public let currentTierStamps: Int
    public let currentTier: StampTier
    public let stamps: [StampDTO]

    public init(totalStamps: Int, currentTierStamps: Int, currentTier: StampTier, stamps: [StampDTO]) {
        self.totalStamps = totalStamps
        self.currentTierStamps = currentTierStamps
        self.currentTier = currentTier
        self.stamps = stamps
    }
}

public struct StampDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let placeName: String
    public let earnedAt: Date
    public let source: StampSource

    public init(id: UUID, placeName: String, earnedAt: Date, source: StampSource) {
        self.id = id
        self.placeName = placeName
        self.earnedAt = earnedAt
        self.source = source
    }
}

// MARK: - Pagination

public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let items: [T]
    public let cursor: String?
    public let hasMore: Bool

    public init(items: [T], cursor: String?, hasMore: Bool) {
        self.items = items
        self.cursor = cursor
        self.hasMore = hasMore
    }
}
