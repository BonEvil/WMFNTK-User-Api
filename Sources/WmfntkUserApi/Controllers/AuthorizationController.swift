import Foundation
import Vapor
import Fluent
import WMFNTKModels

/// Controller for handling user authorization and account management
public actor AuthorizationController {
    
    public init() {}
    
    nonisolated func routes(_ app: Application) throws {
        let protectedRoutes = app.grouped("api", "v1")
            .grouped(AuthMiddleware())
        
        // User profile routes (any authenticated user)
        // GET/PUT /api/v1/profile
        protectedRoutes.get("profile") { [self] req in
            try await getProfile(req)
        }
        
        protectedRoutes.put("profile") { [self] req in
            try await updateProfile(req)
        }
        
        // Account routes
        // Anyone with a role for the account can GET account details
        // GET /api/v1/accounts/:accountId
        let memberRoutes = protectedRoutes.grouped(AccountRoleMiddleware(), MemberMiddleware())
        memberRoutes.get("accounts", ":accountId") { [self] req in
            try await getAccount(req)
        }
        
        // Owner and admin route for full account information (read-only for admins)
        // GET /api/v1/accounts/:accountId/full
        let adminRoutes = protectedRoutes.grouped(AccountRoleMiddleware(), AdminMiddleware())
        adminRoutes.get("accounts", ":accountId", "full") { [self] req in
            try await getFullAccount(req)
        }
        
        // Owner-only routes for account management
        // PUT /api/v1/accounts/:accountId
        // GET /api/v1/accounts/:accountId/users
        // POST /api/v1/accounts/:accountId/users
        // DELETE /api/v1/accounts/:accountId/users/:userId
        let ownerRoutes = protectedRoutes.grouped(AccountRoleMiddleware(), OwnerMiddleware())
        ownerRoutes.put("accounts", ":accountId") { [self] req in
            try await updateAccount(req)
        }
        ownerRoutes.get("accounts", ":accountId", "users") { [self] req in
            try await getAccountUsers(req)
        }
        ownerRoutes.post("accounts", ":accountId", "users") { [self] req in
            try await addUserToAccount(req)
        }
        ownerRoutes.delete("accounts", ":accountId", "users", ":userId") { [self] req in
            try await removeUserFromAccount(req)
        }
    }
    
    /// Get current user profile (any authenticated user)
    public func getProfile(_ req: Request) async throws -> UserProfileResponseDTO {
        guard let authenticatableUser = req.auth.get(AuthenticatableUser.self) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        
        guard let user = try await authenticatableUser.userForRequest(req) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        return UserProfileResponseDTO(
            id: try user.requireID(),
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            phone: user.phone,
            dateCreated: user.dateCreated,
            dateLastUpdated: user.dateLastUpdated
        )
    }
    
    /// Update current user profile (any authenticated user)
    public func updateProfile(_ req: Request) async throws -> UserProfileResponseDTO {
        let updateRequest = try req.content.decode(UpdateProfileRequestDTO.self)
        
        guard let authenticatableUser = req.auth.get(AuthenticatableUser.self) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        
        guard let user = try await authenticatableUser.userForRequest(req) else {
            throw Abort(.notFound, reason: "User not found")
        }
        
        // Update user fields
        user.firstName = updateRequest.firstName
        user.lastName = updateRequest.lastName
        user.phone = updateRequest.phone
        user.dateLastUpdated = Date()
        
        try await user.save(on: req.db)
        
        return UserProfileResponseDTO(
            id: try user.requireID(),
            email: user.email,
            firstName: user.firstName,
            lastName: user.lastName,
            phone: user.phone,
            dateCreated: user.dateCreated,
            dateLastUpdated: user.dateLastUpdated
        )
    }
    
    /// Get account details (any user with a role for the account)
    public func getAccount(_ req: Request) async throws -> AccountResponseDTO {
        guard let accountId = req.accountId else {
            throw Abort(.badRequest, reason: "Account ID not found")
        }
        
        guard let account = try await Account.find(accountId, on: req.db) else {
            throw Abort(.notFound, reason: "Account not found")
        }
        
        // Decrypt account data to get full information
        let accountData: AccountData = try await req.application.crypto.decryptToDecodable(account.data)
        
        return AccountResponseDTO(
            id: try account.requireID(),
            data: accountData,
            dateCreated: account.dateCreated,
            dateLastUpdated: account.dateLastUpdated
        )
    }
    
    /// Get full account details (owner and admin)
    public func getFullAccount(_ req: Request) async throws -> DetailedAccountResponse {
        guard let accountId = req.accountId else {
            throw Abort(.badRequest, reason: "Account ID not found")
        }
        
        // Use WMFNTK-Models AccountController for detailed account information
        let accountController = AccountController(crypto: req.application.crypto)
        return try await accountController.getDetailedAccount(req: req, accountId: accountId)
    }
    
    /// Update account details (owner only)
    public func updateAccount(_ req: Request) async throws -> AccountResponseDTO {
        let updateRequest = try req.content.decode(UpdateAccountRequestDTO.self)
        
        guard let accountId = req.accountId else {
            throw Abort(.badRequest, reason: "Account ID not found")
        }
        
        guard let account = try await Account.find(accountId, on: req.db) else {
            throw Abort(.notFound, reason: "Account not found")
        }
        
        // Create new account data
        let accountData = AccountData(
            title: updateRequest.title,
            description: updateRequest.description
        )
        
        // Encrypt outside transaction
        let encryptedData = try await req.application.crypto.encryptFromEncodable(accountData)
        
        // Update account
        account.data = encryptedData
        account.dateLastUpdated = Date()
        try await account.save(on: req.db)
        
        return AccountResponseDTO(
            id: try account.requireID(),
            data: accountData,
            dateCreated: account.dateCreated,
            dateLastUpdated: account.dateLastUpdated
        )
    }
    
    /// Get users for an account (owner only)
    public func getAccountUsers(_ req: Request) async throws -> AccountUsersListResponseDTO {
        guard let accountId = req.accountId else {
            throw Abort(.badRequest, reason: "Account ID not found")
        }
        
        // Get existing users with roles
        let roles = try await Role.query(on: req.db)
            .filter(FieldKey("account_id"), .equal, accountId)
            .with(\.$user)
            .all()
        
        let accountUsers = try roles.map { role in
            print("Role: \(role.user)")
            return AccountUserResponseDTO(
                userId: try role.user.requireID(),
                email: role.user.email,
                firstName: role.user.firstName,
                lastName: role.user.lastName,
                role: role.role,
                dateCreated: role.dateCreated
            )
        }
        
        // Get pending invitations (AgentUser records)
        let agentUsers = try await AgentUser.query(on: req.db)
            .filter(FieldKey("account_id"), .equal, accountId)
            .all()
        
        let pendingInvitations = agentUsers.map { agentUser in
            PendingAccountUserDTO(
                email: agentUser.email,
                role: agentUser.role,
                dateCreated: agentUser.dateCreated
            )
        }
        
        return AccountUsersListResponseDTO(users: accountUsers, pendingInvitations: pendingInvitations)
    }
    
    /// Add user to account (owner only)
    public func addUserToAccount(_ req: Request) async throws -> AccountUserResponseDTO {
        let addUserRequest = try req.content.decode(AddUserToAccountRequestDTO.self)
        
        guard let accountId = req.accountId else {
            throw Abort(.badRequest, reason: "Account ID not found")
        }
        
        // Fetch account and admin info for email
        guard let account = try await Account.find(accountId, on: req.db) else {
            throw Abort(.notFound, reason: "Account not found")
        }
        
        // Decrypt account data to get title
        let accountData: AccountData = try await req.application.crypto.decryptToDecodable(account.data)
        
        guard let authenticatableUser = req.auth.get(AuthenticatableUser.self),
              let adminUser = try await authenticatableUser.userForRequest(req) else {
            throw Abort(.unauthorized, reason: "Authentication required")
        }
        let adminName = [adminUser.firstName, adminUser.lastName].filter { !$0.isEmpty }.joined(separator: " ")
        
        // Check if user already has a role in this account
        if let existingUser = try await User.query(on: req.db)
            .filter(FieldKey("email"), .equal, addUserRequest.email)
            .first() {
            
            let existingRole = try await Role.query(on: req.db)
                .filter(FieldKey("user_id"), .equal, existingUser.id!)
                .filter(FieldKey("account_id"), .equal, accountId)
                .first()
            
            if existingRole != nil {
                throw Abort(.conflict, reason: "User is already a member of this account")
            }
        }
        
        // Check if there's already an AgentUser record for this email and account
        let existingAgentUser = try await AgentUser.query(on: req.db)
            .filter(FieldKey("email"), .equal, addUserRequest.email)
            .filter(FieldKey("account_id"), .equal, accountId)
            .first()
        
        if existingAgentUser != nil {
            throw Abort(.conflict, reason: "User has already been invited to this account")
        }
        
        // Try to find the user by email
        if let user = try await User.query(on: req.db)
            .filter(FieldKey("email"), .equal, addUserRequest.email)
            .first() {
            
            // User exists, create a Role record
            let role = Role(
                userId: try user.requireID(),
                accountId: accountId,
                role: addUserRequest.role
            )
            try await role.save(on: req.db)
            
            // Send notification email
            if let emailService = req.application.emailService {
                try await emailService.sendAddedToAccountEmail(
                    to: user.email,
                    accountTitle: accountData.title,
                    adminName: adminName
                )
            }
            
            return AccountUserResponseDTO(
                userId: try user.requireID(),
                email: user.email,
                firstName: user.firstName,
                lastName: user.lastName,
                role: role.role,
                dateCreated: role.dateCreated
            )
        } else {
            // User doesn't exist, create an AgentUser record as a placeholder
            let agentUser = AgentUser(
                accountId: accountId,
                email: addUserRequest.email,
                role: addUserRequest.role
            )
            try await agentUser.save(on: req.db)
            
            // Send invitation email
            if let emailService = req.application.emailService {
                try await emailService.sendAccountInvitationEmail(
                    to: addUserRequest.email,
                    accountTitle: accountData.title,
                    adminName: adminName
                )
            }
            
            // Return a response indicating this is a pending invitation
            return AccountUserResponseDTO(
                userId: UUID(), // Placeholder UUID since user doesn't exist yet
                email: addUserRequest.email,
                firstName: "", // Will be filled when user signs up
                lastName: "", // Will be filled when user signs up
                role: addUserRequest.role,
                dateCreated: agentUser.dateCreated
            )
        }
    }
    
    /// Remove user from account (owner only)
    public func removeUserFromAccount(_ req: Request) async throws -> HTTPStatus {
        guard let accountId = req.accountId else {
            throw Abort(.badRequest, reason: "Account ID not found")
        }
        
        guard let userIdParam = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdParam) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // Find and delete the role
        guard let role = try await Role.query(on: req.db)
            .filter(FieldKey("user_id"), .equal, userId)
            .filter(FieldKey("account_id"), .equal, accountId)
            .first()
        else {
            throw Abort(.notFound, reason: "User not found in account")
        }
        
        // Prevent removing admin users
        if role.role == 0 {
            throw Abort(.forbidden, reason: "Cannot remove admin users from account")
        }
        
        try await role.delete(on: req.db)
        
        return .noContent
    }
} 
