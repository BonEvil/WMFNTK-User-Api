import Vapor
import AWSSES

public actor AWSEmailService {
    private let region: String
    private let defaultFromEmail: String
    
    public init(region: String, defaultFromEmail: String) throws {
        self.region = region
        self.defaultFromEmail = defaultFromEmail
    }
    
    nonisolated private func sendEmail(region: String, input: SendEmailInput) async throws {
        let client = try SESClient(region: region)
        do {
            let result = try await client.sendEmail(input: input)
            print("EMAIL RESULT: \(result)")
        } catch {
            print("EMAIL ERROR: \(error)")
            throw error
        }
    }
    
    public func sendLoginCodeEmail(to email: String, code: Int) async throws {
        let htmlBody = """
        <html>
        <body>
            <h2>Login Code</h2>
            <p>Your login code is: <strong>\(code)</strong></p>
            <p>This code will expire in 10 minutes.</p>
            <p>If you did not request this code, please ignore this email.</p>
        </body>
        </html>
        """
        
        let input = SendEmailInput(
            destination: .init(
                toAddresses: [email]
            ),
            message: .init(
                body: .init(
                    html: .init(data: htmlBody)
                ),
                subject: .init(data: "Login Code")
            ),
            source: defaultFromEmail
        )
        
        try await sendEmail(region: region, input: input)
    }
    
    public func sendSignupCodeEmail(to email: String, code: Int) async throws {
        let htmlBody = """
        <html>
        <body>
            <h2>Signup Verification Code</h2>
            <p>Your signup verification code is: <strong>\(code)</strong></p>
            <p>This code will expire in 10 minutes.</p>
            <p>If you did not request this code, please ignore this email.</p>
        </body>
        </html>
        """
        
        let input = SendEmailInput(
            destination: .init(
                toAddresses: [email]
            ),
            message: .init(
                body: .init(
                    html: .init(data: htmlBody)
                ),
                subject: .init(data: "Signup Verification Code")
            ),
            source: defaultFromEmail
        )
        
        try await sendEmail(region: region, input: input)
    }

    public func sendAddedToAccountEmail(to email: String, accountTitle: String, adminName: String) async throws {
        let htmlBody = """
        <html>
        <body>
            <h2>You've been added to an account</h2>
            <p>Hello,</p>
            <p>You have been added to the account <strong>\(accountTitle)</strong> by <strong>\(adminName)</strong>.</p>
            <p>You can now access this account after logging in.</p>
        </body>
        </html>
        """
        let input = SendEmailInput(
            destination: .init(
                toAddresses: [email]
            ),
            message: .init(
                body: .init(
                    html: .init(data: htmlBody)
                ),
                subject: .init(data: "You've been added to an account")
            ),
            source: defaultFromEmail
        )
        try await sendEmail(region: region, input: input)
    }

    public func sendAccountInvitationEmail(to email: String, accountTitle: String, adminName: String) async throws {
        let htmlBody = """
        <html>
        <body>
            <h2>You're invited to join an account</h2>
            <p>Hello,</p>
            <p>You have been invited to join the account <strong>\(accountTitle)</strong> by <strong>\(adminName)</strong>.</p>
            <p>To accept this invitation, please create an account using this email address.</p>
        </body>
        </html>
        """
        let input = SendEmailInput(
            destination: .init(
                toAddresses: [email]
            ),
            message: .init(
                body: .init(
                    html: .init(data: htmlBody)
                ),
                subject: .init(data: "You're invited to join an account")
            ),
            source: defaultFromEmail
        )
        try await sendEmail(region: region, input: input)
    }
} 