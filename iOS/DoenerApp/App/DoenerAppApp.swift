import SwiftUI
import SwiftData

@main
struct DoenerAppApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var authStore = AuthStore()
    @State private var isSyncing = false
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer = {
        do {
            return try ModelContainer(for:
                CachedPlace.self, CachedRegion.self, Visit.self, Review.self,
                PendingSyncOperation.self, CachedFriendship.self, MissingShopReport.self
            )
        } catch {
            fatalError("ModelContainer init failed: \(error)")
        }
    }()

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
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, !isSyncing else { return }
            isSyncing = true
            Task {
                await SyncQueueService.processQueue(context: container.mainContext)
                isSyncing = false
            }
        }
    }
}
