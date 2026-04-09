import SwiftUI
import SwiftData
import MapKit

struct PlaceDetailView: View {
    let place: CachedPlace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var visits: [Visit] = []
    @State private var reviews: [Review] = []
    @State private var showCheckInConfirmation = false
    @State private var showReviewSheet = false
    @State private var showNoteSheet = false
    @State private var checkInComment = ""
    @State private var justCheckedIn = false
    @State private var showCheckInExplanation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with glass card
                GlassCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(place.name)
                                .font(.title2.bold())

                            if let address = place.address, !address.isEmpty {
                                Label(address, systemImage: "mappin")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let city = place.city {
                                Text([place.postalCode, city].compactMap { $0 }.joined(separator: " "))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        RatingBadge(rating: place.avgRating, count: place.reviewCount)
                    }
                }

                // Opening hours
                if let hours = place.openingHours, !hours.isEmpty {
                    GlassCard {
                        Label {
                            Text(hours)
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                // Action buttons
                HStack(spacing: 8) {
                    ActionButton(title: place.isFavorite ? "Favorit" : "Merken", icon: place.isFavorite ? "heart.fill" : "heart", color: .pink) {
                        place.isFavorite.toggle()
                        try? modelContext.save()
                    }

                    ActionButton(title: "Einchecken", icon: "checkmark.circle.fill", color: .green) {
                        showCheckInConfirmation = true
                    }
                    .overlay(alignment: .topTrailing) {
                        Button {
                            showCheckInExplanation = true
                        } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .background(Circle().fill(.background))
                        }
                        .offset(x: 6, y: -2)
                        .accessibilityLabel("Was ist Einchecken?")
                    }

                    ActionButton(title: "Bewerten", icon: "fork.knife.circle.fill", color: .orange) {
                        showReviewSheet = true
                    }

                    ActionButton(title: "Notiz", icon: place.userNote != nil ? "note.text.badge.checkmark" : "note.text", color: .blue) {
                        showNoteSheet = true
                    }

                    ActionButton(title: "Route", icon: "arrow.triangle.turn.up.right.diamond.fill", color: .purple) {
                        openInMaps()
                    }
                }

                // Note
                if let note = place.userNote, !note.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Notiz", systemImage: "note.text")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.blue)
                            Text(note)
                                .font(.subheadline)
                        }
                    }
                    .onTapGesture { showNoteSheet = true }
                }

                // Reviews
                if !reviews.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Bewertungen (\(reviews.count))")
                            .font(.headline)

                        ForEach(reviews) { review in
                            ReviewRow(review: review) {
                                showReviewSheet = true
                            }
                        }
                    }
                }

                // Visit history
                if !visits.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Besuche (\(visits.count))")
                            .font(.headline)

                        ForEach(visits) { visit in
                            VisitRow(visit: visit)
                        }
                    }
                }

                // Mini Map
                GlassCard(padding: 0) {
                    Map {
                        Marker(place.name, coordinate: place.coordinate)
                            .tint(.orange)
                    }
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .allowsHitTesting(false)
                }
            }
            .padding()
        }
        .onAppear {
            loadVisits()
            loadReviews()
        }
        .sheet(isPresented: $showReviewSheet) {
            loadReviews()
        } content: {
            ReviewSheet(place: place, existingReview: reviews.first)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showNoteSheet) {
            NoteSheet(place: place)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .overlay {
            if justCheckedIn {
                CheckInToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showCheckInExplanation) {
            CheckInExplanationSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert("Einchecken", isPresented: $showCheckInConfirmation) {
            TextField("Kommentar (optional)", text: $checkInComment)
            Button("Einchecken") { checkIn() }
            Button("Abbrechen", role: .cancel) { checkInComment = "" }
        } message: {
            Text("Bei \(place.name) einchecken?")
        }
    }

    private func checkIn() {
        let visit = Visit(
            placeOsmNodeID: place.osmNodeID,
            placeName: place.name,
            comment: checkInComment.isEmpty ? nil : checkInComment
        )
        modelContext.insert(visit)
        try? modelContext.save()
        checkInComment = ""
        loadVisits()

        withAnimation { justCheckedIn = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { justCheckedIn = false }
        }
    }

    private func loadVisits() {
        let osmID = place.osmNodeID
        let descriptor = FetchDescriptor<Visit>(
            predicate: #Predicate { $0.placeOsmNodeID == osmID },
            sortBy: [SortDescriptor(\.visitedAt, order: .reverse)]
        )
        visits = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func loadReviews() {
        let osmID = place.osmNodeID
        let descriptor = FetchDescriptor<Review>(
            predicate: #Predicate { $0.placeOsmNodeID == osmID },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        reviews = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

// MARK: - Review Row

struct ReviewRow: View {
    let review: Review
    let onEdit: () -> Void

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    DoenerRatingView(value: review.rating, size: 14)

                    Spacer()

                    Button("Bearbeiten", systemImage: "pencil") { onEdit() }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .labelStyle(.iconOnly)
                }

                if let text = review.text {
                    Text(text)
                        .font(.subheadline)
                }

                Text(review.createdAt, format: .dateTime.day().month().year())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Visit Row

struct VisitRow: View {
    let visit: Visit

    var body: some View {
        GlassCard {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(visit.visitedAt, format: .dateTime.day().month().year().hour().minute())
                        .font(.subheadline.weight(.medium))

                    if let comment = visit.comment {
                        Text(comment)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - Check-In Explanation

struct CheckInExplanationSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
            }
            .padding(.top, 30)

            Text("Was ist Einchecken?")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 14) {
                ExplanationRow(icon: "seal.fill", color: .purple,
                               text: "Jeder Check-in zählt einen Stempel auf deiner Stempelkarte.")
                ExplanationRow(icon: "person.2.fill", color: .blue,
                               text: "Dein Besuch erscheint im Feed — auch deine Freunde sehen wo du isst.")
                ExplanationRow(icon: "trophy.fill", color: .orange,
                               text: "Achievements werden freigeschaltet, wenn du oft genug eincheckst.")
            }
            .padding(.horizontal, 24)

            Spacer()

            Button("Verstanden") { dismiss() }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.green.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
}

private struct ExplanationRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Check-In Toast

struct CheckInToast: View {
    var body: some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("Eingecheckt!")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .padding(.top, 8)

            Spacer()
        }
    }
}

// MARK: - Glass Components

struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.5
                            )
                    }
                    .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
            }
    }
}

struct RatingBadge: View {
    let rating: Double?
    let count: Int

    var body: some View {
        VStack(spacing: 2) {
            if let rating {
                Text(String(format: "%.1f", rating))
                    .font(.title.bold())
                    .foregroundStyle(.orange)
            } else {
                Text("—")
                    .font(.title.bold())
                    .foregroundStyle(.secondary)
            }
            Text(count == 1 ? "1 Bewertung" : "\(count) Bewertungen")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.orange.opacity(0.2), lineWidth: 1)
                }
        }
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .white.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 0.5
                            )
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PlaceDetailView(place: CachedPlace(
        osmNodeID: 12345,
        name: "Mustafa's Gemüse Kebap",
        latitude: 52.5069,
        longitude: 13.3878,
        address: "Mehringdamm 32",
        postalCode: "10961",
        city: "Berlin",
        openingHours: "Mo-Su 10:00-02:00"
    ))
    .modelContainer(for: [CachedPlace.self, Visit.self, Review.self], inMemory: true)
}
