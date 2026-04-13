import Vapor
import DoenerShared

extension UserDTO: @retroactive Content {}
extension PlaceDTO: @retroactive Content {}
extension FriendshipDTO: @retroactive Content {}
extension AuthResponse: @retroactive Content {}
extension AppleSignInRequest: @retroactive Content {}
extension ReviewDTO: @retroactive Content {}
extension VisitDTO: @retroactive Content {}
extension PlaceSummaryDTO: @retroactive Content {}
extension FeedItem: @retroactive Content {}
extension LiveStatusDTO: @retroactive Content {}
