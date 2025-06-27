import Foundation
import Vapor

/// Signup email request DTO
public struct SignupEmailRequestDTO: Content, Sendable {
    public let email: String
    
    public init(email: String) {
        self.email = email
    }
}

/// Signup email verification DTO
public struct SignupEmailVerifyDTO: Content, Sendable {
    public let email: String
    public let code: Int
    
    public init(email: String, code: Int) {
        self.email = email
        self.code = code
    }
}

/// Signup account creation DTO
public struct SignupAccountRequestDTO: Content, Sendable {
    public let accountTitle: String
    public let accountDescription: String?
    public let userPassword: String
    public let userFirstName: String
    public let userLastName: String
    public let userPhoneNumber: String?
    
    public init(
        accountTitle: String,
        accountDescription: String?,
        userPassword: String,
        userFirstName: String,
        userLastName: String,
        userPhoneNumber: String?
    ) {
        self.accountTitle = accountTitle
        self.accountDescription = accountDescription
        self.userPassword = userPassword
        self.userFirstName = userFirstName
        self.userLastName = userLastName
        self.userPhoneNumber = userPhoneNumber
    }
}

/// Signup token payload for JWT
public struct SignupTokenPayload: Content, Sendable {
    public let email: String
    public let signupToken: String
    public let expiresAt: Date
    
    public init(email: String, signupToken: String, expiresAt: Date) {
        self.email = email
        self.signupToken = signupToken
        self.expiresAt = expiresAt
    }
}

/// Signup response DTO
public struct SignupResponseDTO: Content, Sendable, AsyncResponseEncodable {
    public let accountId: UUID
    public let userId: UUID
    public let email: String
    public let firstName: String
    public let lastName: String
    
    public init(accountId: UUID, userId: UUID, email: String, firstName: String, lastName: String) {
        self.accountId = accountId
        self.userId = userId
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
    }
    
    public func encodeResponse(for request: Request) async throws -> Response {
        try await self.encodeResponse(status: .ok, for: request)
    }
} 