import Foundation

public enum StampTier: String, Codable, Sendable, CaseIterable, Comparable {
    case bronze
    case silver
    case gold
    case platinum

    public var stampsRequired: Int {
        switch self {
        case .bronze: 0
        case .silver: 10
        case .gold: 25
        case .platinum: 50
        }
    }

    public var nextTier: StampTier? {
        switch self {
        case .bronze: .silver
        case .silver: .gold
        case .gold: .platinum
        case .platinum: nil
        }
    }

    public var stampsToNextTier: Int? {
        nextTier?.stampsRequired
    }

    public static func tier(forStamps count: Int) -> StampTier {
        if count >= StampTier.platinum.stampsRequired { return .platinum }
        if count >= StampTier.gold.stampsRequired { return .gold }
        if count >= StampTier.silver.stampsRequired { return .silver }
        return .bronze
    }

    public static func < (lhs: StampTier, rhs: StampTier) -> Bool {
        lhs.stampsRequired < rhs.stampsRequired
    }
}

public enum StampSource: String, Codable, Sendable {
    case visit
    case review
    case note
}
