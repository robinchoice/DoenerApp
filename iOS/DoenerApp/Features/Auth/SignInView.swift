import SwiftUI

struct SignInView: View {
    @Environment(AuthStore.self) private var authStore
    @State private var displayName: String = ""
    var onSuccess: () -> Void = {}

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(.orange.opacity(0.15)).frame(width: 140, height: 140)
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
            }

            VStack(spacing: 12) {
                Text("Account anlegen")
                    .font(.title.bold())
                Text("Wähl einen Namen, damit du Freunde\nhinzufügen und Erfolge sammeln kannst.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Dein Name", text: $displayName)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal)

            if let err = authStore.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            Button {
                Task {
                    await authStore.devSignIn(displayName: displayName.trimmingCharacters(in: .whitespaces))
                    if authStore.isAuthenticated { onSuccess() }
                }
            } label: {
                Text(authStore.isLoading ? "Lädt…" : "Loslegen")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(canSubmit ? Color.orange : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSubmit || authStore.isLoading)
            .padding(.horizontal)

            Button("Später") {
                onSuccess()
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.bottom, 40)
        }
        .padding()
    }

    private var canSubmit: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 2 && trimmed.count <= 30
    }
}
