//
// ConnectionProfile.swift
//
// Model for storing Cerbo connection profiles.
//

import Foundation

/// Represents a saved Cerbo connection profile
public struct ConnectionProfile: Codable, Equatable {
    /// Unique identifier for the profile
    public let id: UUID
    
    /// User-friendly name for the profile
    public var name: String
    
    /// Host address (IP or hostname)
    public var host: String
    
    /// MQTT port
    public var port: Int
    
    /// Whether to use TLS
    public var useTLS: Bool
    
    /// MQTT username (optional)
    public var username: String?
    
    /// Keychain reference for the password (never stored in plain text)
    public var passwordKeychainReference: String?
    
    /// Portal ID detected from the Cerbo (optional)
    public var portalId: String?
    
    /// Date when the profile was last used
    public var lastUsed: Date?
    
    /// Date when the profile was created
    public var createdAt: Date
    
    /// Date when the profile was last updated
    public var updatedAt: Date
    
    /// Initialize a new connection profile
    /// - Parameters:
    ///   - name: User-friendly name
    ///   - host: Host address
    ///   - port: MQTT port
    ///   - useTLS: Whether to use TLS
    ///   - username: MQTT username (optional)
    public init(name: String, host: String, port: Int, useTLS: Bool, username: String? = nil) {
        self.id = UUID()
        self.name = name
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.username = username
        self.passwordKeychainReference = nil
        self.portalId = nil
        self.lastUsed = nil
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    /// Initialize from a profile without password (for loading from storage)
    /// - Parameters:
    ///   - id: Profile ID
    ///   - name: User-friendly name
    ///   - host: Host address
    ///   - port: MQTT port
    ///   - useTLS: Whether to use TLS
    ///   - username: MQTT username (optional)
    ///   - passwordKeychainReference: Keychain reference for password
    ///   - portalId: Detected portal ID (optional)
    ///   - lastUsed: Last used date (optional)
    ///   - createdAt: Creation date
    ///   - updatedAt: Last update date
    public init(id: UUID, name: String, host: String, port: Int, useTLS: Bool, username: String?, passwordKeychainReference: String?, portalId: String?, lastUsed: Date?, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.username = username
        self.passwordKeychainReference = passwordKeychainReference
        self.portalId = portalId
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Update the profile's metadata
    /// - Parameter now: Function to get current date (defaults to Date.init)
    public mutating func updateMetadata(now: () -> Date = Date.init) {
        self.updatedAt = now()
    }
    
    /// Mark the profile as last used
    /// - Parameter now: Function to get current date (defaults to Date.init)
    public mutating func markAsLastUsed(now: () -> Date = Date.init) {
        self.lastUsed = now()
        self.updateMetadata(now: now)
    }
    
    /// Update the portal ID
    /// - Parameter portalId: The portal ID to update
    /// - Parameter now: Function to get current date (defaults to Date.init)
    public mutating func updatePortalId(_ portalId: String, now: () -> Date = Date.init) {
        self.portalId = portalId
        self.updateMetadata(now: now)
    }
}
