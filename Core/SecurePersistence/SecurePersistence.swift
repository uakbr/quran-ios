//
//  SecurePersistence.swift
//  QuranEngine
//
//  Created by Mohannad Hassan on 28/12/2024.
//

import Foundation
import SystemDependencies
import VLogging

/// Errors that can occur during secure persistence operations
public enum PersistenceError: Error {
    case persistenceFailed
    case retrievalFailed
    case tooManyConnections
    
    // MARK: Public

    public static func generalError(_ error: Error, info: String) -> PersistenceError {
        .general("error: \(error), info: \(info)")
    }
}

extension PersistenceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .persistenceFailed:
            return "Failed to persist data securely"
        case .retrievalFailed:
            return "Failed to retrieve stored data"
        case .tooManyConnections:
            return "Too many database connections. Please try again."
        }
    }
}

/// An abstraction for secure persistence of data.
///
/// This protocol provides a secure way to store sensitive data such as OAuth tokens,
/// user credentials, and other confidential information. The implementation should
/// ensure that data is encrypted at rest and protected from unauthorized access.
///
/// ## Security Considerations
/// - All data should be encrypted before storage
/// - Keys should be protected using the device's secure enclave when available
/// - Data should be automatically cleared when the app is uninstalled
/// - Biometric protection should be considered for highly sensitive data
///
/// ## Usage
/// ```swift
/// let persistence = KeychainPersistence()
/// try await persistence.set(data: tokenData, forKey: "oauth_token")
/// let retrievedData = try await persistence.getData(forKey: "oauth_token")
/// ```
///
/// ## Thread Safety
/// Implementations should be thread-safe and support concurrent access.
///
/// Currently, only supports `Data` as the data type of the saved objects.
public protocol SecurePersistence {
    
    /// Securely stores data for the specified key
    /// - Parameters:
    ///   - data: The data to store securely
    ///   - key: Unique identifier for the stored data
    /// - Throws: `PersistenceError.persistenceFailed` if storage fails
    func set(data: Data, forKey key: String) throws

    /// Retrieves securely stored data for the specified key
    /// - Parameter key: The key used to store the data
    /// - Returns: The stored data, or nil if no data exists for the key
    /// - Throws: `PersistenceError.retrievalFailed` if retrieval fails
    func getData(forKey key: String) throws -> Data?

    /// Removes securely stored data for the specified key
    /// - Parameter key: The key of the data to remove
    /// - Throws: `PersistenceError` if removal fails
    func clearData(forKey key: String) throws
}

/// Keychain-based implementation of SecurePersistence
///
/// This implementation uses the iOS Keychain Services to securely store data.
/// The Keychain provides hardware-backed encryption and automatic data protection.
///
/// ## Features
/// - Hardware-backed encryption on supported devices
/// - Automatic data protection and access control
/// - Data persists across app updates but is removed on app uninstall
/// - Thread-safe operations
///
/// ## Security Benefits
/// - Data is encrypted using device-specific keys
/// - Protected against other apps accessing the data
/// - Survives device restarts and app updates
/// - Can be configured to require device unlock or biometric authentication
public final class KeychainPersistence: SecurePersistence {
    // MARK: Lifecycle

    /// Creates a new KeychainPersistence instance
    /// - Parameter keychainAccess: The keychain access interface (defaults to system keychain)
    public init(keychainAccess: KeychainAccess = DefaultKeychainAccess()) {
        self.keychainAccess = keychainAccess
    }

    // MARK: Public

    /// Stores data securely in the keychain
    /// - Parameters:
    ///   - data: The data to store
    ///   - key: Unique identifier for the data
    /// - Throws: `PersistenceError.persistenceFailed` if keychain operation fails
    public func set(data: Data, forKey key: String) throws {
        let addquery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
        ]
        let status = keychainAccess.addItem(query: addquery)
        if status == errSecDuplicateItem {
            logger.info("[KeychainPersistence] Data already exists, updating")
            try update(dat: data, forKey: key)
        } else if status != errSecSuccess {
            logger.error("[KeychainPersistence] Failed to persist data -- \(status) status")
            throw PersistenceError.persistenceFailed
        }
        logger.info("[KeychainPersistence] Data persisted successfully")
    }

    /// Retrieves data from the keychain
    /// - Parameter key: The key of the data to retrieve
    /// - Returns: The stored data, or nil if not found
    /// - Throws: `PersistenceError.retrievalFailed` if keychain operation fails
    public func getData(forKey key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
        ]
        let status = keychainAccess.copyMatching(query: query)
        switch status {
        case .success(let data):
            logger.debug("[KeychainPersistence] Successfully retrieved data for key: \(key)")
            return data as? Data
        case .itemNotFound:
            logger.debug("[KeychainPersistence] No data found for key: \(key)")
            return nil
        case .failure(let error):
            logger.error("[KeychainPersistence] Failed to retrieve data for key: \(key), error: \(error)")
            throw PersistenceError.retrievalFailed
        }
    }

    /// Removes data from the keychain
    /// - Parameter key: The key of the data to remove
    /// - Throws: `PersistenceError` if keychain operation fails
    public func clearData(forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        let status = keychainAccess.deleteItem(query: query)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("[KeychainPersistence] Failed to clear data for key: \(key), status: \(status)")
            throw PersistenceError.persistenceFailed
        }
        logger.debug("[KeychainPersistence] Data cleared for key: \(key)")
    }

    // MARK: Private

    private let keychainAccess: KeychainAccess
    private let logger = Logger(label: "SecurePersistence")

    /// Updates existing keychain item with new data
    /// - Parameters:
    ///   - data: New data to store
    ///   - key: Key of the existing item
    /// - Throws: `PersistenceError.persistenceFailed` if update fails
    private func update(dat data: Data, forKey key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
        ]
        let status = keychainAccess.updateItem(query: query, attributesToUpdate: update)
        if status != errSecSuccess {
            logger.error("[KeychainPersistence] Failed to update data for key: \(key), status: \(status)")
            throw PersistenceError.persistenceFailed
        }
        logger.debug("[KeychainPersistence] Successfully updated data for key: \(key)")
    }
}
