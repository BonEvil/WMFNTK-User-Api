import Foundation
import Vapor

/// Login request DTO
public struct LoginRequestDTO: Content {
    public let email: String
    public let password: String
    
    public init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

/// Verify request DTO
public struct VerifyRequestDTO: Content {
    public let email: String
    public let code: Int
    
    public init(email: String, code: Int) {
        self.email = email
        self.code = code
    }
}

/// User DTO for response
public struct UserDTO: Content {
    public let id: UUID
    public let email: String
    public let firstName: String
    public let lastName: String
    public let phone: String?
    public let dateCreated: Date?
    public let dateLastUpdated: Date?
    
    public init(
        id: UUID,
        email: String,
        firstName: String,
        lastName: String,
        phone: String?,
        dateCreated: Date?,
        dateLastUpdated: Date?
    ) {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.dateCreated = dateCreated
        self.dateLastUpdated = dateLastUpdated
    }
} 