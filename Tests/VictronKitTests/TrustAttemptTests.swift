//
// TrustAttemptTests.swift
//
// Tests for TrustAttempt struct functionality
//

import XCTest
@testable import VictronKit

final class TrustAttemptTests: XCTestCase {

    func testTrustAttemptAcceptsMatchingId() {
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true))
        XCTAssertTrue(attempt.accepts(resultFor: attempt.id))
    }

    func testTrustAttemptRejectsDifferentId() {
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true))
        let differentId = UUID()
        XCTAssertFalse(attempt.accepts(resultFor: differentId))
    }

    func testTrustAttemptPinMatchesHostPort() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: profile, 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertEqual(result, "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2")
    }

    func testTrustAttemptPinRejectsChangedHost() {
        let profile = ConnectionProfile(name: "Test", host: "192.168.1.1", port: 8883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsChangedPort() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 1883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsChangedTLSSetting() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: false)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsNilFingerprint() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true)
        let attempt = TrustAttempt(id: UUID(), profile: profile, fingerprint: nil, host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    func testTrustAttemptPinRejectsNonTLSProfile() {
        let profile = ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: false)
        let attempt = TrustAttempt(id: UUID(), profile: ConnectionProfile(name: "Test", host: "127.0.0.1", port: 8883, useTLS: true), 
                                   fingerprint: "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2", 
                                   host: "127.0.0.1", port: 8883)
        let result = attempt.pin(for: profile)
        XCTAssertNil(result)
    }

    /// The manual-TLS path used to store only the fingerprint, so the prompt (which needs host, port and fingerprint)
    /// came up empty. Both paths now go through completed(fingerprint:).
    func testCompletedAttemptCarriesHostPortAndFingerprint() {
        let manual = ConnectionProfile(name: "192.0.2.10", host: "192.0.2.10", port: 8883, useTLS: true)
        let done = TrustAttempt(id: UUID(), profile: manual).completed(fingerprint: String(repeating: "ab", count: 32))
        XCTAssertEqual(done.host, "192.0.2.10")
        XCTAssertEqual(done.port, 8883)
        XCTAssertEqual(done.fingerprint, String(repeating: "ab", count: 32))
        XCTAssertEqual(done.pin(for: manual), String(repeating: "ab", count: 32))
    }

    func testCompletedKeepsTheAttemptId() {
        let id = UUID()
        let profile = ConnectionProfile(name: "A", host: "192.0.2.10", port: 8883, useTLS: true)
        XCTAssertTrue(TrustAttempt(id: id, profile: profile).completed(fingerprint: "ff").accepts(resultFor: id))
    }
}
