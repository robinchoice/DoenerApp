import SwiftUI
import SwiftData

struct ReviewSheet: View {
    let place: CachedPlace
    var existingReview: Review?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var rating: Int = 0
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                // Döner rating
                DoenerRatingView(value: rating, size: 40, interactive: true) { newValue in
                    rating = newValue
                }
                .padding(.vertical, 8)

                // Rating label
                if rating > 0 {
                    Text(ratingLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                        .transition(.scale.combined(with: .opacity))
                }

                // Text input
                TextField("Was war gut, was nicht? (optional)", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.plain)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.orange.opacity(0.2), lineWidth: 0.5)
                            }
                    }

                Spacer()
            }
            .padding()
            .navigationTitle(existingReview != nil ? "Bewertung bearbeiten" : "Bewerten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                        .disabled(rating == 0)
                }
            }
        }
        .onAppear {
            if let existingReview {
                rating = existingReview.rating
                text = existingReview.text ?? ""
            }
        }
    }

    private var ratingLabel: String {
        switch rating {
        case 1: "Schlecht"
        case 2: "Naja"
        case 3: "Okay"
        case 4: "Gut"
        case 5: "Ausgezeichnet"
        default: ""
        }
    }

    private func save() {
        if let existingReview {
            existingReview.rating = rating
            existingReview.text = text.isEmpty ? nil : text
            existingReview.updatedAt = Date()
        } else {
            let review = Review(
                placeOsmNodeID: place.osmNodeID,
                placeName: place.name,
                rating: rating,
                text: text.isEmpty ? nil : text
            )
            modelContext.insert(review)
        }

        updatePlaceRating()
        try? modelContext.save()

        // Fire-and-forget backend sync. Skips silently if not authenticated.
        let osmID = place.osmNodeID
        let placeName = place.name
        let lat = place.latitude
        let lon = place.longitude
        let addr = place.address
        let postal = place.postalCode
        let city = place.city
        let hours = place.openingHours
        let ratingValue = rating
        let textValue = text.isEmpty ? nil : text
        Task.detached {
            await ReviewSyncService.push(
                osmNodeID: osmID, name: placeName, latitude: lat, longitude: lon,
                address: addr, postalCode: postal, city: city, openingHours: hours,
                rating: ratingValue, text: textValue
            )
        }

        dismiss()
    }

    private func updatePlaceRating() {
        let osmID = place.osmNodeID
        let descriptor = FetchDescriptor<Review>(
            predicate: #Predicate { $0.placeOsmNodeID == osmID }
        )
        guard let reviews = try? modelContext.fetch(descriptor) else { return }
        place.reviewCount = reviews.count
        place.avgRating = reviews.isEmpty ? nil : Double(reviews.reduce(0) { $0 + $1.rating }) / Double(reviews.count)
    }
}
