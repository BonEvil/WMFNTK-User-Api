import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import WMFNTKModels

// configures your application
public func configure(_ app: Application) async throws {
    
#if DEBUG
    app.logger.logLevel = .debug
    let allowedOrigins: CORSMiddleware.AllowOriginSetting = .all
#else
    app.logger.logLevel = .error
    let allowedOrigins: CORSMiddleware.AllowOriginSetting = .any(["*","https://app.whatmyfamilyneedstoknow.com"]) // Remove "*" when final deployment
#endif

    // Load application config
    app.config = AppConfig.load()

    // Configure CORS
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: allowedOrigins,
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
    
#if DEBUG
    let tlsConfig: PostgresConnection.Configuration.TLS = .disable
#else
    let tlsConfig: PostgresConnection.Configuration.TLS = .prefer(try .init(configuration: makeTlsConfiguration()))
#endif

    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.databaseHost,
        port: Environment.databasePort,
        username: Environment.databaseUsername,
        password: Environment.databasePassword,
        database: Environment.databaseName,
        tls: tlsConfig)
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

fileprivate func makeTlsConfiguration() throws -> TLSConfiguration {
    var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
    let certPath = "./us-east-1-bundle.pem"
    tlsConfiguration.trustRoots = NIOSSLTrustRoots.certificates(
        try NIOSSLCertificate.fromPEMFile(certPath)
    )
    return tlsConfiguration
}
