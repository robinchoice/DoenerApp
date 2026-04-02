import Foundation

public enum AchievementType: String, Codable, Sendable, CaseIterable {
    case firstBite = "first_bite"
    case critic = "critic"
    case regular = "regular"
    case explorer = "explorer"
    case connoisseur = "connoisseur"
    case berlinTour = "berlin_tour"
    case hamburgTour = "hamburg_tour"
    case stampCollectorSilver = "stamp_collector_silver"
    case stampCollectorGold = "stamp_collector_gold"
    case nightOwl = "night_owl"
    case socialButterfly = "social_butterfly"

    public var title: String {
        switch self {
        case .firstBite: "First Bite"
        case .critic: "Critic"
        case .regular: "Regular"
        case .explorer: "Explorer"
        case .connoisseur: "Connoisseur"
        case .berlinTour: "Berlin Döner Tour"
        case .hamburgTour: "Hamburg Döner Tour"
        case .stampCollectorSilver: "Silver Collector"
        case .stampCollectorGold: "Gold Collector"
        case .nightOwl: "Night Owl"
        case .socialButterfly: "Social Butterfly"
        }
    }

    public var description: String {
        switch self {
        case .firstBite: "Check in at your first Döner place"
        case .critic: "Write your first review"
        case .regular: "Visit the same place 5 times"
        case .explorer: "Visit 10 different places"
        case .connoisseur: "Visit 50 different places"
        case .berlinTour: "Visit 5 Döner places in Berlin"
        case .hamburgTour: "Visit 5 Döner places in Hamburg"
        case .stampCollectorSilver: "Reach Silver tier on your stamp card"
        case .stampCollectorGold: "Reach Gold tier on your stamp card"
        case .nightOwl: "Check in after 10 PM"
        case .socialButterfly: "Add 5 friends"
        }
    }

    public var iconName: String {
        switch self {
        case .firstBite: "fork.knife"
        case .critic: "star.bubble"
        case .regular: "repeat"
        case .explorer: "map"
        case .connoisseur: "crown"
        case .berlinTour: "building.2"
        case .hamburgTour: "building.2"
        case .stampCollectorSilver: "seal"
        case .stampCollectorGold: "seal.fill"
        case .nightOwl: "moon.stars"
        case .socialButterfly: "person.3"
        }
    }
}

public struct AchievementDTO: Codable, Sendable, Identifiable {
    public let id: UUID
    public let type: AchievementType
    public let unlockedAt: Date

    public init(id: UUID, type: AchievementType, unlockedAt: Date) {
        self.id = id
        self.type = type
        self.unlockedAt = unlockedAt
    }
}
