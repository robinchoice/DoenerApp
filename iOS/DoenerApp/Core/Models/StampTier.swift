import Foundation
import SwiftUI

enum StampTier: String, Codable, Sendable, CaseIterable, Comparable {
    case doenerneuling
    case doenerfreund
    case doenerfan
    case doenerprofi
    case doenermeister
    case doenerlegende

    var stampsRequired: Int {
        switch self {
        case .doenerneuling: 0
        case .doenerfreund: 5
        case .doenerfan: 15
        case .doenerprofi: 30
        case .doenermeister: 60
        case .doenerlegende: 100
        }
    }

    var nextTier: StampTier? {
        switch self {
        case .doenerneuling: .doenerfreund
        case .doenerfreund: .doenerfan
        case .doenerfan: .doenerprofi
        case .doenerprofi: .doenermeister
        case .doenermeister: .doenerlegende
        case .doenerlegende: nil
        }
    }

    var stampsToNextTier: Int? {
        nextTier?.stampsRequired
    }

    static func tier(forStamps count: Int) -> StampTier {
        for tier in StampTier.allCases.reversed() {
            if count >= tier.stampsRequired { return tier }
        }
        return .doenerneuling
    }

    static func < (lhs: StampTier, rhs: StampTier) -> Bool {
        lhs.stampsRequired < rhs.stampsRequired
    }

    /// Localized display name shown in the UI.
    var displayName: String {
        switch self {
        case .doenerneuling:  String(localized: "stamp_tier.doenerneuling",  defaultValue: "Dönerneuling")
        case .doenerfreund:   String(localized: "stamp_tier.doenerfreund",   defaultValue: "Dönerfreund")
        case .doenerfan:      String(localized: "stamp_tier.doenerfan",      defaultValue: "Dönerfan")
        case .doenerprofi:    String(localized: "stamp_tier.doenerprofi",    defaultValue: "Dönerprofi")
        case .doenermeister:  String(localized: "stamp_tier.doenermeister",  defaultValue: "Dönermeister")
        case .doenerlegende:  String(localized: "stamp_tier.doenerlegende",  defaultValue: "Dönerlegende")
        }
    }

    /// Color for badges, progress bar, and stamp dots.
    var color: Color {
        switch self {
        case .doenerneuling:  .gray
        case .doenerfreund:   .brown
        case .doenerfan:      .orange
        case .doenerprofi:    .red
        case .doenermeister:  .purple
        case .doenerlegende:  .yellow
        }
    }
}
