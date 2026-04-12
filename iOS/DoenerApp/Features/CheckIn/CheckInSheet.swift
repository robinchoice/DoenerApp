import SwiftUI
import SwiftData

struct CheckInSheet: View {
    let place: CachedPlace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var selectedFoodIndex = 0
    @State private var comment = ""
    @State private var showConfetti = false
    @State private var confettiEmoji = "🥙"

    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()

                VStack(spacing: 16) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    // Rotary picker
                    RotaryPicker(selectedIndex: $selectedFoodIndex, items: FoodItem.all)

                    // Trigger button
                    Button {
                        triggerCheckIn()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.orange.gradient)
                                .frame(width: 72, height: 72)
                                .shadow(color: .orange.opacity(0.4), radius: 12, y: 4)

                            Image(systemName: "checkmark")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)

                    // Comment
                    TextField("Kommentar (optional)", text: $comment)
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
                        .padding(.horizontal)
                }
                .padding()

                // Confetti overlay
                if showConfetti {
                    ConfettiView(emoji: confettiEmoji)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .navigationTitle("Einchecken")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private func triggerCheckIn() {
        let food = FoodItem.all[selectedFoodIndex]
        confettiEmoji = food.emoji

        // Save visit
        let visit = Visit(
            placeOsmNodeID: place.osmNodeID,
            placeName: place.name,
            visitedAt: Date(),
            comment: comment.isEmpty ? nil : comment,
            foodType: food.id
        )
        modelContext.insert(visit)
        try? modelContext.save()

        // Backend sync
        let osmID = place.osmNodeID
        let placeName = place.name
        let lat = place.latitude
        let lon = place.longitude
        let addr = place.address
        let postal = place.postalCode
        let city = place.city
        let hours = place.openingHours
        let visitedAt = visit.visitedAt
        let commentVal = comment.isEmpty ? nil : comment
        Task.detached {
            await VisitSyncService.push(
                osmNodeID: osmID, name: placeName, latitude: lat, longitude: lon,
                address: addr, postalCode: postal, city: city, openingHours: hours,
                visitedAt: visitedAt, comment: commentVal
            )
        }

        // Confetti!
        withAnimation(.spring(response: 0.3)) {
            showConfetti = true
        }

        // Dismiss after confetti
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            dismiss()
        }
    }
}

// MARK: - Confetti

struct ConfettiView: View {
    let emoji: String
    @State private var particles: [ConfettiParticle] = []

    struct ConfettiParticle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let size: CGFloat
        let rotation: Double
        let delay: Double
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { p in
                    Text(emoji)
                        .font(.system(size: p.size))
                        .rotationEffect(.degrees(p.rotation))
                        .position(x: p.x, y: p.y)
                        .animation(
                            .easeOut(duration: 1.5).delay(p.delay),
                            value: p.y
                        )
                }
            }
            .onAppear {
                let width = geo.size.width
                let height = geo.size.height
                // Generate particles
                particles = (0..<20).map { _ in
                    ConfettiParticle(
                        x: CGFloat.random(in: 0...width),
                        y: -50,
                        size: CGFloat.random(in: 20...40),
                        rotation: Double.random(in: -45...45),
                        delay: Double.random(in: 0...0.3)
                    )
                }
                // Animate down
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeIn(duration: 1.5)) {
                        particles = particles.map { p in
                            var q = p
                            q.y = height + 100
                            return q
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
