import SwiftUI
import SwiftData

@main
struct DoenerAppApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var authStore = AuthStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .environment(authStore)
            .task { await authStore.bootstrap() }
        }
        .modelContainer(for: [
            CachedPlace.self,
            CachedRegion.self,
            Visit.self,
            Review.self,
            PendingSyncOperation.self,
            CachedFriendship.self,
            MissingShopReport.self,
        ])
    }
}
