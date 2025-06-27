import Fluent
import Vapor

func routes(_ app: Application) throws {
    // Register authentication routes
    let emailService = try AWSEmailService(
        region: app.config.awsRegion,
        defaultFromEmail: app.config.defaultFromEmail
    )
    app.emailService = emailService
    let authController = AuthenticationController(emailService: emailService)
    try authController.routes(app)
    
    // Register authorization routes
    let authorizationController = AuthorizationController()
    try authorizationController.routes(app)
    
    // Health check route
    app.get("health") { req async in
        return Response(status: .ok)
    }
}
