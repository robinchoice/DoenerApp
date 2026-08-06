import SwiftUI
import SwiftData

@main
struct DoenerAppApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var authStore = AuthStore()
    @State private var isSyncing = false
    @Environment(\.scenePhase) private var scenePhase

    private let container: ModelContainer = Self.makeContainer()

    private static func makeContainer() -> ModelContainer {
        let schema = Schema([
            CachedPlace.self, CachedRegion.self, Visit.self, Review.self,
            PendingSyncOperation.self, CachedFriendship.self, MissingShopReport.self
        ])
        let configuration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            // A schema change (e.g. place IDs switching from Int64 to String)
            // can leave an incompatible store on existing installs. Self-heal
            // by wiping the local store instead of crash-looping — local
            // favorites/notes/pending syncs are lost, but the app stays usable.
            print("[App] ModelContainer init failed, resetting local store: \(error)")
            let url = configuration.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("ModelContainer init failed even after local store reset: \(error)")
            }
        }
    }

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
