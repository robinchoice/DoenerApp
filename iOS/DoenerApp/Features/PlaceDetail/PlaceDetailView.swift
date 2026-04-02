import SwiftUI
import SwiftData
import MapKit

struct PlaceDetailView: View {
    let place: CachedPlace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var visits: [Visit] = []
    @State private var showCheckInConfirmation = false
    @State private var checkInComment = ""
    @State private var justCheckedIn = false

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
                HStack(spacing: 10) {
                    ActionButton(title: "Einchecken", icon: "checkmark.circle.fill", color: .green) {
                        showCheckInConfirmation = true
                    }

                    ActionButton(title: "Bewerten", icon: "star.fill", color: .orange) {
                        // TODO: Phase 3
                    }

                    ActionButton(title: "Notiz", icon: "note.text", color: .blue) {
                        // TODO: Phase 3
                    }

                    ActionButton(title: "Route", icon: "arrow.triangle.turn.up.right.diamond.fill", color: .purple) {
                        openInMaps()
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
        .onAppear { loadVisits() }
        .overlay {
            if justCheckedIn {
                CheckInToast()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
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

    private func openInMaps() {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
        mapItem.name = place.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
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
    .modelContainer(for: [CachedPlace.self, Visit.self], inMemory: true)
}
