import Foundation
import Vapor
import Fluent
import WMFNTKModels

/// Middleware for checking if user has any role for the account
public struct HasAccountRoleMiddleware: AsyncMiddleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Get the authenticated user
        guard let authenticatableUser = request.auth.get(AuthenticatableUser.self) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        
        // Get the user from database
        guard let user = try await authenticatableUser.userForRequest(request) else {
            throw Abort(.unauthorized, reason: "User not found")
        }
        
        // Get account ID from request parameters or body
        let accountId: UUID
        
        if let accountIdParam = request.parameters.get("accountId") {
            guard let uuid = UUID(uuidString: accountIdParam) else {
                throw Abort(.badRequest, reason: "Invalid account ID format")
            }
            accountId = uuid
        } else if let accountIdBody = try? request.content.get(UUID.self, at: "accountId") {
            accountId = accountIdBody
        } else {
            throw Abort(.badRequest, reason: "Account ID required")
        }
        
        // Check if user has any role for this account
        let hasRole = try await Role.query(on: request.db)
            .filter(FieldKey("user_id"), .equal, user.id!)
            .filter(FieldKey("account_id"), .equal, accountId)
            .first() != nil
        
        guard hasRole else {
            throw Abort(.forbidden, reason: "Access denied - no role found for this account")
        }
        
        // Store the account ID in request for later use
        request.storage[AccountIDKey.self] = accountId
        
        return try await next.respond(to: request)
    }
}

// Storage key for account ID (shared with AdminMiddleware)
private struct AccountIDKey: StorageKey {
    typealias Value = UUID
}

extension Request {
    /// Get the account ID from middleware
    public var accountIdFromRole: UUID? {
        get { storage[AccountIDKey.self] }
    }
} 