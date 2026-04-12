import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 2 // Entdecken (middle)

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                FeedView()
                    .tag(0)

                RankingView()
                    .tag(1)

                DiscoverView()
                    .tag(2)

                MapView()
                    .tag(3)

                ProfileView()
                    .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)

            // Custom tab bar
            CustomTabBar(selectedTab: $selectedTab)
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: Int

    private let tabs: [(icon: String, label: String)] = [
        ("person.2.fill", "Feed"),
        ("trophy.fill", "Ranking"),
        ("sparkle.magnifyingglass", "Entdecken"),
        ("map.fill", "Karte"),
        ("person.crop.circle.fill", "Profil"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                if index == 2 {
                    // Prominent center tab
                    Button { selectedTab = index } label: {
                        VStack(spacing: 2) {
                            ZStack {
                                Circle()
                                    .fill(.orange)
                                    .frame(width: 52, height: 52)
                                    .shadow(color: .orange.opacity(0.4), radius: 8, y: 3)

                                Image(systemName: tabs[index].icon)
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .offset(y: -12)

                            Text(tabs[index].label)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(selectedTab == index ? .orange : .secondary)
                                .offset(y: -10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    // Normal tab
                    Button { selectedTab = index } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tabs[index].icon)
                                .font(.system(size: 20))
                                .foregroundStyle(selectedTab == index ? .orange : .secondary)

                            Text(tabs[index].label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(selectedTab == index ? .orange : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                    }
                }
            }
        }
        .padding(.bottom, 20)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
                .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
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
