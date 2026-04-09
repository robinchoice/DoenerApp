import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var authStore

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(APIConfig.backendOverrideKey) private var backendOverride: String = ""

    @State private var displayNameDraft: String = ""
    @State private var displayNameError: String?
    @State private var displayNameSaving = false

    @State private var pendingReset: ResetAction?
    @State private var infoMessage: String?

    @Query(sort: \MissingShopReport.createdAt, order: .reverse) private var shopReports: [MissingShopReport]

    enum ResetAction: Identifiable {
        case logout
        case ownData
        case mapCache
        case fullReset

        var id: String {
            switch self {
            case .logout: "logout"
            case .ownData: "ownData"
            case .mapCache: "mapCache"
            case .fullReset: "fullReset"
            }
        }

        var title: String {
            switch self {
            case .logout: "Vom Server abmelden"
            case .ownData: "Eigene Daten löschen"
            case .mapCache: "Karten-Cache leeren"
            case .fullReset: "Komplett zurücksetzen"
            }
        }

        var description: String {
            switch self {
            case .logout: "Token wird verworfen. Lokale Daten bleiben."
            case .ownData: "Bewertungen, Besuche und Notizen werden gelöscht. Account bleibt."
            case .mapCache: "Gespeicherte Döner-Läden werden verworfen. Werden beim nächsten Map-Pan neu geladen."
            case .fullReset: "Alles weg — wie nach einer frischen Installation. Onboarding läuft erneut."
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                accountSection
                backendSection
                shopReportsSection
                resetSection
                aboutSection
            }
            .navigationTitle("Einstellungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .alert(item: $pendingReset) { action in
                Alert(
                    title: Text(action.title),
                    message: Text(action.description),
                    primaryButton: .destructive(Text("Ja, machen")) { perform(action) },
                    secondaryButton: .cancel(Text("Abbrechen"))
                )
            }
            .alert("Erledigt", isPresented: Binding(
                get: { infoMessage != nil },
                set: { if !$0 { infoMessage = nil } }
            )) {
                Button("OK", role: .cancel) { infoMessage = nil }
            } message: {
                Text(infoMessage ?? "")
            }
            .onAppear {
                displayNameDraft = authStore.currentUser?.displayName ?? ""
            }
        }
    }

    // MARK: - Sections

    private var accountSection: some View {
        Section("Account") {
            if authStore.isAuthenticated {
                TextField("Anzeigename", text: $displayNameDraft)
                    .autocorrectionDisabled()
                if let err = displayNameError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button {
                    Task { await saveDisplayName() }
                } label: {
                    HStack {
                        Text("Anzeigename speichern")
                        if displayNameSaving {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(displayNameSaving || displayNameDraft.trimmingCharacters(in: .whitespaces) == authStore.currentUser?.displayName)
            } else {
                Text("Nicht angemeldet")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var backendSection: some View {
        Section {
            TextField(APIConfig.defaultBaseURL.absoluteString, text: $backendOverride)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !backendOverride.isEmpty {
                Button("Auf Default zurücksetzen", role: .destructive) {
                    backendOverride = ""
                }
            }
        } header: {
            Text("Backend-URL")
        } footer: {
            Text("Leer = Default (\(APIConfig.defaultBaseURL.absoluteString)). Praktisch beim WiFi-Wechsel — kein Recompile nötig.")
        }
    }

    @ViewBuilder
    private var shopReportsSection: some View {
        if shopReports.isEmpty {
            EmptyView()
        } else {
            Section {
                ForEach(shopReports) { report in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(report.name).font(.subheadline.weight(.semibold))
                        if let hint = report.addressOrHint {
                            Text(hint).font(.caption).foregroundStyle(.secondary)
                        }
                        if let lat = report.latitude, let lon = report.longitude {
                            Text("📍 \(String(format: "%.5f", lat)), \(String(format: "%.5f", lon))")
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        if let note = report.note {
                            Text(note).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(shopReports[index])
                    }
                    try? modelContext.save()
                }
            } header: {
                Text("Gemeldete Läden (\(shopReports.count))")
            } footer: {
                Text("Lokal gespeichert. Robin überträgt sie später ins Backend / OSM.")
            }
        }
    }

    private var resetSection: some View {
        Section {
            resetButton(.logout)
            resetButton(.ownData)
            resetButton(.mapCache)
            resetButton(.fullReset)
        } header: {
            Text("Dev-Modus")
        } footer: {
            Text("Reset-Funktionen für Tester. Keine Aktion ist umkehrbar.")
        }
    }

    private func resetButton(_ action: ResetAction) -> some View {
        Button {
            pendingReset = action
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .foregroundStyle(action == .fullReset ? .red : .primary)
                Text(action.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        Section("Über") {
            HStack {
                Text("Version")
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("Build")
                Spacer()
                Text(buildNumber)
                    .foregroundStyle(.secondary)
            }
            Text("Made with ❤️ und viel Knoblauchsoße.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    // MARK: - Actions

    private func saveDisplayName() async {
        let trimmed = displayNameDraft.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2, trimmed.count <= 30 else {
            displayNameError = "2 bis 30 Zeichen."
            return
        }
        displayNameError = nil
        displayNameSaving = true
        defer { displayNameSaving = false }
        do {
            try await authStore.updateDisplayName(trimmed)
            infoMessage = "Anzeigename aktualisiert."
        } catch {
            displayNameError = error.localizedDescription
        }
    }

    private func perform(_ action: ResetAction) {
        switch action {
        case .logout:
            authStore.signOut()
            infoMessage = "Abgemeldet."
        case .ownData:
            wipeUserData()
            infoMessage = "Eigene Daten gelöscht."
        case .mapCache:
            wipeMapCache()
            infoMessage = "Karten-Cache geleert."
        case .fullReset:
            authStore.signOut()
            wipeUserData()
            wipeMapCache()
            wipeFriendships()
            hasCompletedOnboarding = false
            backendOverride = ""
            infoMessage = "Alles zurückgesetzt. App jetzt neu starten."
        }
    }

    private func wipeUserData() {
        try? modelContext.delete(model: Visit.self)
        try? modelContext.delete(model: Review.self)
        try? modelContext.delete(model: PendingSyncOperation.self)
        // Reset per-place user fields on cached places
        if let places = try? modelContext.fetch(FetchDescriptor<CachedPlace>()) {
            for p in places {
                p.userNote = nil
                p.userRating = nil
                p.isFavorite = false
            }
        }
        try? modelContext.save()
    }

    private func wipeMapCache() {
        try? modelContext.delete(model: CachedPlace.self)
        try? modelContext.delete(model: CachedRegion.self)
        try? modelContext.save()
    }

    private func wipeFriendships() {
        try? modelContext.delete(model: CachedFriendship.self)
        try? modelContext.save()
    }
}
