//
// FakeSecretStore.swift
//
// In-memory secret store for testing.
//

import Foundation
@testable import VictronKit

/// In-memory secret store for testing
public final class FakeSecretStore: SecretStore {
    /// Storage for secrets
    private var secrets: [String: String] = [:]
    
    /// Store a secret value
    /// - Parameters:
    ///   - secret: The secret value to store
    ///   - key: The key to associate with the secret
    /// - Throws: Never
    public func set(_ secret: String, for key: String) throws {
        secrets[key] = secret
    }
    
    /// Retrieve a secret value
    /// - Parameter key: The key to retrieve
    /// - Returns: The secret value, or nil if not found
    /// - Throws: Never
    public func get(_ key: String) throws -> String? {
        return secrets[key]
    }
    
    /// Remove a secret value
    /// - Parameter key: The key to remove
    /// - Throws: Never
    public func remove(_ key: String) throws {
        secrets.removeValue(forKey: key)
    }
    
    /// Clear all secrets
    public func clear() {
        secrets.removeAll()
    }
}
