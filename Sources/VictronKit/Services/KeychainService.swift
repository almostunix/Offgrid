//
// KeychainService.swift
//
// Secure storage for sensitive data using iOS Keychain.
//

import Foundation
import Security

/// Service for securely storing and retrieving sensitive data from the Keychain
public final class KeychainService: SecretStore {
    /// Service identifier for the app
    private let service: String
    
    /// Initialize the Keychain service
    /// - Parameter service: Service identifier (default: "com.almostunix.cerbo-app")
    public init(service: String = "com.almostunix.cerbo-app") {
        self.service = service
    }
    
    /// Store a secret value
    /// - Parameters:
    ///   - secret: The secret value to store
    ///   - key: The key to associate with the secret
    /// - Throws: KeychainError if the operation fails
    public func set(_ secret: String, for key: String) throws {
        let secretData = secret.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: secretData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        
        // Delete any existing item with this key
        SecItemDelete(query as CFDictionary)
        
        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
    }
    
    /// Retrieve a secret value
    /// - Parameter key: The key to retrieve
    /// - Returns: The secret value, or nil if not found
    /// - Throws: KeychainError if the operation fails
    public func get(_ key: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            return nil
        }
        
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
        
        guard let data = item as? Data else {
            throw KeychainError.invalidData
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Remove a secret value
    /// - Parameter key: The key to remove
    /// - Throws: KeychainError if the operation fails
    public func remove(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.status(status)
        }
    }
    
    /// Updates a secret value in the Keychain
    /// - Parameters:
    ///   - newSecret: The new secret value
    ///   - key: The key used to store the secret
    /// - Throws: KeychainError if the operation fails
    public func update(_ newSecret: String, for key: String) throws {
        let secretData = newSecret.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: secretData
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        
        guard status == errSecSuccess else {
            throw KeychainError.status(status)
        }
    }
}

/// Errors that can occur when interacting with the Keychain
public enum KeychainError: Error {
    /// Keychain returned an error status
    case status(OSStatus)
    
    /// Retrieved data was invalid
    case invalidData
    
    /// Description of the error
    public var localizedDescription: String {
        switch self {
        case .status(let status):
            return "Keychain error: OSStatus = \(status)"
        case .invalidData:
            return "Invalid data retrieved from Keychain"
        }
    }
}
