import SwiftUI
import SwiftData

// MARK: - Food Stats Card (laufende Stats im Profil)

struct FoodStatsCard: View {
    let foodCounts: [(FoodItem, Int)]
    let totalVisits: Int

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Dein Döner-Konsum", systemImage: "chart.bar.fill")
                    .font(.headline)

                if foodCounts.isEmpty {
                    Text("Noch keine Check-ins mit Essenstyp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(foodCounts, id: \.0.id) { item, count in
                        HStack(spacing: 10) {
                            Text(item.emoji)
                                .font(.title3)
                                .frame(width: 32)

                            Text(item.label)
                                .font(.subheadline)
                                .frame(width: 80, alignment: .leading)

                            // Bar
                            GeometryReader { geo in
                                let maxCount = foodCounts.first?.1 ?? 1
                                let fraction = CGFloat(count) / CGFloat(max(maxCount, 1))
                                Capsule()
                                    .fill(.orange.gradient)
                                    .frame(width: geo.size.width * fraction, height: 20)
                                    .overlay(alignment: .trailing) {
                                        Text("\(count)")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                            .padding(.trailing, 6)
                                    }
                            }
                            .frame(height: 20)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Döner Wrapped (Jahresrückblick)

struct DoenerWrappedView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    @State private var appeared = false

    private var year: Int { Calendar.current.component(.year, from: Date()) }
    @State private var wrappedData = WrappedData()

    struct WrappedData {
        var totalVisits = 0
        var totalReviews = 0
        var uniquePlaces = 0
        var topPlace: (name: String, count: Int)?
        var topFood: (item: FoodItem, count: Int)?
        var foodCounts: [(FoodItem, Int)] = []
        var busiestMonth: (name: String, count: Int)?
        var totalRating: Double?
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Gradient background that changes per page
                pageBackground
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: currentPage)

                TabView(selection: $currentPage) {
                    // Page 1: Total visits
                    wrappedPage(page: 0) {
                        VStack(spacing: 16) {
                            Text("🥙")
                                .font(.system(size: 80))
                            Text("\(wrappedData.totalVisits)")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Döner-Besuche in \(String(year))")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .tag(0)

                    // Page 2: Favorite food
                    wrappedPage(page: 1) {
                        VStack(spacing: 16) {
                            if let top = wrappedData.topFood {
                                Text(top.item.emoji)
                                    .font(.system(size: 80))
                                Text("Dein Favorit:")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(top.item.label)
                                    .font(.system(size: 44, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("\(top.count)×")
                                    .font(.title.bold())
                                    .foregroundStyle(.white.opacity(0.9))
                            } else {
                                Text("🤷")
                                    .font(.system(size: 80))
                                Text("Noch kein Lieblings-Essen")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                        }
                    }
                    .tag(1)

                    // Page 3: Top place
                    wrappedPage(page: 2) {
                        VStack(spacing: 16) {
                            Text("📍")
                                .font(.system(size: 80))
                            if let top = wrappedData.topPlace {
                                Text("Dein Stammladen:")
                                    .font(.title3)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(top.name)
                                    .font(.title.bold())
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                Text("\(top.count) Besuche")
                                    .font(.title3.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .tag(2)

                    // Page 4: Places explored
                    wrappedPage(page: 3) {
                        VStack(spacing: 16) {
                            Text("🗺️")
                                .font(.system(size: 80))
                            Text("\(wrappedData.uniquePlaces)")
                                .font(.system(size: 72, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("verschiedene Läden entdeckt")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .tag(3)

                    // Page 5: Summary
                    wrappedPage(page: 4) {
                        VStack(spacing: 20) {
                            Text("🏆")
                                .font(.system(size: 60))
                            Text("Dein \(String(year))")
                                .font(.title.bold())
                                .foregroundStyle(.white)

                            VStack(spacing: 10) {
                                summaryRow("🥙", "\(wrappedData.totalVisits) Besuche")
                                summaryRow("⭐", "\(wrappedData.totalReviews) Bewertungen")
                                summaryRow("📍", "\(wrappedData.uniquePlaces) Läden")
                                if let food = wrappedData.topFood {
                                    summaryRow(food.item.emoji, "\(food.count)× \(food.item.label)")
                                }
                                if let month = wrappedData.busiestMonth {
                                    summaryRow("📅", "Aktivster Monat: \(month.name)")
                                }
                            }
                        }
                    }
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { loadWrapped() }
        }
    }

    private func wrappedPage<Content: View>(page: Int, @ViewBuilder content: () -> Content) -> some View {
        VStack {
            Spacer()
            content()
                .scaleEffect(currentPage == page && appeared ? 1 : 0.7)
                .opacity(currentPage == page && appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: appeared)
                .onChange(of: currentPage) { appeared = false; withAnimation { appeared = true } }
            Spacer()
        }
        .padding()
        .onAppear { withAnimation(.spring(response: 0.5)) { appeared = true } }
    }

    private func summaryRow(_ emoji: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.title2)
            Text(text)
                .font(.body.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
        }
        .padding(.horizontal)
    }

    private var pageBackground: some View {
        let colors: [(Color, Color)] = [
            (.orange, .red),
            (.pink, .purple),
            (.blue, .cyan),
            (.green, .teal),
            (.orange, .yellow),
        ]
        let pair = colors[min(currentPage, colors.count - 1)]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func loadWrapped() {
        let calendar = Calendar.current
        let startOfYear = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!

        let visitDesc = FetchDescriptor<Visit>(
            predicate: #Predicate { $0.visitedAt >= startOfYear },
            sortBy: [SortDescriptor(\.visitedAt)]
        )
        let reviewDesc = FetchDescriptor<Review>(
            predicate: #Predicate { $0.createdAt >= startOfYear }
        )

        let visits = (try? modelContext.fetch(visitDesc)) ?? []
        let reviews = (try? modelContext.fetch(reviewDesc)) ?? []

        // Food counts
        var foodMap: [String: Int] = [:]
        for v in visits {
            if let ft = v.foodType { foodMap[ft, default: 0] += 1 }
        }
        let foodCounts = FoodItem.all.compactMap { item -> (FoodItem, Int)? in
            guard let count = foodMap[item.id] else { return nil }
            return (item, count)
        }.sorted { $0.1 > $1.1 }

        // Top place
        let placeGroups = Dictionary(grouping: visits, by: \.placeName)
        let topPlace = placeGroups.max { $0.value.count < $1.value.count }

        // Busiest month
        let monthGroups = Dictionary(grouping: visits) { calendar.component(.month, from: $0.visitedAt) }
        let busiestMonth = monthGroups.max { $0.value.count < $1.value.count }
        let monthFormatter = DateFormatter()
        monthFormatter.locale = Locale(identifier: "de_DE")

        wrappedData = WrappedData(
            totalVisits: visits.count,
            totalReviews: reviews.count,
            uniquePlaces: Set(visits.map(\.placeOsmNodeID)).count,
            topPlace: topPlace.map { ($0.key, $0.value.count) },
            topFood: foodCounts.first,
            foodCounts: foodCounts,
            busiestMonth: busiestMonth.map {
                (monthFormatter.monthSymbols[$0.key - 1], $0.value.count)
            },
            totalRating: reviews.isEmpty ? nil : Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
        )
    }
}
