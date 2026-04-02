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
                        ErrorPill(message: error)
                            .padding(.bottom, 80)
                            .onTapGesture { viewModel.errorMessage = nil }
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

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Outer glow
                Circle()
                    .fill((visitCount > 0 ? Color.green : Color.orange).opacity(0.3))
                    .frame(width: 44, height: 44)
                    .blur(radius: 4)

                // Glass circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Circle()
                            .strokeBorder(visitCount > 0 ? .green.gradient : .orange.gradient, lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.15), radius: 6, y: 3)

                if visitCount > 0 {
                    Text("\(visitCount)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "fork.knife")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.orange)
                }
            }

            // Pin tail
            Triangle()
                .fill((visitCount > 0 ? Color.green : Color.orange).gradient)
                .frame(width: 12, height: 6)
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

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

#Preview {
    MapView()
        .modelContainer(for: CachedPlace.self, inMemory: true)
}
