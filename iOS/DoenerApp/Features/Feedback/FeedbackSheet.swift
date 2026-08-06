import SwiftUI
import PhotosUI
import UIKit

struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var message: String = ""
    @State private var selectedItem: PhotosPickerItem?
    @State private var screenshotData: Data?
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Was ist passiert?") {
                    TextField("Fehler oder Feedback beschreiben…", text: $message, axis: .vertical)
                        .lineLimit(5...10)
                }

                Section("Screenshot (optional)") {
                    if let screenshotData, let uiImage = UIImage(data: screenshotData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Screenshot auswählen", systemImage: "photo.on.rectangle")
                    }
                    if screenshotData != nil {
                        Button("Screenshot entfernen", role: .destructive) {
                            selectedItem = nil
                            screenshotData = nil
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Feedback geben")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await send() }
                    } label: {
                        if isSending {
                            ProgressView()
                        } else {
                            Text("Senden")
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSubmit || isSending)
                }
            }
            .onChange(of: selectedItem) {
                Task { await loadScreenshot() }
            }
        }
    }

    private var canSubmit: Bool {
        message.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5
    }

    private func loadScreenshot() async {
        guard let selectedItem,
              let data = try? await selectedItem.loadTransferable(type: Data.self) else { return }
        screenshotData = compressedJPEG(from: data)
    }

    private func compressedJPEG(from data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1080
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        return resized.jpegData(compressionQuality: 0.5)
    }

    private func send() async {
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        let request = CreateFeedbackRequest(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            screenshotBase64: screenshotData?.base64EncodedString(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
            buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        )

        do {
            let _: FeedbackDTO = try await APIClient.shared.post("feedback", body: request)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    FeedbackSheet()
}
