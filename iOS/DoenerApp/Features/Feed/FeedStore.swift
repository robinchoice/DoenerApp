import Foundation

@MainActor
@Observable
final class FeedStore {
    var items: [FeedItem] = []
    var liveStatuses: [LiveStatusDTO] = []
    var isLoading = false
    var hasMore = true
    var lastError: String?

    private var cursor: String?
    private let api = APIClient.shared

    func loadInitial() async {
        guard !isLoading else { return }
        cursor = nil
        hasMore = true
        items = []
        await fetchPage()
        await fetchLiveStatuses()
    }

    func loadMore() async {
        guard !isLoading, hasMore else { return }
        await fetchPage()
    }

    func refresh() async {
        cursor = nil
        hasMore = true
        items = []
        await fetchPage()
        await fetchLiveStatuses()
    }

    private func fetchPage() async {
        isLoading = true
        defer { isLoading = false }
        var query: [String: String] = ["limit": "20"]
        if let cursor { query["cursor"] = cursor }
        do {
            let page: FeedPage = try await api.get("feed", query: query)
            items.append(contentsOf: page.items)
            cursor = page.cursor
            hasMore = page.hasMore
        } catch APIError.unauthorized {
            // not signed in — feed stays empty
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func fetchLiveStatuses() async {
        do {
            let statuses: [LiveStatusDTO] = try await api.get("feed/live")
            liveStatuses = statuses
        } catch {
            // non-critical, ignore
        }
    }
}
