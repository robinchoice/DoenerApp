import SwiftUI
import SwiftData

struct FriendsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthStore.self) private var authStore
    @State private var store = FriendsStore()
    @State private var showingSearch = false

    var body: some View {
        List {
            if !store.incomingPending.isEmpty {
                Section("Anfragen") {
                    ForEach(store.incomingPending) { f in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(f.user.displayName).font(.body)
                                Text("Möchte dich als Freund hinzufügen").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Annehmen") {
                                Task { await store.accept(f.id) }
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.orange)
                        }
                    }
                }
            }

            if !store.outgoingPending.isEmpty {
                Section("Gesendete Anfragen") {
                    ForEach(store.outgoingPending) { f in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(f.user.displayName).font(.body)
                                Text("Ausstehend").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Zurückziehen", role: .destructive) {
                                Task { await store.remove(f.id) }
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }

            Section("Freunde (\(store.accepted.count))") {
                if store.accepted.isEmpty {
                    Text("Noch keine Freunde")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.accepted) { f in
                        Text(f.user.displayName)
                            .swipeActions {
                                Button("Entfernen", role: .destructive) {
                                    Task { await store.remove(f.id) }
                                }
                            }
                    }
                }
            }
        }
        .navigationTitle("Freunde")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingSearch = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showingSearch) {
            FriendSearchSheet(store: store)
        }
        .task { await store.load(into: modelContext) }
        .refreshable { await store.load(into: modelContext) }
    }
}

struct FriendSearchSheet: View {
    let store: FriendsStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Display-Name eingeben…", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(.horizontal)
                    .onSubmit {
                        Task { await store.search(displayName: query) }
                    }

                Button("Suchen") {
                    Task { await store.search(displayName: query) }
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)

                List {
                    ForEach(store.searchResults) { user in
                        HStack {
                            Text(user.displayName)
                            Spacer()
                            Button("Anfragen") {
                                Task {
                                    await store.sendRequest(to: user.id)
                                    dismiss()
                                }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                        }
                    }
                }
            }
            .navigationTitle("Freund suchen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
