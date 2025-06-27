import Foundation
import Vapor
import JWT
import WMFNTKModels

/// Middleware for JWT authentication with automatic token refresh
public struct AuthMiddleware: AsyncMiddleware {
    public init() {}
    
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        // Get the Authorization header
        guard let authHeader = request.headers.first(name: "Authorization") else {
            throw Abort(.unauthorized, reason: "Missing Authorization header")
        }
        
        // Extract token from "Bearer <token>" format
        let token = authHeader.replacingOccurrences(of: "Bearer ", with: "")
        
        // Verify and decode the JWT token
        let payload = try await request.jwt.verify(token, as: UserTokenPayload.self)
        
        // Get user ID from token
        let userId = payload.subject.value
        
        // Fetch user from database
        guard let user = try await User.find(UUID(uuidString: userId), on: request.db) else {
            throw Abort(.unauthorized, reason: "User not found")
        }
        
        // Verify session token matches the stored token
        guard let sessionToken = user.sessionToken,
              sessionToken == token else {
            throw Abort(.unauthorized, reason: "Invalid session")
        }
        
        // Check if session token is expired
        if let sessionExpiresAt = user.sessionTokenExpiresAt,
           Date() > sessionExpiresAt {
            throw Abort(.unauthorized, reason: "Session expired")
        }
        
        // Generate new token for this request
        let newToken = try await generateToken(for: user, on: request)
        
        // Update user's session token
        user.sessionToken = newToken
        user.sessionTokenExpiresAt = Date().addingTimeInterval(600) // 10 minutes
        try await user.save(on: request.db)
        
        // Store AuthenticatableUser in request for later use
        let authenticatableUser = AuthenticatableUser(userId: try user.requireID())
        request.auth.login(authenticatableUser)
        
        // Store the new token in request for later use
        request.storage[NewTokenKey.self] = newToken
        
        // Continue with the request and capture any errors
        do {
            let response = try await next.respond(to: request)
            
            // Add the new token to the response header (for all successful responses)
            response.headers.replaceOrAdd(name: "x-new-token", value: newToken)
            
            return response
        } catch let error as Abort {
            // For Abort errors, create a response with the error and add the token
            let response = Response(status: error.status)
            
            // Add the new token to the response header (except for 401 errors)
            if error.status != .unauthorized {
                response.headers.replaceOrAdd(name: "x-new-token", value: newToken)
            }
            
            // Add error details to response body
            let errorResponse = ["error": error.reason]
            try response.content.encode(errorResponse)
            
            return response
        } catch {
            // For any other errors, create a 500 response and add the token
            let response = Response(status: .internalServerError)
            
            // Add the new token to the response header
            response.headers.replaceOrAdd(name: "x-new-token", value: newToken)
            
            // Add error details to response body
            let errorResponse = ["error": "Internal server error"]
            try response.content.encode(errorResponse)
            
            return response
        }
    }
    
    /// Generate JWT token for user
    private func generateToken(for user: User, on req: Request) async throws -> String {
        let payload = UserTokenPayload(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            expiration: ExpirationClaim(value: Date().addingTimeInterval(600)), // 10 minutes
            issuer: IssuerClaim(value: "WMFNTK-User-API"),
            issuedAt: IssuedAtClaim(value: Date())
        )
        
        return try await req.jwt.sign(payload)
    }
}

// Storage key for new token
private struct NewTokenKey: StorageKey {
    typealias Value = String
}

/// Extension to add authentication helper to Request
extension Request {
    /// Get the authenticated user
    public var authUser: User? {
        get { 
            guard auth.get(AuthenticatableUser.self) != nil else {
                return nil
            }
            // Note: This would need to be async in a real implementation
            // For now, we'll return nil and let the route handler fetch the user
            return nil
        }
        set { 
            if let newValue = newValue {
                let authenticatableUser = AuthenticatableUser(userId: try! newValue.requireID())
                auth.login(authenticatableUser)
            }
        }
    }
    
    /// Get the authenticated user asynchronously
    public func getAuthenticatedUser() async throws -> User? {
        guard let authenticatableUser = auth.get(AuthenticatableUser.self) else {
            return nil
        }
        return try await authenticatableUser.userForRequest(self)
    }
    
    /// Get the new token generated by AuthMiddleware
    public var newToken: String? {
        get { storage[NewTokenKey.self] }
    }
} 