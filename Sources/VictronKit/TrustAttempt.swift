//
// TrustAttempt.swift
//
// Tracks trust-on-first-use attempts to prevent race conditions
//

import Foundation

/// Tracks a trust-on-first-use attempt to prevent race conditions
public struct TrustAttempt {
    public let id: UUID
    public let profile: ConnectionProfile
    public let fingerprint: String?
    public let host: String?
    public let port: Int?

    public init(id: UUID, profile: ConnectionProfile, fingerprint: String? = nil, host: String? = nil, port: Int? = nil) {
        self.id = id
        self.profile = profile
        self.fingerprint = fingerprint
        self.host = host
        self.port = port
    }

    /// Determines if this attempt's result should be accepted
    /// - Parameter id: The current attempt ID
    /// - Returns: True if the attempt ID matches (not stale)
    public func accepts(resultFor id: UUID) -> Bool {
        return self.id == id
    }

    /// Gets the fingerprint to pin for a profile if the attempt is still valid
    /// - Parameter profile: The profile to check against
    /// - Returns: The fingerprint to pin, or nil if host/port don't match
    public func pin(for profile: ConnectionProfile) -> String? {
        // Only pin if the host, port, and TLS settings match
        guard let fingerprint = fingerprint,
              let host = host,
              let port = port,
              host == profile.host,
              port == profile.port,
              self.profile.useTLS == profile.useTLS,
              profile.useTLS else {
            return nil
        }
        return fingerprint
    }
}