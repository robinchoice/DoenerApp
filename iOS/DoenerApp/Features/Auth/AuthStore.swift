import Foundation

@MainActor
@Observable
final class AuthStore: NSObject {
    var currentUser: UserDTO?
    var isLoading = false
    var lastError: String?

    var isAuthenticated: Bool { currentUser != nil }

    private let api = APIClient.shared

    func bootstrap() async {
        guard KeychainStore.loadToken() != nil else { return }
        do {
            let user: UserDTO = try await api.get("auth/me")
            self.currentUser = user
        } catch {
            // Token invalid — clear it
            KeychainStore.deleteToken()
        }
    }

    func signIn(identityToken: String, displayName: String?) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            let body = AppleSignInRequest(identityToken: identityToken, displayName: displayName)
            let response: AuthResponse = try await api.post("auth/apple", body: body)
            KeychainStore.saveToken(response.accessToken)
            self.currentUser = response.user
        } catch {
            lastError = error.localizedDescription
        }
    }

    func devSignIn(displayName: String) async {
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            let body = DevSignInRequest(displayName: displayName)
            let response: AuthResponse = try await api.post("auth/dev", body: body)
            KeychainStore.saveToken(response.accessToken)
            self.currentUser = response.user
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateDisplayName(_ name: String) async throws {
        let updated: UserDTO = try await api.patch("users/me", body: UpdateMeRequest(displayName: name))
        self.currentUser = updated
    }

    func signOut() {
        KeychainStore.deleteToken()
        currentUser = nil
    }
}
