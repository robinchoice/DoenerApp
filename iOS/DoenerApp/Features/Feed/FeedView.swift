import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var segment: FeedSegment = .friends
    @State private var feedStore = FeedStore()
    @State private var myItems: [FeedEntry] = []

    enum FeedSegment { case mine, friends }

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                VStack(spacing: 0) {
                    Picker("", selection: $segment) {
                        Text("Freunde").tag(FeedSegment.friends)
                        Text("Meine").tag(FeedSegment.mine)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if segment == .friends {
                        friendsFeedContent
                    } else {
                        myFeedContent
                    }
                }
            }
            .navigationTitle("Feed")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .task(id: segment) {
                if segment == .friends && feedStore.items.isEmpty {
                    await feedStore.loadInitial()
                } else if segment == .mine {
                    loadMyFeed()
                }
            }
        }
    }

    // MARK: - Friends Feed

    private var friendsFeedContent: some View {
        Group {
            if feedStore.isLoading && feedStore.items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if feedStore.items.isEmpty {
                ContentUnavailableView(
                    "Keine Aktivität",
                    systemImage: "person.2",
                    description: Text("Füge Freunde hinzu, um ihre Döner-Aktivitäten zu sehen.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if !feedStore.liveStatuses.isEmpty {
                            LiveStatusBanner(statuses: feedStore.liveStatuses)
                        }
                        ForEach(feedStore.items) { item in
                            FriendFeedCard(item: item)
                                .onAppear {
                                    if item.id == feedStore.items.last?.id {
                                        Task { await feedStore.loadMore() }
                                    }
                                }
                        }
                        if feedStore.isLoading {
                            ProgressView().padding()
                        }
                    }
                    .padding()
                }
                .refreshable { await feedStore.refresh() }
            }
        }
    }

    // MARK: - My Feed

    private var myFeedContent: some View {
        Group {
            if myItems.isEmpty {
                ContentUnavailableView(
                    "Noch keine Aktivität",
                    systemImage: "fork.knife",
                    description: Text("Checke bei einem Döner-Laden ein oder schreibe eine Bewertung.")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(myItems) { item in
                            FeedCard(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
    }

    private func loadMyFeed() {
        let visits = (try? modelContext.fetch(FetchDescriptor<Visit>(sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]))) ?? []
        let reviews = (try? modelContext.fetch(FetchDescriptor<Review>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []

        var entries: [FeedEntry] = visits.map {
            FeedEntry(id: $0.persistentModelID.hashValue, type: .visit,
                      placeName: $0.placeName, timestamp: $0.visitedAt,
                      comment: $0.comment, rating: nil)
        }
        entries += reviews.map {
            FeedEntry(id: $0.persistentModelID.hashValue, type: .review,
                      placeName: $0.placeName, timestamp: $0.createdAt,
                      comment: $0.text, rating: $0.rating)
        }
        myItems = entries.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Live Status Banner

struct LiveStatusBanner: View {
    let statuses: [LiveStatusDTO]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(statuses, id: \.user.id) { status in
                    LiveStatusChip(status: status)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct LiveStatusChip: View {
    let status: LiveStatusDTO

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 4) {
                Text(status.user.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Text("isst gerade bei \(status.placeName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let food = status.foodType {
                    Text(food)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 160)
    }
}

// MARK: - Friend Feed Card

struct FriendFeedCard: View {
    let item: FeedItem

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
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
                        Text(item.user.displayName)
                            .font(.subheadline.weight(.semibold))
                        Text("\(actionText) \(item.place.name)")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Text(item.timestamp, format: .relative(presentation: .named))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let rating = item.review?.rating {
                    DoenerRatingView(value: rating, size: 14)
                }

                if let text = item.review?.text ?? item.visit?.comment, !text.isEmpty {
                    Text(text)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var iconName: String {
        switch item.type {
        case .visit: "checkmark.circle.fill"
        case .review: "fork.knife.circle.fill"
        case .achievement: "star.circle.fill"
        }
    }

    private var iconColor: Color {
        switch item.type {
        case .visit: .green
        case .review: .orange
        case .achievement: .yellow
        }
    }

    private var actionText: String {
        switch item.type {
        case .visit: "Eingecheckt bei"
        case .review: "Bewertet:"
        case .achievement: "Achievement:"
        }
    }
}

// MARK: - My Feed Entry (unchanged)

struct FeedEntry: Identifiable {
    let id: Int
    let type: EntryType
    let placeName: String
    let timestamp: Date
    let comment: String?
    let rating: Int?

    enum EntryType { case visit, review }
}

struct FeedCard: View {
    let item: FeedEntry

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
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

                if let rating = item.rating {
                    DoenerRatingView(value: rating, size: 14)
                }

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
        case .review: "fork.knife.circle.fill"
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
