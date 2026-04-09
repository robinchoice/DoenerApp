import Foundation

public enum StampTier: String, Codable, Sendable, CaseIterable, Comparable {
    case doenerneuling
    case doenerfreund
    case doenerfan
    case doenerprofi
    case doenermeister
    case doenerlegende

    public var stampsRequired: Int {
        switch self {
        case .doenerneuling: 0
        case .doenerfreund: 5
        case .doenerfan: 15
        case .doenerprofi: 30
        case .doenermeister: 60
        case .doenerlegende: 100
        }
    }

    public var nextTier: StampTier? {
        switch self {
        case .doenerneuling: .doenerfreund
        case .doenerfreund: .doenerfan
        case .doenerfan: .doenerprofi
        case .doenerprofi: .doenermeister
        case .doenermeister: .doenerlegende
        case .doenerlegende: nil
        }
    }

    public var stampsToNextTier: Int? {
        nextTier?.stampsRequired
    }

    public static func tier(forStamps count: Int) -> StampTier {
        // Walk tiers from highest to lowest and return the first one we qualify for.
        for tier in StampTier.allCases.reversed() {
            if count >= tier.stampsRequired { return tier }
        }
        return .doenerneuling
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
