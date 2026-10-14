//
// SecretStore.swift
//
// Protocol for secure storage of sensitive data.
//

import Foundation

/// Protocol for secure storage of sensitive data
public protocol SecretStore {
    /// Store a secret value
    /// - Parameters:
    ///   - secret: The secret value to store
    ///   - key: The key to associate with the secret
    /// - Throws: Error if the operation fails
    func set(_ secret: String, for key: String) throws
    
    /// Retrieve a secret value
    /// - Parameter key: The key to retrieve
    /// - Returns: The secret value, or nil if not found
    /// - Throws: Error if the operation fails
    func get(_ key: String) throws -> String?
    
    /// Remove a secret value
    /// - Parameter key: The key to remove
    /// - Throws: Error if the operation fails
    func remove(_ key: String) throws
}
