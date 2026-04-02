import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var stats = ProfileStats()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Avatar + Name
                    GlassCard {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(.orange.gradient)
                                    .frame(width: 64, height: 64)

                                Image(systemName: "person.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Döner-Fan")
                                    .font(.title3.bold())

                                Text("Seit \(stats.memberSince, format: .dateTime.month().year())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }

                    // Stats grid
                    HStack(spacing: 12) {
                        StatCard(value: "\(stats.totalVisits)", label: "Besuche", icon: "checkmark.circle.fill", color: .green)
                        StatCard(value: "\(stats.totalReviews)", label: "Bewertungen", icon: "star.fill", color: .orange)
                        StatCard(value: "\(stats.uniquePlaces)", label: "Läden", icon: "mappin.circle.fill", color: .purple)
                    }

                    // Stamp card
                    StampCardView(stats: stats)

                    // Achievements
                    AchievementsView(stats: stats)
                }
                .padding()
            }
            .background { GlassBackground() }
            .navigationTitle("Profil")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear { loadStats() }
        }
    }

    private func loadStats() {
        let visitDescriptor = FetchDescriptor<Visit>()
        let reviewDescriptor = FetchDescriptor<Review>()

        let visits = (try? modelContext.fetch(visitDescriptor)) ?? []
        let reviews = (try? modelContext.fetch(reviewDescriptor)) ?? []

        let uniqueOsmIDs = Set(visits.map(\.placeOsmNodeID))

        stats = ProfileStats(
            totalVisits: visits.count,
            totalReviews: reviews.count,
            uniquePlaces: uniqueOsmIDs.count,
            memberSince: visits.map(\.visitedAt).min() ?? Date()
        )
    }
}

// MARK: - Stats

struct ProfileStats {
    var totalVisits = 0
    var totalReviews = 0
    var uniquePlaces = 0
    var memberSince = Date()

    var stampTier: StampTier {
        StampTier.tier(forStamps: totalVisits)
    }

    var stampsToNext: Int? {
        guard let next = stampTier.nextTier else { return nil }
        return next.stampsRequired - totalVisits
    }

    var stampProgress: Double {
        guard let next = stampTier.stampsToNextTier else { return 1.0 }
        let current = stampTier.stampsRequired
        let range = next - current
        guard range > 0 else { return 1.0 }
        return Double(totalVisits - current) / Double(range)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        GlassCard {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(value)
                    .font(.title2.bold())

                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Stamp Card

struct StampCardView: View {
    let stats: ProfileStats

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Stempelkarte", systemImage: "seal.fill")
                        .font(.headline)

                    Spacer()

                    Text(stats.stampTier.rawValue.capitalized)
                        .font(.subheadline.bold())
                        .foregroundStyle(tierColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(tierColor.opacity(0.15), in: Capsule())
                }

                // Progress bar
                VStack(alignment: .leading, spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.gray.opacity(0.15))
                                .frame(height: 8)

                            Capsule()
                                .fill(tierColor.gradient)
                                .frame(width: geo.size.width * stats.stampProgress, height: 8)
                        }
                    }
                    .frame(height: 8)

                    if let remaining = stats.stampsToNext {
                        Text("Noch \(remaining) Besuche bis \(stats.stampTier.nextTier!.rawValue.capitalized)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Höchste Stufe erreicht!")
                            .font(.caption)
                            .foregroundStyle(tierColor)
                    }
                }

                // Stamp dots
                let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)
                LazyVGrid(columns: columns, spacing: 6) {
                    let target = stats.stampTier.stampsToNextTier ?? stats.stampTier.stampsRequired
                    let currentInTier = stats.totalVisits - stats.stampTier.stampsRequired
                    let dotsToShow = max(target - stats.stampTier.stampsRequired, 10)

                    ForEach(0..<dotsToShow, id: \.self) { i in
                        Circle()
                            .fill(i < currentInTier ? tierColor : .gray.opacity(0.15))
                            .frame(width: 16, height: 16)
                            .overlay {
                                if i < currentInTier {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
        }
    }

    private var tierColor: Color {
        switch stats.stampTier {
        case .bronze: .brown
        case .silver: .gray
        case .gold: .orange
        case .platinum: .purple
        }
    }
}

// MARK: - Achievements

struct AchievementsView: View {
    let stats: ProfileStats

    private var unlockedTypes: Set<AchievementType> {
        var unlocked = Set<AchievementType>()
        if stats.totalVisits >= 1 { unlocked.insert(.firstBite) }
        if stats.totalReviews >= 1 { unlocked.insert(.critic) }
        if stats.uniquePlaces >= 10 { unlocked.insert(.explorer) }
        if stats.uniquePlaces >= 50 { unlocked.insert(.connoisseur) }
        return unlocked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Erfolge", systemImage: "trophy.fill")
                    .font(.headline)

                Spacer()

                Text("\(unlockedTypes.count)/\(AchievementType.allCases.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AchievementType.allCases, id: \.self) { type in
                    AchievementBadge(type: type, unlocked: unlockedTypes.contains(type))
                }
            }
        }
    }
}

struct AchievementBadge: View {
    let type: AchievementType
    let unlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(unlocked ? .orange.opacity(0.15) : .gray.opacity(0.08))
                    .frame(width: 52, height: 52)

                Image(systemName: type.iconName)
                    .font(.system(size: 22))
                    .foregroundStyle(unlocked ? .orange : .gray.opacity(0.3))
            }

            Text(type.title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(unlocked ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Visit.self, Review.self], inMemory: true)
}
