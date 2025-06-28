// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WmfntkUserApi",
    platforms: [
       .macOS(.v13)
    ],
    dependencies: [
        // 💧 A server-side Swift web framework.
        .package(url: "https://github.com/vapor/vapor.git", from: "4.115.0"),
        // 🗄 An ORM for SQL and NoSQL databases.
        .package(url: "https://github.com/vapor/fluent.git", from: "4.9.0"),
        // 🐘 Fluent driver for Postgres.
        .package(url: "https://github.com/vapor/fluent-postgres-driver.git", from: "2.8.0"),
        // 🔵 Non-blocking, event-driven networking for Swift. Used for custom executors
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
        // 🔐 JWT for authentication
        .package(url: "https://github.com/vapor/jwt.git", from: "5.1.0"),
        // AWS
        .package(url: "https://github.com/awslabs/aws-sdk-swift", from: "1.0.56"),
        // WMFNTK Models
        .package(path: "../WMFNTK-Models")
    ],
    targets: [
        .executableTarget(
            name: "WmfntkUserApi",
            dependencies: [
                .product(name: "Fluent", package: "fluent"),
                .product(name: "FluentPostgresDriver", package: "fluent-postgres-driver"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "JWT", package: "jwt"),
                .product(name: "AWSSES", package: "aws-sdk-swift"),
                .product(name: "WMFNTKModels", package: "WMFNTK-Models")
            ],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "WmfntkUserApiTests",
            dependencies: [
                .target(name: "WmfntkUserApi"),
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftSettings
        )
    ]
)

var swiftSettings: [SwiftSetting] { [
    .enableUpcomingFeature("ExistentialAny"),
] }
