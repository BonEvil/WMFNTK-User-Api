import Foundation
import Vapor
import WMFNTKModels

// MARK: - User Profile DTOs

/// User profile response DTO
public struct UserProfileResponseDTO: Content {
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

/// Update profile request DTO
public struct UpdateProfileRequestDTO: Content {
    public let firstName: String
    public let lastName: String
    public let phone: String?
    
    public init(firstName: String, lastName: String, phone: String?) {
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
    }
}

// MARK: - Account DTOs

/// Account response DTO
public struct AccountResponseDTO: Content {
    public let id: UUID
    public let data: AccountData
    public let dateCreated: Date?
    public let dateLastUpdated: Date?
    
    public init(
        id: UUID,
        data: AccountData,
        dateCreated: Date?,
        dateLastUpdated: Date?
    ) {
        self.id = id
        self.data = data
        self.dateCreated = dateCreated
        self.dateLastUpdated = dateLastUpdated
    }
}

/// Update account request DTO
public struct UpdateAccountRequestDTO: Content {
    public let title: String
    public let description: String?
    
    public init(title: String, description: String?) {
        self.title = title
        self.description = description
    }
}

// MARK: - Account User DTOs

/// Account user response DTO
public struct AccountUserResponseDTO: Content {
    public let userId: UUID
    public let email: String
    public let firstName: String
    public let lastName: String
    public let role: UInt8
    public let dateCreated: Date?
    
    public init(
        userId: UUID,
        email: String,
        firstName: String,
        lastName: String,
        role: UInt8,
        dateCreated: Date?
    ) {
        self.userId = userId
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.role = role
        self.dateCreated = dateCreated
    }
}

/// Add user to account request DTO
public struct AddUserToAccountRequestDTO: Content {
    public let email: String
    public let role: UInt8
    
    public init(email: String, role: UInt8) {
        self.email = email
        self.role = role
    }
}

/// Pending account user DTO (for invited users who have not signed up yet)
public struct PendingAccountUserDTO: Content {
    public let email: String
    public let role: UInt8
    public let dateCreated: Date?
    
    public init(email: String, role: UInt8, dateCreated: Date?) {
        self.email = email
        self.role = role
        self.dateCreated = dateCreated
    }
}

/// Response DTO for listing account users and pending invitations
public struct AccountUsersListResponseDTO: Content {
    public let users: [AccountUserResponseDTO]
    public let pendingInvitations: [PendingAccountUserDTO]
    
    public init(users: [AccountUserResponseDTO], pendingInvitations: [PendingAccountUserDTO]) {
        self.users = users
        self.pendingInvitations = pendingInvitations
    }
} 