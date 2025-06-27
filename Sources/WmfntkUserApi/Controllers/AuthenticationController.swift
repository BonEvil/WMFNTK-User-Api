import Foundation
import Vapor
import Fluent
import WMFNTKModels
import Crypto
import JWT

/// Controller for handling user authentication
public actor AuthenticationController {
    private let emailService: AWSEmailService
    
    public init(emailService: AWSEmailService) {
        self.emailService = emailService
    }
    
    nonisolated func routes(_ app: Application) throws {
        let routes = app.grouped("api", "v1")
        routes.post("auth", "login") { [self] req in
            try await login(req)
        }
        routes.post("auth", "verify") { [self] req in
            try await verify(req)
        }
        routes.post("auth", "signup", "email") { [self] req in
            try await signupEmail(req)
        }
        routes.post("auth", "signup", "verify") { [self] req in
            try await signupVerify(req)
        }
        routes.post("auth", "signup", "account") { [self] req in
            try await signupAccount(req)
        }
        // Add protected or additional routes here as needed
        // Example: routes.post("auth", "create-first-admin") { [self] req in try await createFirstAdmin(req) }
    }
    
    /// User login endpoint (password verification + code generation)
    public func login(_ req: Request) async throws -> HTTPStatus {
        let loginRequest = try req.content.decode(LoginRequestDTO.self)
        
        // Find user by email
        guard let user = try await User.query(on: req.db)
            .filter(FieldKey("email"), .equal, loginRequest.email)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Verify password
        guard try Bcrypt.verify(loginRequest.password, created: user.passwordHash) else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Generate and save new login code directly on the user
        let code = generateLoginCode()
        user.code = code
        user.codeExpiresAt = Date().addingTimeInterval(600) // 10 minutes
        
        try await user.save(on: req.db)
        
        // Send login code email
        try await emailService.sendLoginCodeEmail(to: user.email, code: code)
        
        return .ok
    }
    
    /// Code verification endpoint
    public func verify(_ req: Request) async throws -> Response {
        let verifyRequest = try req.content.decode(VerifyRequestDTO.self)
        
        // Find user by email
        guard let user = try await User.query(on: req.db)
            .filter(FieldKey("email"), .equal, verifyRequest.email)
            .first()
        else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Verify code
        guard let storedCode = user.code,
              storedCode == verifyRequest.code else {
            throw Abort(.unauthorized, reason: "Invalid code")
        }
        
        // Check if code is expired
        if let codeExpiresAt = user.codeExpiresAt,
           Date() > codeExpiresAt {
            // Clear the expired code
            user.code = nil
            user.codeExpiresAt = nil
            try await user.save(on: req.db)
            throw Abort(.unauthorized, reason: "Code expired")
        }
        
        // Clear the used code
        user.code = nil
        user.codeExpiresAt = nil
        
        // Update last updated date (closest to last login)
        user.dateLastUpdated = Date()
        try await user.save(on: req.db)
        
        // Generate JWT token
        let token = try await generateToken(for: user, on: req)
        
        // Store session token
        user.sessionToken = token
        user.sessionTokenExpiresAt = Date().addingTimeInterval(600) // 10 minutes
        try await user.save(on: req.db)
        
        // Create response with token in header
        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: "x-new-token", value: token)
        
        return response
    }
    
    /// Signup email endpoint (email validation + code generation)
    public func signupEmail(_ req: Request) async throws -> HTTPStatus {
        let signupRequest = try req.content.decode(SignupEmailRequestDTO.self)
        
        // Check if user already exists
        if let existingUser = try await User.query(on: req.db)
            .filter(FieldKey("email"), .equal, signupRequest.email)
            .first() {
            
            // Check if this is a signup user (no name or password set)
            if existingUser.firstName.isEmpty && existingUser.lastName.isEmpty && existingUser.passwordHash.isEmpty {
                // This is a signup user, generate and send new code
                let code = generateLoginCode()
                existingUser.code = code
                existingUser.codeExpiresAt = Date().addingTimeInterval(600) // 10 minutes
                
                try await existingUser.save(on: req.db)
                
                // Send signup verification email
                try await emailService.sendSignupCodeEmail(to: existingUser.email, code: code)
                
                return .ok
            } else {
                // This is a real user, fail signup
                throw Abort(.conflict, reason: "User with this email already exists")
            }
        }
        
        // Create a temporary user for signup process
        let tempUser = User()
        tempUser.email = signupRequest.email
        tempUser.firstName = "" // Will be set during account creation
        tempUser.lastName = "" // Will be set during account creation
        tempUser.passwordHash = "" // Will be set during account creation
        
        // Generate and save signup code
        let code = generateLoginCode()
        tempUser.code = code
        tempUser.codeExpiresAt = Date().addingTimeInterval(600) // 10 minutes
        
        try await tempUser.save(on: req.db)
        
        // Send signup verification email
        try await emailService.sendSignupCodeEmail(to: tempUser.email, code: code)
        
        return .ok
    }
    
    /// Signup email verification endpoint
    public func signupVerify(_ req: Request) async throws -> Response {
        let verifyRequest = try req.content.decode(SignupEmailVerifyDTO.self)
        
        // Find temporary user by email
        guard let tempUser = try await User.query(on: req.db)
            .filter(FieldKey("email"), .equal, verifyRequest.email)
            .first()
        else {
            throw Abort(.notFound, reason: "Signup request not found")
        }
        
        // Check if this is a signup user (no name or password set)
        guard tempUser.firstName.isEmpty && tempUser.lastName.isEmpty && tempUser.passwordHash.isEmpty else {
            throw Abort(.conflict, reason: "User with this email already exists")
        }
        
        // Verify code
        guard let storedCode = tempUser.code,
              storedCode == verifyRequest.code else {
            throw Abort(.unauthorized, reason: "Invalid code")
        }
        
        // Check if code is expired
        if let codeExpiresAt = tempUser.codeExpiresAt,
           Date() > codeExpiresAt {
            // Clear the expired code
            tempUser.code = nil
            tempUser.codeExpiresAt = nil
            try await tempUser.save(on: req.db)
            throw Abort(.unauthorized, reason: "Code expired")
        }
        
        // Clear the used code
        tempUser.code = nil
        tempUser.codeExpiresAt = nil
        try await tempUser.save(on: req.db)
        
        // Generate signup token
        let signupToken = try await generateSignupToken(for: tempUser, on: req)
        
        // Create response with signup token in header
        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: "x-signup-token", value: signupToken)
        
        return response
    }
    
    /// Signup account creation endpoint
    public func signupAccount(_ req: Request) async throws -> Response {
        let accountRequest = try req.content.decode(SignupAccountRequestDTO.self)
        
        // Verify signup token from header
        guard let signupToken = req.headers.first(name: "x-signup-token") else {
            throw Abort(.unauthorized, reason: "Missing signup token")
        }
        
        // Verify and decode the signup token
        let payload = try await req.jwt.verify(signupToken, as: SignupTokenJWTPayload.self)
        
        // Find the temporary user
        guard let tempUser = try await User.query(on: req.db)
            .filter(FieldKey("email"), .equal, payload.email)
            .first()
        else {
            throw Abort(.notFound, reason: "Signup request not found")
        }
        
        // Create and encrypt account data BEFORE transaction
        let accountData = AccountData(
            title: accountRequest.accountTitle,
            description: accountRequest.accountDescription
        )
        
        // Encrypt account data outside transaction
        let encryptedData = try await req.application.crypto.encryptFromEncodable(accountData)
        
        // Use database transaction for account creation (with pre-encrypted data)
        let signupResponse = try await req.db.transaction { db in
            // Create account with pre-encrypted data
            let account = Account(data: encryptedData)
            try await account.save(on: db)
            
            // Update user with final details
            tempUser.firstName = accountRequest.userFirstName
            tempUser.lastName = accountRequest.userLastName
            tempUser.phone = accountRequest.userPhoneNumber
            tempUser.passwordHash = try Bcrypt.hash(accountRequest.userPassword)
            tempUser.dateLastUpdated = Date()
            try await tempUser.save(on: db)
            
            // Create owner role (role = 0) for their own account
            let ownerRole = Role(
                userId: try tempUser.requireID(),
                accountId: try account.requireID(),
                role: 0 // Owner role
            )
            try await ownerRole.save(on: db)
            
            // Check for AgentUser records and convert them to Role records
            let agentUsers = try await AgentUser.query(on: db)
                .filter(FieldKey("email"), .equal, tempUser.email)
                .all()
            
            for agentUser in agentUsers {
                // Create Role record for each account the user was invited to
                let role = Role(
                    userId: try tempUser.requireID(),
                    accountId: agentUser.$account.id,
                    role: agentUser.role
                )
                try await role.save(on: db)
                
                // Delete the AgentUser record since it's now converted
                try await agentUser.delete(on: db)
            }
            
            return SignupResponseDTO(
                accountId: try account.requireID(),
                userId: try tempUser.requireID(),
                email: tempUser.email,
                firstName: tempUser.firstName,
                lastName: tempUser.lastName
            )
        }
        
        // Generate authentication token for the newly created user
        let authToken = try await generateToken(for: tempUser, on: req)
        
        // Store session token on the user
        tempUser.sessionToken = authToken
        tempUser.sessionTokenExpiresAt = Date().addingTimeInterval(600) // 10 minutes
        try await tempUser.save(on: req.db)
        
        // Create response with token in header and signup data in body
        let response = Response(status: .ok)
        response.headers.replaceOrAdd(name: "x-new-token", value: authToken)
        
        // Encode the signup response data
        try response.content.encode(signupResponse)
        
        return response
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
    
    /// Generate signup JWT token
    private func generateSignupToken(for user: User, on req: Request) async throws -> String {
        let payload = SignupTokenJWTPayload(
            subject: SubjectClaim(value: try user.requireID().uuidString),
            email: user.email,
            expiration: ExpirationClaim(value: Date().addingTimeInterval(1800)), // 30 minutes
            issuer: IssuerClaim(value: "WMFNTK-User-API"),
            issuedAt: IssuedAtClaim(value: Date())
        )
        
        return try await req.jwt.sign(payload)
    }
    
    /// Generate a 6-digit login code
    private func generateLoginCode() -> Int {
        Int.random(in: 100000...999999)
    }
}

/// JWT payload for user tokens
public struct UserTokenPayload: JWTPayload {
    public var subject: SubjectClaim
    public var expiration: ExpirationClaim
    public var issuer: IssuerClaim
    public var issuedAt: IssuedAtClaim
    
    public func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
}

/// JWT payload for signup tokens
public struct SignupTokenJWTPayload: JWTPayload {
    public var subject: SubjectClaim
    public var email: String
    public var expiration: ExpirationClaim
    public var issuer: IssuerClaim
    public var issuedAt: IssuedAtClaim
    
    public func verify(using algorithm: some JWTAlgorithm) async throws {
        try expiration.verifyNotExpired()
    }
} 