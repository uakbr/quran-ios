//
//  SecurePersistence.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 28/12/2024.
//

@preconcurrency import SystemDependencies
import Foundation
import VLogging

/// Errors that can occur during secure persistence operations
public enum SecurePersistenceError: Error {
    case persistenceFailed
    case retrievalFailed
    case keyNotFound
    case invalidData
    
    // MARK: Public

    public static func generalError(_ error: Error, info: String) -> SecurePersistenceError {
        logger.error("SecurePersistence error: \(error), info: \(info)")
        return .persistenceFailed
    }
}

extension SecurePersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .persistenceFailed:
            return "Failed to persist data securely"
        case .retrievalFailed:
            return "Failed to retrieve secure data"
        case .keyNotFound:
            return "Secure key not found"
        case .invalidData:
            return "Invalid secure data format"
        }
    }
}

/// A protocol for secure data persistence using keychain services
///
/// SecurePersistence provides a secure storage mechanism for sensitive data using the system keychain.
/// All operations are performed securely with proper error handling and thread safety.
///
/// ## Usage
/// ```swift
/// let persistence = KeychainPersistence()
/// 
/// // Store secure data
/// try await persistence.store("sensitive_data", forKey: "user_token")
/// 
/// // Retrieve secure data
/// let token = try await persistence.retrieve(forKey: "user_token")
/// 
/// // Remove secure data
/// try await persistence.remove(forKey: "user_token")
/// ```
public protocol SecurePersistence: Sendable {
    /// Stores data securely in the keychain
    /// - Parameters:
    ///   - data: The data to store securely
    ///   - key: The key to associate with the data
    /// - Throws: SecurePersistenceError if storage fails
    func store(_ data: String, forKey key: String) async throws
    
    /// Retrieves data securely from the keychain
    /// - Parameter key: The key for the data to retrieve
    /// - Returns: The retrieved data, or nil if not found
    /// - Throws: SecurePersistenceError if retrieval fails
    func retrieve(forKey key: String) async throws -> String?
    
    /// Removes data securely from the keychain
    /// - Parameter key: The key for the data to remove
    /// - Throws: SecurePersistenceError if removal fails
    func remove(forKey key: String) async throws
    
    /// Checks if data exists for the given key
    /// - Parameter key: The key to check
    /// - Returns: true if data exists, false otherwise
    func exists(forKey key: String) async throws -> Bool
}

/// A keychain-based implementation of SecurePersistence
///
/// KeychainPersistence provides secure storage using the iOS/macOS keychain services.
/// All data is encrypted and protected by the system's security mechanisms.
public struct KeychainPersistence: SecurePersistence {
    // MARK: Lifecycle

    public init(keychain: any KeychainAccess = SystemDependencies.keychainAccess) {
        self.keychain = keychain
    }

    // MARK: Public

    public func store(_ data: String, forKey key: String) async throws {
        let dataToStore = Data(data.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: dataToStore,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Try to update first
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let updateAttributes: [String: Any] = [
            kSecValueData as String: dataToStore
        ]
        
        let updateStatus = keychain.updateItem(query: updateQuery, attributes: updateAttributes)
        
        if updateStatus == errSecItemNotFound {
            // Item doesn't exist, add it
            let addStatus = keychain.addItem(query: query)
            guard addStatus == errSecSuccess else {
                logger.error("Failed to add keychain item: \(addStatus)")
                throw SecurePersistenceError.persistenceFailed
            }
        } else if updateStatus != errSecSuccess {
            logger.error("Failed to update keychain item: \(updateStatus)")
            throw SecurePersistenceError.persistenceFailed
        }
    }
    
    public func retrieve(forKey key: String) async throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = keychain.copyItem(query: query, result: &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess else {
            logger.error("Failed to retrieve keychain item: \(status)")
            throw SecurePersistenceError.retrievalFailed
        }
        
        guard let data = result as? Data else {
            throw SecurePersistenceError.invalidData
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    public func remove(forKey key: String) async throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = keychain.deleteItem(query: query)
        
        if status == errSecItemNotFound {
            // Item already doesn't exist, consider it success
            return
        }
        
        guard status == errSecSuccess else {
            logger.error("Failed to delete keychain item: \(status)")
            throw SecurePersistenceError.persistenceFailed
        }
    }
    
    public func exists(forKey key: String) async throws -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: CFTypeRef?
        let status = keychain.copyItem(query: query, result: &result)
        
        if status == errSecItemNotFound {
            return false
        }
        
        guard status == errSecSuccess else {
            logger.error("Failed to check keychain item existence: \(status)")
            throw SecurePersistenceError.retrievalFailed
        }
        
        return true
    }

    // MARK: Private

    private let keychain: any KeychainAccess
}

private let logger = Logger(subsystem: "SecurePersistence", category: "KeychainPersistence")
