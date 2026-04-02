import SwiftUI
import SwiftData

struct RankingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var rankedPlaces: [RankedPlace] = []
    @State private var sortMode: SortMode = .rating

    enum SortMode: String, CaseIterable {
        case rating = "Bewertung"
        case visits = "Besuche"
        case recent = "Zuletzt besucht"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                if rankedPlaces.isEmpty {
                    ContentUnavailableView(
                        "Noch kein Ranking",
                        systemImage: "trophy",
                        description: Text("Besuche und bewerte Döner-Läden, um dein persönliches Ranking zu erstellen.")
                    )
                } else {
                    VStack(spacing: 0) {
                        // Sort picker
                        Picker("Sortierung", selection: $sortMode) {
                            ForEach(SortMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        // Ranking list
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(Array(rankedPlaces.enumerated()), id: \.element.place.persistentModelID) { index, ranked in
                                    RankingRow(rank: index + 1, ranked: ranked)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationTitle("Ranking")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear { loadRanking() }
            .onChange(of: sortMode) { loadRanking() }
        }
    }

    private func loadRanking() {
        let visitDescriptor = FetchDescriptor<Visit>()
        let reviewDescriptor = FetchDescriptor<Review>()
        let placeDescriptor = FetchDescriptor<CachedPlace>()

        guard let visits = try? modelContext.fetch(visitDescriptor),
              let reviews = try? modelContext.fetch(reviewDescriptor),
              let places = try? modelContext.fetch(placeDescriptor) else { return }

        let visitsByPlace = Dictionary(grouping: visits, by: \.placeOsmNodeID)
        let reviewsByPlace = Dictionary(grouping: reviews, by: \.placeOsmNodeID)

        // Only show places the user has interacted with
        let interactedOsmIDs = Set(visitsByPlace.keys).union(reviewsByPlace.keys)

        var ranked: [RankedPlace] = places.compactMap { place in
            guard interactedOsmIDs.contains(place.osmNodeID) else { return nil }
            let placeVisits = visitsByPlace[place.osmNodeID] ?? []
            let placeReviews = reviewsByPlace[place.osmNodeID] ?? []
            let avgRating = placeReviews.isEmpty ? nil : Double(placeReviews.reduce(0) { $0 + $1.rating }) / Double(placeReviews.count)
            let lastVisit = placeVisits.map(\.visitedAt).max()

            return RankedPlace(
                place: place,
                visitCount: placeVisits.count,
                avgRating: avgRating,
                lastVisitedAt: lastVisit
            )
        }

        switch sortMode {
        case .rating:
            ranked.sort { ($0.avgRating ?? 0) > ($1.avgRating ?? 0) }
        case .visits:
            ranked.sort { $0.visitCount > $1.visitCount }
        case .recent:
            ranked.sort { ($0.lastVisitedAt ?? .distantPast) > ($1.lastVisitedAt ?? .distantPast) }
        }

        rankedPlaces = ranked
    }
}

struct RankedPlace {
    let place: CachedPlace
    let visitCount: Int
    let avgRating: Double?
    let lastVisitedAt: Date?
}

// MARK: - Ranking Row

struct RankingRow: View {
    let rank: Int
    let ranked: RankedPlace

    var body: some View {
        GlassCard {
            HStack(spacing: 14) {
                // Rank badge
                ZStack {
                    Circle()
                        .fill(rankColor.opacity(0.15))
                        .frame(width: 36, height: 36)

                    if rank <= 3 {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(rankColor)
                    } else {
                        Text("\(rank)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Place info
                VStack(alignment: .leading, spacing: 4) {
                    Text(ranked.place.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        if ranked.visitCount > 0 {
                            Label("\(ranked.visitCount)", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        }

                        if let rating = ranked.avgRating {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Spacer()

                // City
                if let city = ranked.place.city {
                    Text(city)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: .orange
        case 2: .gray
        case 3: .brown
        default: .clear
        }
    }
}

#Preview {
    RankingView()
        .modelContainer(for: [CachedPlace.self, Visit.self, Review.self], inMemory: true)
}
