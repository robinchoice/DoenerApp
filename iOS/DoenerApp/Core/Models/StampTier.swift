import Foundation

enum StampTier: String, Codable, Sendable, CaseIterable, Comparable {
    case bronze
    case silver
    case gold
    case platinum

    var stampsRequired: Int {
        switch self {
        case .bronze: 0
        case .silver: 10
        case .gold: 25
        case .platinum: 50
        }
    }

    var nextTier: StampTier? {
        switch self {
        case .bronze: .silver
        case .silver: .gold
        case .gold: .platinum
        case .platinum: nil
        }
    }

    var stampsToNextTier: Int? {
        nextTier?.stampsRequired
    }

    static func tier(forStamps count: Int) -> StampTier {
        if count >= StampTier.platinum.stampsRequired { return .platinum }
        if count >= StampTier.gold.stampsRequired { return .gold }
        if count >= StampTier.silver.stampsRequired { return .silver }
        return .bronze
    }

    static func < (lhs: StampTier, rhs: StampTier) -> Bool {
        lhs.stampsRequired < rhs.stampsRequired
    }
}
