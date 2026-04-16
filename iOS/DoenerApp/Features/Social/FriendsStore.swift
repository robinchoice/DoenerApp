import Foundation
import SwiftData

@MainActor
@Observable
final class FriendsStore {
    var friendships: [FriendshipDTO] = []
    var searchResults: [UserDTO] = []
    var isLoading = false
    var lastError: String?

    private let api = APIClient.shared

    var acceptedCount: Int {
        friendships.filter { $0.status == .accepted }.count
    }

    var incomingPending: [FriendshipDTO] {
        friendships.filter { $0.status == .pending && $0.direction == .incoming }
    }

    var outgoingPending: [FriendshipDTO] {
        friendships.filter { $0.status == .pending && $0.direction == .outgoing }
    }

    var accepted: [FriendshipDTO] {
        friendships.filter { $0.status == .accepted }
    }

    func load(into context: ModelContext? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result: [FriendshipDTO] = try await api.get("friends")
            self.friendships = result
            if let context { syncCache(to: context) }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func search(displayName: String) async {
        guard !displayName.isEmpty else {
            searchResults = []
            return
        }
        do {
            let users: [UserDTO] = try await api.get("users/search", query: ["displayName": displayName])
            self.searchResults = users
        } catch {
            lastError = error.localizedDescription
            searchResults = []
        }
    }

    func sendRequest(to userID: UUID) async {
        do {
            let body = CreateFriendRequestBody(addresseeID: userID)
            let f: FriendshipDTO = try await api.post("friends/requests", body: body)
            if !friendships.contains(where: { $0.id == f.id }) {
                friendships.append(f)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func accept(_ friendshipID: UUID) async {
        do {
            let f: FriendshipDTO = try await api.post("friends/requests/\(friendshipID)/accept", body: EmptyBody())
            if let idx = friendships.firstIndex(where: { $0.id == friendshipID }) {
                friendships[idx] = f
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func remove(_ friendshipID: UUID) async {
        do {
            try await api.delete("friends/\(friendshipID)")
            friendships.removeAll { $0.id == friendshipID }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func syncCache(to context: ModelContext) {
        let descriptor = FetchDescriptor<CachedFriendship>()
        let existing = (try? context.fetch(descriptor)) ?? []
        for old in existing { context.delete(old) }
        for f in friendships {
            let cached = CachedFriendship(
                id: f.id,
                userID: f.user.id,
                displayName: f.user.displayName,
                avatarURL: f.user.avatarURL,
                status: f.status.rawValue,
                direction: f.direction.rawValue,
                createdAt: f.createdAt
            )
            context.insert(cached)
        }
        try? context.save()
    }

    private struct EmptyBody: Encodable {}
}
