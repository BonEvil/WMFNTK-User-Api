import Vapor

/// Route helper utilities
public struct RouteHelpers {
    
    /// Create a protected route group with authentication middleware
    /// - Parameter app: The application instance
    /// - Returns: A route group with auth middleware applied
    public static func protectedRoutes(_ app: Application) -> any RoutesBuilder {
        return app.grouped("api", "v1")
            .grouped(AuthMiddleware())
    }
    
    /// Create a public route group (no authentication required)
    /// - Parameter app: The application instance
    /// - Returns: A route group without auth middleware
    public static func publicRoutes(_ app: Application) -> any RoutesBuilder {
        return app.grouped("api", "v1")
    }
} 