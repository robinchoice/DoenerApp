import Foundation
import SwiftData

enum SyncQueueService {
    private static let maxRetries = 5

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static func enqueueVisit(placeID: String, body: VisitSyncService.CreateVisitBody, context: ModelContext) {
        guard let payload = try? encoder.encode(body) else { return }
        let op = PendingSyncOperation(
            entityType: "visit",
            entityID: placeID,
            operationType: "create",
            payload: payload
        )
        context.insert(op)
        try? context.save()
        print("[SyncQueue] enqueued visit for place/\(placeID)")
    }

    static func enqueueReview(placeID: String, body: ReviewSyncService.UpsertReviewBody, context: ModelContext) {
        guard let payload = try? encoder.encode(body) else { return }
        let op = PendingSyncOperation(
            entityType: "review",
            entityID: placeID,
            operationType: "create",
            payload: payload
        )
        context.insert(op)
        try? context.save()
        print("[SyncQueue] enqueued review for place/\(placeID)")
    }

    @MainActor
    static func processQueue(context: ModelContext) async {
        let descriptor = FetchDescriptor<PendingSyncOperation>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        guard let ops = try? context.fetch(descriptor), !ops.isEmpty else { return }
        print("[SyncQueue] processing \(ops.count) pending operation(s)")

        for op in ops {
            let placeID = op.entityID
            var handled = false

            do {
                switch op.entityType {
                case "visit":
                    let body = try decoder.decode(VisitSyncService.CreateVisitBody.self, from: op.payload)
                    let _: VisitSyncService.VisitResponse = try await APIClient.shared.post(
                        "places/\(placeID)/visits",
                        body: body
                    )
                    handled = true
                case "review":
                    let body = try decoder.decode(ReviewSyncService.UpsertReviewBody.self, from: op.payload)
                    let _: ReviewSyncService.ReviewResponse = try await APIClient.shared.post(
                        "places/\(placeID)/reviews",
                        body: body
                    )
                    handled = true
                default:
                    handled = true
                }
            } catch APIError.unauthorized {
                // Not signed in yet — keep for next time
            } catch {
                op.retryCount += 1
                if op.retryCount >= maxRetries {
                    print("[SyncQueue] giving up on \(op.entityType)/\(placeID) after \(maxRetries) retries")
                    handled = true
                }
            }

            if handled {
                context.delete(op)
            }
        }

        try? context.save()
    }
}
