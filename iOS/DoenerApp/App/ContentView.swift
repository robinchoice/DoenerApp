import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Karte", systemImage: "map.fill") {
                MapView()
            }

            Tab("Feed", systemImage: "person.2.fill") {
                FeedView()
            }

            Tab("Ranking", systemImage: "trophy.fill") {
                RankingsPlaceholderView()
            }

            Tab("Profil", systemImage: "person.crop.circle.fill") {
                ProfilePlaceholderView()
            }
        }
        .tint(.orange)
    }
}

struct RankingsPlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                ContentUnavailableView(
                    "Kommt bald",
                    systemImage: "trophy",
                    description: Text("Dein persönliches Döner-Ranking erscheint hier.")
                )
            }
            .navigationTitle("Ranking")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
}

struct ProfilePlaceholderView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                GlassBackground()
                ContentUnavailableView(
                    "Kommt bald",
                    systemImage: "person.crop.circle",
                    description: Text("Dein Profil, Stempel und Erfolge erscheinen hier.")
                )
            }
            .navigationTitle("Profil")
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
    }
}

// Reusable glass background for non-map screens
struct GlassBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                .orange.opacity(0.08),
                .clear,
                .orange.opacity(0.04)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
