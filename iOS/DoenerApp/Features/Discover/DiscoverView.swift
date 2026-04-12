import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DiscoverViewModel()
    @State private var locationManager = LocationManager()
    @State private var selectedPlace: CachedPlace?

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                if viewModel.isLoading && viewModel.nearbyPlaces.isEmpty && viewModel.trendingPlaces.isEmpty {
                    ProgressView("Lade Empfehlungen…")
                        .tint(.orange)
                } else if !viewModel.searchQuery.isEmpty {
                    searchResultsList
                } else {
                    discoverSections
                }
            }
            .navigationTitle("Entdecken")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .searchable(text: $viewModel.searchQuery, prompt: "Döner-Laden suchen…")
            .onChange(of: viewModel.searchQuery) { viewModel.search() }
            .onAppear {
                viewModel.setup(modelContext: modelContext, locationManager: locationManager)
                locationManager.requestPermission()
            }
            .task { await viewModel.refresh() }
            .refreshable { await viewModel.refresh() }
            .sheet(item: $selectedPlace) { place in
                PlaceDetailView(place: place)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationCornerRadius(24)
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if viewModel.searchResults.isEmpty {
                    ContentUnavailableView.search(text: viewModel.searchQuery)
                } else {
                    ForEach(viewModel.searchResults) { place in
                        Button { selectedPlace = place } label: {
                            PlaceListRow(
                                name: place.name,
                                city: place.city,
                                avgRating: place.avgRating,
                                reviewCount: place.reviewCount,
                                specialNote: place.specialNote
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Discover Sections

    private var discoverSections: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // In deiner Nähe
                if !viewModel.nearbyPlaces.isEmpty {
                    discoverSection(title: "In deiner Nähe", icon: "location.fill", places: viewModel.nearbyPlaces)
                }

                // Gerade im Hype
                if !viewModel.trendingPlaces.isEmpty {
                    discoverSection(title: "Gerade im Hype", icon: "flame.fill", places: viewModel.trendingPlaces)
                }

                // Neu bewertet
                if !viewModel.recentReviews.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Neu bewertet", systemImage: "star.bubble.fill")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        ForEach(viewModel.recentReviews) { entry in
                            FeedCard(item: entry)
                        }
                    }
                }

                // Empty state
                if viewModel.nearbyPlaces.isEmpty && viewModel.trendingPlaces.isEmpty && viewModel.recentReviews.isEmpty && !viewModel.isLoading {
                    ContentUnavailableView(
                        "Noch keine Empfehlungen",
                        systemImage: "fork.knife",
                        description: Text("Checke bei Döner-Läden ein und bewerte sie, um Empfehlungen zu sehen.")
                    )
                }
            }
            .padding()
        }
    }

    private func discoverSection(title: String, icon: String, places: [DiscoverViewModel.DiscoverPlace]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(places) { dp in
                        Button {
                            if let cached = viewModel.cachedPlace(for: dp) {
                                selectedPlace = cached
                            }
                        } label: {
                            DiscoverPlaceCard(place: dp)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Discover Place Card

struct DiscoverPlaceCard: View {
    let place: DiscoverViewModel.DiscoverPlace

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)

                if let city = place.city {
                    Text(city)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 6) {
                    if let avg = place.avgRating {
                        DoenerRatingView(value: Int(avg.rounded()), size: 12)
                        Text(String(format: "%.1f", avg))
                            .font(.caption.bold())
                            .foregroundStyle(.orange)
                    }
                    if place.reviewCount > 0 {
                        Text("(\(place.reviewCount))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                if let note = place.specialNote, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 160)
    }
}

// MARK: - Place List Row

struct PlaceListRow: View {
    let name: String
    let city: String?
    let avgRating: Double?
    let reviewCount: Int
    let specialNote: String?

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))

                    if let city {
                        Text(city)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let note = specialNote, !note.isEmpty {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                if let avg = avgRating, reviewCount > 0 {
                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", avg))
                            .font(.title3.bold())
                            .foregroundStyle(.orange)
                        Text("\(reviewCount) Bew.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
