import SwiftUI
import SwiftData
import CoreLocation

struct ReportShopSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Optional location to attach (typically the user's current coordinate from the map screen).
    var prefilledCoordinate: CLLocationCoordinate2D?

    @State private var name: String = ""
    @State private var address: String = ""
    @State private var note: String = ""
    @State private var attachLocation: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Laden") {
                    TextField("Name (z.B. Erbil)", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Adresse oder Stadtteil (optional)", text: $address)
                        .textInputAutocapitalization(.words)
                }

                if prefilledCoordinate != nil {
                    Section {
                        Toggle("Aktuellen Standort anhängen", isOn: $attachLocation)
                    } footer: {
                        Text("Hilft Robin, den Laden später zu finden.")
                    }
                }

                Section("Notiz (optional)") {
                    TextField("Was ist besonders? Special-Soße, Falafel-Rezept, etc.",
                              text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Laden fehlt?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Senden") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSubmit)
                }
            }
        }
    }

    private var canSubmit: Bool {
        name.trimmingCharacters(in: .whitespaces).count >= 2
    }

    private func save() {
        let coord = (attachLocation ? prefilledCoordinate : nil)
        let report = MissingShopReport(
            name: name.trimmingCharacters(in: .whitespaces),
            addressOrHint: address.trimmingCharacters(in: .whitespaces).isEmpty ? nil : address,
            latitude: coord?.latitude,
            longitude: coord?.longitude,
            note: note.trimmingCharacters(in: .whitespaces).isEmpty ? nil : note
        )
        modelContext.insert(report)
        try? modelContext.save()
        dismiss()
    }
}
