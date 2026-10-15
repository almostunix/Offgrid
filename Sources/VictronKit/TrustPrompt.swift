//
// TrustPrompt.swift
//
// Utilities for trust-on-first-use certificate pinning prompts.
//

import Foundation

/// Formats a SHA-256 fingerprint into groups of pairs for display
/// - Parameter fingerprint: The SHA-256 fingerprint as a hex string
/// - Returns: Formatted string with pairs grouped
public func formatFingerprint(forDisplay fingerprint: String) -> String {
    guard fingerprint.count == 64 else { return fingerprint }
    
    var result = ""
    for i in 0..<32 {
        let start = fingerprint.index(fingerprint.startIndex, offsetBy: i * 2)
        let end = fingerprint.index(start, offsetBy: 2)
        let pair = String(fingerprint[start..<end])
        result += pair
        if i < 31 {
            result += " "
        }
    }
    return result
}

/// Determines if a profile needs trust-on-first-use prompt
/// - Parameter profile: The connection profile
/// - Returns: True if the profile needs trust prompt (TLS enabled but no pinned certificate)
public func needsTrustPrompt(for profile: ConnectionProfile) -> Bool {
    return profile.useTLS && profile.pinnedCertificateSHA256 == nil
}

/// Determines if a profile with password needs plaintext password warning
/// - Parameters:
///   - profile: The connection profile
///   - password: The password (optional)
/// - Returns: True if the profile uses plain MQTT with a password (needs warning)
public func needsPlaintextPasswordWarning(for profile: ConnectionProfile, password: String?) -> Bool {
    return !profile.useTLS && !(password ?? "").isEmpty
}

/// Determines if the certificate pin should be preserved when editing a profile
/// - Parameters:
///   - old: The original connection profile
///   - new: The updated connection profile
/// - Returns: The pinned certificate SHA-256 if it should be preserved, nil otherwise
public func pinAfterEdit(old: ConnectionProfile, new: ConnectionProfile) -> String? {
    // Keep the existing pin only if host, port, and TLS settings haven't changed
    if old.host == new.host && old.port == new.port && old.useTLS == new.useTLS {
        return old.pinnedCertificateSHA256
    }
    // Clear the pin if any of the critical connection parameters changed
    return nil
}

/// Warning message for plaintext password connections
public let plaintextPasswordWarning = "Your password will be sent unencrypted. Anyone on this network could read it and use it to control your Cerbo. Switch the Cerbo to TLS (port 8883) if you can."
