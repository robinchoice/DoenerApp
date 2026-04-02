import SwiftUI
import SwiftData

@main
struct DoenerAppApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
            } else {
                WelcomeView()
            }
        }
        .modelContainer(for: [
            CachedPlace.self,
            CachedRegion.self,
            Visit.self,
            Review.self,
            PendingSyncOperation.self,
        ])
    }
}
