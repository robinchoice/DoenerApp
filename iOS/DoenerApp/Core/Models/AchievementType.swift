import Foundation

enum AchievementType: String, Codable, Sendable, CaseIterable {
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

    var title: String {
        switch self {
        case .firstBite: "First Bite"
        case .critic: "Kritiker"
        case .regular: "Stammgast"
        case .explorer: "Entdecker"
        case .connoisseur: "Kenner"
        case .berlinTour: "Berlin Döner Tour"
        case .hamburgTour: "Hamburg Döner Tour"
        case .stampCollectorSilver: "Silber-Sammler"
        case .stampCollectorGold: "Gold-Sammler"
        case .nightOwl: "Nachtschwärmer"
        case .socialButterfly: "Schmetterling"
        }
    }

    var description: String {
        switch self {
        case .firstBite: "Check bei deinem ersten Döner-Laden ein"
        case .critic: "Schreibe deine erste Bewertung"
        case .regular: "Besuche denselben Laden 5 Mal"
        case .explorer: "Besuche 10 verschiedene Läden"
        case .connoisseur: "Besuche 50 verschiedene Läden"
        case .berlinTour: "Besuche 5 Döner-Läden in Berlin"
        case .hamburgTour: "Besuche 5 Döner-Läden in Hamburg"
        case .stampCollectorSilver: "Erreiche die Silber-Stufe"
        case .stampCollectorGold: "Erreiche die Gold-Stufe"
        case .nightOwl: "Checke nach 22 Uhr ein"
        case .socialButterfly: "Füge 5 Freunde hinzu"
        }
    }

    var iconName: String {
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
