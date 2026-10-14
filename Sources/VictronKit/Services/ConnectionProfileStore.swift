//
// ConnectionProfileStore.swift
//
// Stores and manages Cerbo connection profiles with secure credential storage.
//

import Foundation

/// Protocol for connection profile storage
public protocol ConnectionProfileStoring {
    /// Save a connection profile
    /// - Parameters:
    ///   - profile: The profile to save
    ///   - password: Optional password to store securely
    /// - Throws: ProfileError if the operation fails
    func save(_ profile: ConnectionProfile, password: String?) throws
    
    /// Load a connection profile by ID
    /// - Parameter id: The profile ID
    /// - Returns: The loaded profile, or nil if not found
    /// - Throws: ProfileError if the operation fails
    func loadProfile(id: UUID) throws -> ConnectionProfile?
    
    /// Load all connection profiles
    /// - Returns: Array of all profiles
    /// - Throws: ProfileError if the operation fails
    func loadAllProfiles() throws -> [ConnectionProfile]
    
    /// Update an existing connection profile
    /// - Parameters:
    ///   - profile: The profile to update
    ///   - password: Optional new password to store securely (nil keeps existing password)
    /// - Throws: ProfileError if the operation fails
    func updateProfile(_ profile: ConnectionProfile, password: String?) throws
    
    /// Delete a connection profile
    /// - Parameter id: The profile ID to delete
    /// - Throws: ProfileError if the operation fails
    func deleteProfile(id: UUID) throws
    
    /// Delete all connection profiles
    /// - Throws: ProfileError if the operation fails
    func deleteAllProfiles() throws
    
    /// Get the most recently used profile
    /// - Returns: The most recently used profile, or nil if none
    /// - Throws: ProfileError if the operation fails
    func getMostRecentlyUsedProfile() throws -> ConnectionProfile?
    
    /// Get password for a profile
    /// - Parameter profile: The profile
    /// - Returns: The password, or nil if not found
    /// - Throws: ProfileError if the operation fails
    func password(for profile: ConnectionProfile) throws -> String?
}

/// Errors that can occur when managing connection profiles
public enum ProfileError: Error {
    /// Profile not found
    case notFound
    
    /// Invalid profile data
    case invalidData
    
    /// Profile with the same name already exists
    case duplicateName
    
    /// Storage error
    case storageError(Error)
    
    /// Description of the error
    public var localizedDescription: String {
        switch self {
        case .notFound:
            return "Profile not found"
        case .invalidData:
            return "Invalid profile data"
        case .duplicateName:
            return "A profile with this name already exists"
        case .storageError(let error):
            return "Storage error: \(error.localizedDescription)"
        }
    }
}

/// Default implementation of ConnectionProfileStoring
public final class ConnectionProfileStore: ConnectionProfileStoring {
    /// Secret store for secure password storage
    private let secretStore: SecretStore
    
    /// File manager for profile storage
    private let fileManager: FileManager
    
    /// Directory where profiles are stored
    private let profilesDirectory: URL
    
    /// Function to get current date/time
    private let now: () -> Date
    
    /// Initialize the connection profile store
    /// - Parameters:
    ///   - secretStore: Secret store for secure password storage
    ///   - fileManager: File manager for profile storage
    ///   - profilesDirectory: Directory where profiles are stored
    ///   - now: Function to get current date/time
    public init(secretStore: SecretStore, fileManager: FileManager = .default, profilesDirectory: URL? = nil, now: @escaping () -> Date = Date.init) throws {
        self.secretStore = secretStore
        self.fileManager = fileManager
        self.now = now
        
        // Set up profiles directory
        let directory = profilesDirectory ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("connection_profiles", isDirectory: true)
        self.profilesDirectory = directory
        
        // Create directory if it doesn't exist
        try createProfilesDirectory()
    }
    
    /// Create the profiles directory if it doesn't exist
    private func createProfilesDirectory() throws {
        if !fileManager.fileExists(atPath: profilesDirectory.path) {
            try fileManager.createDirectory(at: profilesDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    }
    
    /// Get the file URL for a profile
    /// - Parameter id: The profile ID
    /// - Returns: The file URL
    private func profileFileURL(for id: UUID) -> URL {
        return profilesDirectory.appendingPathComponent("profile_\(id.uuidString).json")
    }
    
    /// Save a connection profile
    /// - Parameters:
    ///   - profile: The profile to save
    ///   - password: Optional password to store securely
    /// - Throws: ProfileError if the operation fails
    public func save(_ profile: ConnectionProfile, password: String?) throws {
        // Check if a profile with the same name already exists
        let existingProfiles = try loadAllProfiles()
        if existingProfiles.contains(where: { $0.name == profile.name && $0.id != profile.id }) {
            throw ProfileError.duplicateName
        }
        
        // Store password if provided
        if let password = password {
            let key = profile.id.uuidString
            try secretStore.set(password, for: key)
            
            var profileWithRef = profile
            profileWithRef.passwordKeychainReference = key
            
            try saveProfileToDisk(profileWithRef)
        } else {
            // No password provided, save without password reference
            try saveProfileToDisk(profile)
        }
    }
    
    /// Save profile to disk
    /// - Parameter profile: The profile to save
    /// - Throws: ProfileError if the operation fails
    private func saveProfileToDisk(_ profile: ConnectionProfile) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(profile)
        let url = profileFileURL(for: profile.id)
        
        try data.write(to: url, options: [.atomicWrite])
    }
    
    /// Load a connection profile by ID
    /// - Parameter id: The profile ID
    /// - Returns: The loaded profile, or nil if not found
    /// - Throws: ProfileError if the operation fails
    public func loadProfile(id: UUID) throws -> ConnectionProfile? {
        let url = profileFileURL(for: id)
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let profile = try decoder.decode(ConnectionProfile.self, from: data)
        return profile
    }
    
    /// Load all connection profiles
    /// - Returns: Array of all profiles
    /// - Throws: ProfileError if the operation fails
    public func loadAllProfiles() throws -> [ConnectionProfile] {
        guard fileManager.fileExists(atPath: profilesDirectory.path) else {
            return []
        }
        
        let contents = try fileManager.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil, options: [])
        
        var profiles: [ConnectionProfile] = []
        
        for url in contents {
            if url.pathExtension == "json" {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                let profile = try decoder.decode(ConnectionProfile.self, from: data)
                profiles.append(profile)
            }
        }
        
        // Sort by lastUsed date (most recent first), then by name
        return profiles.sorted { profile1, profile2 in
            if let lastUsed1 = profile1.lastUsed, let lastUsed2 = profile2.lastUsed {
                return lastUsed1.compare(lastUsed2) == .orderedDescending
            } else if profile1.lastUsed != nil {
                return true
            } else if profile2.lastUsed != nil {
                return false
            } else {
                return profile1.name < profile2.name
            }
        }
    }
    
    /// Update an existing connection profile
    /// - Parameters:
    ///   - profile: The profile to update
    ///   - password: Optional new password to store securely (nil keeps existing password)
    /// - Throws: ProfileError if the operation fails
    public func updateProfile(_ profile: ConnectionProfile, password: String?) throws {
        // Check if a profile with the same name already exists (excluding current profile)
        let existingProfiles = try loadAllProfiles()
        if existingProfiles.contains(where: { $0.name == profile.name && $0.id != profile.id }) {
            throw ProfileError.duplicateName
        }
        
        // Load existing profile to preserve password reference
        guard var existingProfile = try loadProfile(id: profile.id) else {
            throw ProfileError.notFound
        }
        
        // Handle password update
        if let password = password {
            // New password provided, store it
            let key = profile.id.uuidString
            try secretStore.set(password, for: key)
            
            existingProfile.passwordKeychainReference = key
        }
        
        // Update all fields from the new profile
        existingProfile.name = profile.name
        existingProfile.host = profile.host
        existingProfile.port = profile.port
        existingProfile.useTLS = profile.useTLS
        existingProfile.username = profile.username
        existingProfile.portalId = profile.portalId
        existingProfile.lastUsed = profile.lastUsed
        
        try saveProfileToDisk(existingProfile)
    }
    
    /// Delete a connection profile
    /// - Parameter id: The profile ID to delete
    /// - Throws: ProfileError if the operation fails
    public func deleteProfile(id: UUID) throws {
        let url = profileFileURL(for: id)
        
        if fileManager.fileExists(atPath: url.path) {
            let profile = try loadProfile(id: id)
            
            // Delete password from secret store if it exists
            if let passwordRef = profile?.passwordKeychainReference {
                try secretStore.remove(passwordRef)
            }
            
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Delete all connection profiles
    /// - Throws: ProfileError if the operation fails
    public func deleteAllProfiles() throws {
        let profiles = try loadAllProfiles()
        
        for profile in profiles {
            try deleteProfile(id: profile.id)
        }
    }
    
    /// Get the most recently used profile
    /// - Returns: The most recently used profile, or nil if none
    /// - Throws: ProfileError if the operation fails
    public func getMostRecentlyUsedProfile() throws -> ConnectionProfile? {
        let profiles = try loadAllProfiles()
        return profiles.first
    }
    
    /// Get password for a profile
    /// - Parameter profile: The profile
    /// - Returns: The password, or nil if not found
    /// - Throws: ProfileError if the operation fails
    public func password(for profile: ConnectionProfile) throws -> String? {
        guard let passwordRef = profile.passwordKeychainReference else {
            return nil
        }
        
        return try secretStore.get(passwordRef)
    }
}
