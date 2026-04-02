import SwiftUI
import SwiftData

@main
struct DoenerAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
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
