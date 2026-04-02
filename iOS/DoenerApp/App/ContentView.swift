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
                RankingView()
            }

            Tab("Profil", systemImage: "person.crop.circle.fill") {
                ProfileView()
            }
        }
        .onAppear {
            UITabBar.appearance().tintColor = UIColor.systemOrange
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
