import Foundation
import Vapor
import Fluent
import WMFNTKModels

/// Base middleware that extracts and validates user role for an account
public struct AccountRoleMiddleware: AsyncMiddleware {
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
            // From URL parameter: /api/v1/accounts/{accountId}/...
            guard let uuid = UUID(uuidString: accountIdParam) else {
                throw Abort(.badRequest, reason: "Invalid account ID format")
            }
            accountId = uuid
        } else if let accountIdBody = try? request.content.get(UUID.self, at: "accountId") {
            // From request body
            accountId = accountIdBody
        } else {
            throw Abort(.badRequest, reason: "Account ID required")
        }
        
        // Get user's role for this account
        guard let role = try await Role.query(on: request.db)
            .filter(FieldKey("user_id"), .equal, user.id!)
            .filter(FieldKey("account_id"), .equal, accountId)
            .first()
        else {
            throw Abort(.forbidden, reason: "Access denied - no role found for this account")
        }
        
        // Store the account ID and role in request for later use
        request.storage[AccountRoleKey.self] = (accountId: accountId, role: role.role)
        
        return try await next.respond(to: request)
    }
}

/// Middleware for checking if user has owner role (role = 0)
public struct OwnerMiddleware: AsyncMiddleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let accountRole = request.storage[AccountRoleKey.self] else {
            throw Abort(.internalServerError, reason: "Account role not found - ensure AccountRoleMiddleware is applied first")
        }
        
        guard accountRole.role == 0 else {
            throw Abort(.forbidden, reason: "Owner access required")
        }
        
        return try await next.respond(to: request)
    }
}

/// Middleware for checking if user has admin role (role <= 1)
public struct AdminMiddleware: AsyncMiddleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let accountRole = request.storage[AccountRoleKey.self] else {
            throw Abort(.internalServerError, reason: "Account role not found - ensure AccountRoleMiddleware is applied first")
        }
        
        guard accountRole.role <= 1 else {
            throw Abort(.forbidden, reason: "Admin access required")
        }
        
        return try await next.respond(to: request)
    }
}

/// Middleware for checking if user has member role (role <= 2)
public struct MemberMiddleware: AsyncMiddleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        guard let accountRole = request.storage[AccountRoleKey.self] else {
            throw Abort(.internalServerError, reason: "Account role not found - ensure AccountRoleMiddleware is applied first")
        }
        
        guard accountRole.role <= 2 else {
            throw Abort(.forbidden, reason: "Member access required")
        }
        
        return try await next.respond(to: request)
    }
}

// Storage key for account role information
private struct AccountRoleKey: StorageKey {
    typealias Value = (accountId: UUID, role: UInt8)
}

// Extension to easily access account role information from request
extension Request {
    /// Get the account ID from account role middleware
    public var accountId: UUID? {
        get { storage[AccountRoleKey.self]?.accountId }
    }
    
    /// Get the user's role for the account from account role middleware
    public var userRole: UInt8? {
        get { storage[AccountRoleKey.self]?.role }
    }
    
    /// Get both account ID and role from account role middleware
    public var accountRole: (accountId: UUID, role: UInt8)? {
        get { storage[AccountRoleKey.self] }
    }
} 