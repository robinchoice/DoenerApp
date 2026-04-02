import SwiftUI
import SwiftData
import MapKit

struct MapView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = MapViewModel()
    @State private var locationManager = LocationManager()
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var regionChangeID = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $viewModel.cameraPosition, selection: $viewModel.selectedPlace) {
                    UserAnnotation()

                    ForEach(viewModel.places) { place in
                        Annotation(place.name, coordinate: place.coordinate) {
                            DoenerPinView(place: place, visitCount: viewModel.visitCounts[place.osmNodeID] ?? 0)
                        }
                        .tag(place)
                    }
                }
                .tint(.blue) // prevent inherited tint from coloring map tiles
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onMapCameraChange(frequency: .onEnd) { context in
                    visibleRegion = context.region
                    regionChangeID += 1
                }
                .task(id: regionChangeID) {
                    // Debounce: wait before fetching so rapid panning doesn't spam requests
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    if let region = visibleRegion {
                        await viewModel.onRegionChanged(region)
                    }
                }

                // Floating info bar at top
                VStack {
                    if !viewModel.places.isEmpty {
                        PlaceCountPill(count: viewModel.places.count)
                            .padding(.top, 4)
                    }
                    Spacer()

                    if viewModel.isLoading {
                        LoadingPill()
                            .padding(.bottom, 80)
                    }

                    if let error = viewModel.errorMessage {
                        ErrorPill(message: error) {
                            viewModel.errorMessage = nil
                            if let region = visibleRegion {
                                Task { await viewModel.fetchPlaces(in: region) }
                            }
                        }
                        .padding(.bottom, 80)
                    }
                }
            }
            .navigationTitle("Döner Karte")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .sheet(item: $viewModel.selectedPlace) { place in
                PlaceDetailView(place: place)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.ultraThinMaterial)
                    .presentationCornerRadius(24)
                    .onDisappear { viewModel.loadVisitCounts() }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                locationManager.requestPermission()
            }
        }
    }
}

// MARK: - Pin

struct DoenerPinView: View {
    let place: CachedPlace
    var visitCount: Int = 0
    @State private var appeared = false

    private var pinColor: Color { visitCount > 0 ? .green : .orange }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Glass circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Circle()
                            .strokeBorder(pinColor, lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

                if visitCount > 0 {
                    Text("\(visitCount)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(pinColor)
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(pinColor)
                }
            }

            // Pin tail
            Triangle()
                .fill(pinColor)
                .frame(width: 10, height: 5)
                .offset(y: -1)
        }
        .scaleEffect(appeared ? 1 : 0.5)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                appeared = true
            }
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.closeSubpath()
        }
    }
}

// MARK: - Pills

struct PlaceCountPill: View {
    let count: Int

    var body: some View {
        Text("\(count) Döner in der Nähe")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

struct LoadingPill: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .tint(.orange)
            Text("Lade Döner-Läden…")
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

struct ErrorPill: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        Button {
            onRetry?()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(message)
                    .font(.caption)
                    .lineLimit(1)
                if onRetry != nil {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MapView()
        .modelContainer(for: CachedPlace.self, inMemory: true)
}
