import Vapor
import DoenerShared

extension UserDTO: @retroactive Content {}
extension PlaceDTO: @retroactive Content {}
extension FriendshipDTO: @retroactive Content {}
extension AuthResponse: @retroactive Content {}
extension AppleSignInRequest: @retroactive Content {}
