import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var authStore
    @State private var stats = ProfileStats()
    @State private var friendsStore = FriendsStore()
    @State private var showingSignIn = false
    @State private var showingSettings = false

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
                                Text(authStore.currentUser?.displayName ?? "Döner-Fan")
                                    .font(.title3.bold())

                                Text("Seit \(stats.memberSince, format: .dateTime.month().year())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if !authStore.isAuthenticated {
                                Button("Anmelden") { showingSignIn = true }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.orange)
                            }
                        }
                    }

                    // Friends row
                    if authStore.isAuthenticated {
                        NavigationLink {
                            FriendsView()
                        } label: {
                            GlassCard {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundStyle(.orange)
                                    Text("Freunde")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(friendsStore.acceptedCount)")
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
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
                    AchievementsView(stats: stats, friendsCount: friendsStore.acceptedCount)
                }
                .padding()
            }
            .background { GlassBackground() }
            .navigationTitle("Profil")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
                    .environment(authStore)
            }
            .onAppear { loadStats() }
            .task {
                if authStore.isAuthenticated {
                    await friendsStore.load(into: modelContext)
                }
            }
            .sheet(isPresented: $showingSignIn) {
                SignInView { showingSignIn = false }
                    .environment(authStore)
            }
        }
    }

    private func loadStats() {
        let visitDescriptor = FetchDescriptor<Visit>()
        let reviewDescriptor = FetchDescriptor<Review>()
        let placeDescriptor = FetchDescriptor<CachedPlace>()

        let visits = (try? modelContext.fetch(visitDescriptor)) ?? []
        let reviews = (try? modelContext.fetch(reviewDescriptor)) ?? []
        let places = (try? modelContext.fetch(placeDescriptor)) ?? []

        let uniqueOsmIDs = Set(visits.map(\.placeOsmNodeID))
        let visitsByPlace = Dictionary(grouping: visits, by: \.placeOsmNodeID)
        let maxVisits = visitsByPlace.values.map(\.count).max() ?? 0

        // Check for night visits (after 22:00)
        let calendar = Calendar.current
        let hasNight = visits.contains { calendar.component(.hour, from: $0.visitedAt) >= 22 }

        // Count unique visited places per city
        let placesByID = Dictionary(uniqueKeysWithValues: places.compactMap { p in
            (p.osmNodeID, p)
        })
        var cityCounts: [String: Int] = [:]
        for osmID in uniqueOsmIDs {
            if let city = placesByID[osmID]?.city, !city.isEmpty {
                cityCounts[city, default: 0] += 1
            }
        }

        stats = ProfileStats(
            totalVisits: visits.count,
            totalReviews: reviews.count,
            uniquePlaces: uniqueOsmIDs.count,
            memberSince: visits.map(\.visitedAt).min() ?? Date(),
            maxVisitsToSamePlace: maxVisits,
            hasNightVisit: hasNight,
            cityCounts: cityCounts
        )
    }
}

// MARK: - Stats

struct ProfileStats {
    var totalVisits = 0
    var totalReviews = 0
    var uniquePlaces = 0
    var memberSince = Date()
    var maxVisitsToSamePlace = 0
    var hasNightVisit = false
    var cityCounts: [String: Int] = [:]

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

                    Text(stats.stampTier.displayName)
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
                        Text("Noch \(remaining) Besuche bis \(stats.stampTier.nextTier!.displayName)")
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
        stats.stampTier.color
    }
}

// MARK: - Achievements

struct AchievementsView: View {
    let stats: ProfileStats
    let friendsCount: Int

    private var unlockedTypes: Set<AchievementType> {
        var unlocked = Set<AchievementType>()
        if stats.totalVisits >= 1 { unlocked.insert(.firstBite) }
        if stats.totalReviews >= 1 { unlocked.insert(.critic) }
        if stats.maxVisitsToSamePlace >= 5 { unlocked.insert(.regular) }
        if stats.uniquePlaces >= 10 { unlocked.insert(.explorer) }
        if stats.uniquePlaces >= 50 { unlocked.insert(.connoisseur) }
        if (stats.cityCounts["Berlin"] ?? 0) >= 5 { unlocked.insert(.berlinTour) }
        if (stats.cityCounts["Hamburg"] ?? 0) >= 5 { unlocked.insert(.hamburgTour) }
        // Tier mapping: Silver-Achievement bei Dönerfan (15 Stempel), Gold bei Dönermeister (60).
        if stats.stampTier >= .doenerfan { unlocked.insert(.stampCollectorSilver) }
        if stats.stampTier >= .doenermeister { unlocked.insert(.stampCollectorGold) }
        if stats.hasNightVisit { unlocked.insert(.nightOwl) }
        if friendsCount >= 5 { unlocked.insert(.socialButterfly) }
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
