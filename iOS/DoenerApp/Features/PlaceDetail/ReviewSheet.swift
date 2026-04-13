import SwiftUI
import SwiftData

struct ReviewSheet: View {
    let place: CachedPlace
    var existingReview: Review?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var rating: Int = 0
    @State private var sauceRating: Int = 0
    @State private var fleischRating: Int = 0
    @State private var brotRating: Int = 0
    @State private var overrideGesamt: Bool = false
    @State private var text: String = ""
    @State private var specialNote: String = ""

    private var computedRating: Int {
        let dims = [sauceRating, fleischRating, brotRating].filter { $0 > 0 }
        guard !dims.isEmpty else { return 0 }
        return Int((Double(dims.reduce(0, +)) / Double(dims.count)).rounded())
    }

    private var effectiveRating: Int {
        if overrideGesamt { return rating }
        let computed = computedRating
        return computed > 0 ? computed : rating
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Dimension ratings
                    VStack(spacing: 16) {
                        dimensionRow("Soße", value: $sauceRating)
                        dimensionRow("Fleisch", value: $fleischRating)
                        dimensionRow("Brot", value: $brotRating)
                    }
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.orange.opacity(0.2), lineWidth: 0.5)
                            }
                    }

                    // Overall rating
                    VStack(spacing: 8) {
                        HStack {
                            Text("Gesamt")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            if computedRating > 0 {
                                Button(overrideGesamt ? "Auto" : "Manuell") {
                                    withAnimation(.spring(duration: 0.3)) {
                                        overrideGesamt.toggle()
                                        if !overrideGesamt {
                                            rating = computedRating
                                        }
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.orange)
                            }
                        }

                        DoenerRatingView(
                            value: effectiveRating,
                            size: 40,
                            interactive: overrideGesamt || computedRating == 0
                        ) { newValue in
                            rating = newValue
                            if computedRating > 0 { overrideGesamt = true }
                        }

                        if effectiveRating > 0 {
                            Text(ratingLabel(effectiveRating))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.orange)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }

                    // Special note
                    TextField("Was macht den Laden besonders?", text: $specialNote)
                        .lineLimit(1)
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
                }
                .padding()
            }
            .navigationTitle(existingReview != nil ? "Bewertung bearbeiten" : "Bewerten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                        .disabled(effectiveRating == 0)
                }
            }
        }
        .onAppear {
            if let existingReview {
                rating = existingReview.rating
                sauceRating = existingReview.sauceRating ?? 0
                fleischRating = existingReview.fleischRating ?? 0
                brotRating = existingReview.brotRating ?? 0
                text = existingReview.text ?? ""
                // Check if the stored rating differs from computed → user had overridden
                let computed = [sauceRating, fleischRating, brotRating].filter { $0 > 0 }
                if !computed.isEmpty {
                    let avg = Int((Double(computed.reduce(0, +)) / Double(computed.count)).rounded())
                    overrideGesamt = existingReview.rating != avg
                }
            }
            specialNote = place.specialNote ?? ""
        }
    }

    private func dimensionRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .frame(width: 60, alignment: .leading)
            DoenerRatingView(value: value.wrappedValue, size: 28, interactive: true) { newValue in
                value.wrappedValue = newValue
                if !overrideGesamt {
                    rating = computedRating
                }
            }
            Spacer()
            if value.wrappedValue > 0 {
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        value.wrappedValue = 0
                        if !overrideGesamt { rating = computedRating }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        }
    }

    private func ratingLabel(_ value: Int) -> String {
        switch value {
        case 1: "Schlecht"
        case 2: "Naja"
        case 3: "Okay"
        case 4: "Gut"
        case 5: "Ausgezeichnet"
        default: ""
        }
    }

    private func save() {
        let finalRating = effectiveRating
        let sauce: Int? = sauceRating > 0 ? sauceRating : nil
        let fleisch: Int? = fleischRating > 0 ? fleischRating : nil
        let brot: Int? = brotRating > 0 ? brotRating : nil
        let special: String? = specialNote.isEmpty ? nil : specialNote

        if let existingReview {
            existingReview.rating = finalRating
            existingReview.sauceRating = sauce
            existingReview.fleischRating = fleisch
            existingReview.brotRating = brot
            existingReview.text = text.isEmpty ? nil : text
            existingReview.updatedAt = Date()
        } else {
            let review = Review(
                placeOsmNodeID: place.osmNodeID,
                placeName: place.name,
                rating: finalRating,
                sauceRating: sauce,
                fleischRating: fleisch,
                brotRating: brot,
                text: text.isEmpty ? nil : text
            )
            modelContext.insert(review)
        }

        place.specialNote = special
        updatePlaceRating()
        try? modelContext.save()

        // Backend sync with queue fallback
        let osmID = place.osmNodeID
        let body = ReviewSyncService.UpsertReviewBody(
            rating: finalRating,
            sauceRating: sauce,
            fleischRating: fleisch,
            brotRating: brot,
            text: text.isEmpty ? nil : text,
            specialNote: special,
            name: place.name,
            latitude: place.latitude,
            longitude: place.longitude,
            address: place.address,
            postalCode: place.postalCode,
            city: place.city,
            openingHours: place.openingHours
        )
        Task {
            if !await ReviewSyncService.push(osmNodeID: osmID, body: body) {
                SyncQueueService.enqueueReview(osmNodeID: osmID, body: body, context: modelContext)
            }
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
