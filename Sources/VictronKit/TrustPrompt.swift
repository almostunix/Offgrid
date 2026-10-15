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
