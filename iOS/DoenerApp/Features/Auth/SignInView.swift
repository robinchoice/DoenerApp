import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthStore.self) private var authStore
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
                Text("Damit du Freunde hinzufügen\nund Erfolge sammeln kannst.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let err = authStore.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Spacer()

            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName]
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
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

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let tokenString = String(data: tokenData, encoding: .utf8) else {
                authStore.lastError = "Apple Token nicht erhalten"
                return
            }
            let displayName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            Task {
                await authStore.signIn(
                    identityToken: tokenString,
                    displayName: displayName.isEmpty ? nil : displayName
                )
                if authStore.isAuthenticated {
                    onSuccess()
                }
            }
        case .failure(let error):
            authStore.lastError = error.localizedDescription
        }
    }
}
