import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import WMFNTKModels

// configures your application
public func configure(_ app: Application) async throws {
    
    app.logger.logLevel = .debug

    // Load application config
    app.config = AppConfig.load()

    // Configure CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .DELETE, .OPTIONS],
        allowedHeaders: [
            .accept,
            .authorization,
            .contentType,
            .origin,
            .xRequestedWith,
            .userAgent,
            .accessControlRequestMethod,
            .accessControlRequestHeaders,
            "x-new-token",
            "x-signup-token"
        ]
    )
    app.middleware.use(CORSMiddleware(configuration: corsConfiguration))

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.databaseHost,
        port: Environment.databasePort,
        username: Environment.databaseUsername,
        password: Environment.databasePassword,
        database: Environment.databaseName,
        tls: .disable)
    ), as: .psql)

    // Configure JWT
    let jwtKey = Environment.jwtSecret
    await app.jwt.keys.add(hmac: .init(from: jwtKey), digestAlgorithm: .sha256)

    // Configure encryption
    if let encryptionController = EncryptionController.shared() {
        try await encryptionController.initializeClient(
            region: Environment.awsDefaultRegion,
            keyId: Environment.encryptionKeyId.isEmpty ? nil : Environment.encryptionKeyId
        )
        app.crypto = await encryptionController.wrapper
    }

    // register routes
    try routes(app)
}

// Extension to store crypto in application
extension Application {
    private struct CryptoKey: StorageKey {
        typealias Value = any DataCrypto
    }
    
    var crypto: any DataCrypto {
        get {
            guard let crypto = storage[CryptoKey.self] else {
                fatalError("Crypto not configured. Use app.crypto = ...")
            }
            return crypto
        }
        set {
            storage[CryptoKey.self] = newValue
        }
    }
}
