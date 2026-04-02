import SwiftUI

struct NoteSheet: View {
    let place: CachedPlace
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var text: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text(place.name)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                TextField("Deine Notiz…", text: $text, axis: .vertical)
                    .lineLimit(4...10)
                    .textFieldStyle(.plain)
                    .padding()
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(.blue.opacity(0.2), lineWidth: 0.5)
                            }
                    }

                Spacer()
            }
            .padding()
            .navigationTitle("Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .fontWeight(.semibold)
                }
                if place.userNote != nil {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Notiz löschen", role: .destructive) { delete() }
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            text = place.userNote ?? ""
        }
    }

    private func save() {
        place.userNote = text.isEmpty ? nil : text
        try? modelContext.save()
        dismiss()
    }

    private func delete() {
        place.userNote = nil
        try? modelContext.save()
        dismiss()
    }
}
