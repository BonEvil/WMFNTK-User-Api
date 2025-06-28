import Vapor
import WMFNTKModels

struct AppConfig {
    let awsRegion: String
    let defaultFromEmail: String
    
    static func load() -> AppConfig {
        AppConfig(
            awsRegion: Environment.awsDefaultRegion,
            defaultFromEmail: Environment.defaultFromEmail
        )
    }
}

// Extension to store config in application
extension Application {
    private struct ConfigKey: StorageKey {
        typealias Value = AppConfig
    }
    
    var config: AppConfig {
        get {
            guard let config = storage[ConfigKey.self] else {
                fatalError("Config not configured. Use app.config = ...")
            }
            return config
        }
        set {
            storage[ConfigKey.self] = newValue
        }
    }
}

// Extension to store email service in application
extension Application {
    private struct EmailServiceKey: StorageKey {
        typealias Value = AWSEmailService
    }
    
    var emailService: AWSEmailService? {
        get { storage[EmailServiceKey.self] }
        set { storage[EmailServiceKey.self] = newValue }
    }
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
