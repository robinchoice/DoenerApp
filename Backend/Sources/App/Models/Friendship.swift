import Vapor
import Fluent
import DoenerShared

final class Friendship: Model, Content, @unchecked Sendable {
    static let schema = "friendships"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "requester_id")
    var requester: User

    @Parent(key: "addressee_id")
    var addressee: User

    @Enum(key: "status")
    var status: Status

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    init() {}

    init(id: UUID? = nil, requesterID: UUID, addresseeID: UUID, status: Status = .pending) {
        self.id = id
        self.$requester.id = requesterID
        self.$addressee.id = addresseeID
        self.status = status
    }

    enum Status: String, Codable, CaseIterable {
        case pending
        case accepted
    }
}
