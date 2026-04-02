import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var items: [FeedEntry] = []

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                if items.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Aktivität",
                        systemImage: "fork.knife",
                        description: Text("Checke bei einem Döner-Laden ein oder schreibe eine Bewertung.")
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(items) { item in
                                FeedCard(item: item)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Feed")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .onAppear { loadFeed() }
        }
    }

    private func loadFeed() {
        let visitDescriptor = FetchDescriptor<Visit>(
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        let reviewDescriptor = FetchDescriptor<Review>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )

        let visits = (try? modelContext.fetch(visitDescriptor)) ?? []
        let reviews = (try? modelContext.fetch(reviewDescriptor)) ?? []

        var entries: [FeedEntry] = []

        for visit in visits {
            entries.append(FeedEntry(
                id: visit.persistentModelID.hashValue,
                type: .visit,
                placeName: visit.placeName,
                timestamp: visit.visitedAt,
                comment: visit.comment,
                rating: nil
            ))
        }

        for review in reviews {
            entries.append(FeedEntry(
                id: review.persistentModelID.hashValue,
                type: .review,
                placeName: review.placeName,
                timestamp: review.createdAt,
                comment: review.text,
                rating: review.rating
            ))
        }

        items = entries.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Feed Entry

struct FeedEntry: Identifiable {
    let id: Int
    let type: EntryType
    let placeName: String
    let timestamp: Date
    let comment: String?
    let rating: Int?

    enum EntryType {
        case visit
        case review
    }
}

// MARK: - Feed Card

struct FeedCard: View {
    let item: FeedEntry

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(iconColor.opacity(0.12))
                            .frame(width: 36, height: 36)

                        Image(systemName: iconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(iconColor)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionText)
                            .font(.subheadline.weight(.semibold))

                        Text(item.placeName)
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Text(item.timestamp, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Rating stars
                if let rating = item.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundStyle(star <= rating ? .orange : .gray.opacity(0.3))
                        }
                    }
                }

                // Comment
                if let comment = item.comment, !comment.isEmpty {
                    Text(comment)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var iconName: String {
        switch item.type {
        case .visit: "checkmark.circle.fill"
        case .review: "star.fill"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .visit: .green
        case .review: .orange
        }
    }

    private var actionText: String {
        switch item.type {
        case .visit: "Eingecheckt"
        case .review: "Bewertet"
        }
    }
}

#Preview {
    FeedView()
        .modelContainer(for: [Visit.self, Review.self], inMemory: true)
}
